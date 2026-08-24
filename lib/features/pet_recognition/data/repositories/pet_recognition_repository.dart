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

  /// Processa visualmente uma lista de imagens de um pet (3 a 5 fotos).
  /// Cada foto é analisada individualmente com isolamento total de falhas.
  Future<PetVisualProfileEntity> processPetImages({
    required String petId,
    required PetType petType,
    required List<String> imageUrls,
    Map<String, BoundingBoxEntity>? selectedAnimalPerImage,
  }) async {
    _logger.i('Iniciando processamento de lote de imagens do pet.', context: {
      'petId': petId,
      'totalImages': imageUrls.length,
      'petType': petType.name,
    });

    final List<PetImageAnalysisEntity> analyzedImages = [];

    // Se for espécie diferente de cão e gato, não executa pipeline visual
    if (petType != PetType.dog && petType != PetType.cat) {
      for (int i = 0; i < imageUrls.length; i++) {
        analyzedImages.add(
          PetImageAnalysisEntity(
            id: 'img_${petId}_$i',
            imageUrl: imageUrls[i],
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

    // Processa cada imagem individualmente (YOLOv8n + SigLIP)
    for (int i = 0; i < imageUrls.length; i++) {
      final imgUrl = imageUrls[i];
      final imageId = 'img_${petId}_$i';
      final selectedBox = selectedAnimalPerImage?[imgUrl];

      try {
        final result = await _aiVisionService.analyzeImage(
          imageId: imageId,
          imageUrl: imgUrl,
          petType: petType,
          userSelectedBox: selectedBox,
        );

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

  /// Executa a busca em duas etapas por possíveis correspondências (Matches):
  /// Etapa 1: Recuperação de candidatos estruturados e vetoriais (pgvector/HNSW conceitual).
  /// Etapa 2: Refinamento detalhado por similaridade de cosseno nos embeddings individuais.
  Future<List<PetMatchCandidateEntity>> findMatches({
    required PetLostAlertEntity queryPet,
    PetVisualProfileEntity? queryVisualProfile,
    double minSimilarity = 0.50,
  }) async {
    _logger.i('Iniciando busca de matches.', context: {
      'queryPetId': queryPet.id,
      'petType': queryPet.petType.name,
      'hasVisual': queryVisualProfile?.hasVisualEmbedding,
    });

    // 1. Etapa 1 - Recuperação de candidatos (Defensive Species Isolation)
    final filter = PetCadastralFilterEntity.fromPetAlert(queryPet);
    final candidateAlerts = await _supabaseService.getCandidateAlerts(
      filters: filter,
      excludePetId: queryPet.id,
    );

    if (candidateAlerts.isEmpty) {
      return [];
    }

    final List<PetMatchCandidateEntity> matches = [];

    // Se for cão/gato e houver embeddings visuais válidos:
    final bool canPerformVisualMatch = queryVisualProfile != null &&
        queryVisualProfile.hasVisualEmbedding &&
        queryVisualProfile.isEligibleForVisualAi;

    if (canPerformVisualMatch) {
      final queryValidEmbeddings = queryVisualProfile.validImageAnalyses
          .map((img) => img.embedding!)
          .toList();

      for (final candidate in candidateAlerts) {
        // Regra estrita: nunca comparar espécies diferentes
        if (candidate.petType != queryPet.petType) continue;

        final candidateProfile =
            await _supabaseService.getVisualProfile(candidate.id);

        double finalScore = 0.0;
        final List<double> individualScores = [];

        if (candidateProfile != null && candidateProfile.hasVisualEmbedding) {
          // Etapa 2 - Refinamento detalhado com embeddings individuais
          final candidateValidEmbeddings = candidateProfile.validImageAnalyses
              .map((img) => img.embedding!)
              .toList();

          final aggregatedSim = VectorMath.cosineSimilarity(
            queryVisualProfile.aggregatedEmbedding,
            candidateProfile.aggregatedEmbedding,
          );

          finalScore = VectorMath.computeDetailedMatchScore(
            queryEmbeddings: queryValidEmbeddings,
            candidateEmbeddings: candidateValidEmbeddings,
            aggregatedSimilarity: aggregatedSim,
          );

          for (final q in queryValidEmbeddings) {
            double best = 0.0;
            for (final c in candidateValidEmbeddings) {
              final sim = VectorMath.cosineSimilarity(q, c);
              if (sim > best) best = sim;
            }
            individualScores.add(best);
          }
        } else {
          // Candidato não possui perfil visual -> fallback cadastral com peso reduzido
          finalScore = _computeCadastralScore(queryPet, candidate);
        }

        if (finalScore >= minSimilarity) {
          matches.add(
            PetMatchCandidateEntity(
              matchedPet: candidate,
              visualProfile: candidateProfile,
              similarityScore: finalScore,
              matchMethod: candidateProfile?.hasVisualEmbedding == true
                  ? MatchMethod.visual
                  : MatchMethod.cadastral,
              individualImageScores: individualScores,
              matchingDetails:
                  'Similaridade baseada em fotos e características compatíveis.',
            ),
          );
        }
      }
    } else {
      // Outras espécies (ou cão/gato sem embeddings): busca puramente cadastral
      for (final candidate in candidateAlerts) {
        if (candidate.petType != queryPet.petType) continue;

        final score = _computeCadastralScore(queryPet, candidate);
        if (score >= minSimilarity) {
          matches.add(
            PetMatchCandidateEntity(
              matchedPet: candidate,
              similarityScore: score,
              matchMethod: MatchMethod.cadastral,
              matchingDetails:
                  'Correspondência baseada em raça, idade e localização aproximada.',
            ),
          );
        }
      }
    }

    // Ordena matches do maior score para o menor
    matches.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    return matches;
  }

  /// Calcula um score de similaridade cadastral ponderado (0.0 a 1.0)
  double _computeCadastralScore(
    PetLostAlertEntity a,
    PetLostAlertEntity b,
  ) {
    if (a.petType != b.petType) return 0.0;

    double score = 0.40; // Base por pertencer à mesma espécie

    // Comparação de raça
    if (a.breed != null &&
        b.breed != null &&
        a.breed!.trim().isNotEmpty &&
        b.breed!.trim().isNotEmpty) {
      if (a.breed!.trim().toLowerCase() == b.breed!.trim().toLowerCase()) {
        score += 0.30;
      }
    }

    // Comparação de idade
    if (a.age != null &&
        b.age != null &&
        a.age!.trim().isNotEmpty &&
        b.age!.trim().isNotEmpty) {
      if (a.age!.trim().toLowerCase() == b.age!.trim().toLowerCase()) {
        score += 0.15;
      }
    }

    // Proximidade temporal do desaparecimento (dentro de 15 dias ganha bônus)
    final daysDiff = a.lostDate.difference(b.lostDate).inDays.abs();
    if (daysDiff <= 15) {
      score += 0.15;
    } else if (daysDiff <= 45) {
      score += 0.05;
    }

    return score.clamp(0.0, 1.0);
  }
}
