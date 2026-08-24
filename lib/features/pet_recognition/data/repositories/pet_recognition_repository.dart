import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart';
import '../../domain/models/analysis_status.dart';
import '../../domain/models/bounding_box_entity.dart';
import '../../domain/models/pet_cadastral_filter_entity.dart';
import '../../domain/models/pet_image_analysis_entity.dart';
import '../../domain/models/pet_match_candidate_entity.dart';
import '../../domain/models/pet_visual_profile_entity.dart';
import '../../domain/utils/vector_math.dart';
import '../services/ai_vision_service.dart';
import '../services/supabase_pet_recognition_service.dart';

final petRecognitionRepositoryProvider =
    Provider<PetRecognitionRepository>((ref) {
  final aiVisionService = ref.watch(aiVisionServiceProvider);
  final supabaseService = ref.watch(supabasePetRecognitionServiceProvider);
  return PetRecognitionRepository(aiVisionService, supabaseService);
});

/// Repositório central da feature pet_recognition.
/// Gerencia o processamento visual desacoplado e a busca de matches em duas etapas.
class PetRecognitionRepository {
  final AiVisionService _aiVisionService;
  final SupabasePetRecognitionService _supabaseService;
  final _logger = AppLogger.category('PetRecognitionRepository');

  PetRecognitionRepository(this._aiVisionService, this._supabaseService);

  /// Processa visualmente uma lista de imagens de um pet (máximo 3 fotos por anúncio).
  /// Cada foto é analisada individualmente com isolamento total de falhas.
  Future<PetVisualProfileEntity> processPetImages({
    required String petId,
    required PetType petType,
    required List<String> imageUrls,
    Map<String, BoundingBoxEntity>? selectedAnimalPerImage,
  }) async {
    // Garante no máximo 3 imagens por anúncio
    final targetUrls = imageUrls.take(3).toList();

    _logger.i('Iniciando processamento de imagens do pet (máx 3).', context: {
      'petId': petId,
      'totalImages': targetUrls.length,
      'petType': petType.name,
    });

    final List<PetImageAnalysisEntity> analyzedImages = [];

    // Se for espécie diferente de cão e gato, não executa pipeline visual
    if (petType != PetType.dog && petType != PetType.cat) {
      for (int i = 0; i < targetUrls.length; i++) {
        analyzedImages.add(
          PetImageAnalysisEntity(
            id: 'img_${petId}_$i',
            imageUrl: targetUrls[i],
            status: AnalysisStatus.notDetected,
            errorReason: 'Espécie não utiliza reconhecimento visual de embeddings.',
            processedAt: DateTime.now(),
          ),
        );
      }

      final profile = PetVisualProfileEntity(
        petId: petId,
        petType: petType,
        images: analyzedImages,
        aggregatedEmbedding: null,
        lastAnalyzedAt: DateTime.now(),
      );

      await _supabaseService.saveVisualProfile(profile);
      return profile;
    }

    // Processa cada imagem individualmente (YOLOv8n + SigLIP) - até 3 fotos
    for (int i = 0; i < targetUrls.length; i++) {
      final imgUrl = targetUrls[i];
      final imageId = 'img_${petId}_$i';
      final selectedBox = selectedAnimalPerImage?[imgUrl];

      try {
        final result = await _aiVisionService.analyzeImage(
          imageId: imageId,
          imageUrl: imgUrl,
          petType: petType,
          userSelectedBox: selectedBox,
        );

        if (result.embedding768 != null) {
          await _supabaseService.savePetImage(
            petId: petId,
            imageUrl: imgUrl,
            status: result.status.name,
            embedding: result.embedding768,
          );
        }

        analyzedImages.add(
          PetImageAnalysisEntity(
            id: imageId,
            imageUrl: imgUrl,
            status: result.status,
            detectedAnimals: result.detections,
            selectedAnimal: result.selectedDetection,
            embedding: result.embedding768,
            errorReason: result.errorMessage,
            processedAt: DateTime.now(),
          ),
        );
      } catch (e, st) {
        _logger.w('Falha capturada ao analisar imagem individual.', error: e, stackTrace: st);
        analyzedImages.add(
          PetImageAnalysisEntity(
            id: imageId,
            imageUrl: imgUrl,
            status: AnalysisStatus.error,
            errorReason: 'Erro inesperado no processamento da imagem.',
            processedAt: DateTime.now(),
          ),
        );
      }
    }

    // Geração do embedding agregado com normalização L2 sobre os válidos
    final validEmbeddings = analyzedImages
        .where((img) => img.hasValidEmbedding)
        .map((img) => img.embedding)
        .toList();

    final aggregated = VectorMath.computeAggregatedEmbedding(validEmbeddings);

    final profile = PetVisualProfileEntity(
      petId: petId,
      petType: petType,
      images: analyzedImages,
      aggregatedEmbedding: aggregated,
      lastAnalyzedAt: DateTime.now(),
    );

    await _supabaseService.saveVisualProfile(profile);
    return profile;
  }

  /// Recupera o perfil visual existente de um pet.
  Future<PetVisualProfileEntity?> getVisualProfile(String petId) async {
    return await _supabaseService.getVisualProfile(petId);
  }

  /// Executa a busca por possíveis correspondências (Matches):
  /// Comparação estritamente visual baseada nos embeddings das imagens (SigLIP 768d + Cosseno).
  Future<List<PetMatchCandidateEntity>> findMatches({
    required PetLostAlertEntity queryPet,
    PetVisualProfileEntity? queryVisualProfile,
    double minSimilarity = 0.70,
  }) async {
    _logger.i('Iniciando busca visual de matches por embeddings de imagem.', context: {
      'queryPetId': queryPet.id,
      'petType': queryPet.petType.name,
      'hasVisual': queryVisualProfile?.hasVisualEmbedding,
    });

    // 1. Recuperação de candidatos ativos da mesma espécie
    final filter = PetCadastralFilterEntity.fromPetAlert(queryPet);
    final candidateAlerts = await _supabaseService.getCandidateAlerts(
      filters: filter,
      excludePetId: queryPet.id,
    );

    if (candidateAlerts.isEmpty) {
      return [];
    }

    final List<PetMatchCandidateEntity> matches = [];

    // Se houver perfil visual válido para a query:
    final bool canPerformVisualMatch = queryVisualProfile != null &&
        queryVisualProfile.hasVisualEmbedding &&
        queryVisualProfile.isEligibleForVisualAi;

    if (canPerformVisualMatch) {
      final queryValidEmbeddings = queryVisualProfile.validImageAnalyses
          .map((img) => img.embedding!)
          .toList();

      for (final candidate in candidateAlerts) {
        // Regra estrita: nunca comparar espécies diferentes (cão != gato)
        if (candidate.petType != queryPet.petType) continue;

        final candidateProfile =
            await _supabaseService.getVisualProfile(candidate.id);

        // Se o candidato não possui fotos/embeddings válidos, desconsidera
        if (candidateProfile == null || !candidateProfile.hasVisualEmbedding) {
          continue;
        }

        final candidateValidEmbeddings = candidateProfile.validImageAnalyses
            .map((img) => img.embedding!)
            .toList();

        final aggregatedSim = VectorMath.cosineSimilarity(
          queryVisualProfile.aggregatedEmbedding,
          candidateProfile.aggregatedEmbedding,
        );

        // Score 100% puramente visual (cosseno sobre os embeddings das fotos)
        final finalScore = VectorMath.computeDetailedMatchScore(
          queryEmbeddings: queryValidEmbeddings,
          candidateEmbeddings: candidateValidEmbeddings,
          aggregatedSimilarity: aggregatedSim,
        );

        final List<double> individualScores = [];
        for (final q in queryValidEmbeddings) {
          double best = 0.0;
          for (final c in candidateValidEmbeddings) {
            final sim = VectorMath.cosineSimilarity(q, c);
            if (sim > best) best = sim;
          }
          individualScores.add(best);
        }

        if (finalScore >= minSimilarity) {
          // Persiste na tabela matches do Supabase (dispara o trigger de notificação)
          await _supabaseService.saveMatch(
            lostPetId: queryPet.id,
            foundPetId: candidate.id,
            similarityScore: finalScore,
            matchMethod: 'visual',
            individualScores: individualScores,
          );

          matches.add(
            PetMatchCandidateEntity(
              matchedPet: candidate,
              visualProfile: candidateProfile,
              similarityScore: finalScore,
              matchMethod: MatchMethod.visual,
              individualImageScores: individualScores,
              matchingDetails:
                  'Correspondência visual calculada a partir dos embeddings das fotos.',
            ),
          );
        }
      }
    }

    // Ordena matches do maior score para o menor
    matches.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    return matches;
  }
}
