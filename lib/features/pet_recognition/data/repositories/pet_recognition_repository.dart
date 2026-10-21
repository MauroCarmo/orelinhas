import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart';
import '../../../pet_found/domain/pet_found_entity.dart';
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
            status: result.status.toSnakeCase(),
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

  /// Executa o matching automático simplificado e otimizado quando um pet encontrado é cadastrado.
  /// 
  /// Compara a representação visual única do pet encontrado exclusivamente contra os pets perdidos ativos
  /// da mesma espécie fornecidos em [activeLostPets].
  /// 
  /// - Utiliza a representação visual única por pet (embedding agregado quando disponível, ou o embedding individual).
  /// - Não recarrega os pets encontrados nem recalcula correspondências antigas desnecessariamente.
  /// - Persiste na tabela matches apenas os pares que atingirem [minSimilarity] (padrão 0.70).
  /// - Garante a ordem correta dos identificadores: lost_pet_id (pet perdido) e found_pet_id (pet encontrado).
  Future<List<PetMatchCandidateEntity>> matchFoundPetAgainstLostPets({
    required PetFoundAlertEntity foundPet,
    required PetVisualProfileEntity foundVisualProfile,
    required List<PetLostAlertEntity> activeLostPets,
    double minSimilarity = 0.70,
  }) async {
    _logger.i('Iniciando matching automático para pet encontrado.', context: {
      'foundPetId': foundPet.id,
      'petType': foundPet.petType.name,
      'candidateLostCount': activeLostPets.length,
    });

    // 1. Verificação de espécie e elegibilidade para IA visual
    if (!foundVisualProfile.isEligibleForVisualAi) {
      _logger.i('Espécie não elegível para matching visual automático.', context: {
        'petType': foundPet.petType.name,
      });
      return [];
    }

    // 2. Extrai a representação visual única do pet encontrado
    final foundEmbedding = foundVisualProfile.representativeEmbedding;
    if (foundEmbedding == null || foundEmbedding.length != 768) {
      _logger.w('Pet encontrado sem representação visual válida de 768d.', context: {
        'petId': foundPet.id,
      });
      return [];
    }

    // 3. Filtra estritamente pets perdidos ativos da mesma espécie e com ID distinto
    final eligibleLostPets = activeLostPets
        .where((lost) => lost.petType == foundPet.petType && lost.id != foundPet.id)
        .toList();

    if (eligibleLostPets.isEmpty) {
      _logger.i('Nenhum pet perdido ativo da mesma espécie encontrado para comparação.');
      return [];
    }

    // 4. Carrega os perfis visuais dos pets perdidos candidatos em lote
    final lostIds = eligibleLostPets.map((p) => p.id).toList();
    final lostProfilesMap = await _supabaseService.getVisualProfilesByIds(lostIds);

    final List<PetMatchCandidateEntity> matches = [];

    // 5. Comparação 1:N direta entre o novo pet encontrado e os pets perdidos elegíveis
    for (final lostPet in eligibleLostPets) {
      final lostProfile = lostProfilesMap[lostPet.id];
      if (lostProfile == null) continue;

      final lostEmbedding = lostProfile.representativeEmbedding;
      if (lostEmbedding == null || lostEmbedding.length != 768) continue;

      // Similaridade de cosseno direto entre as representações visuais únicas
      final similarity = VectorMath.cosineSimilarity(foundEmbedding, lostEmbedding);

      if (similarity >= minSimilarity) {
        // Persiste no Supabase com a semântica canônica:
        // lost_pet_id = ID do pet perdido, found_pet_id = ID do pet encontrado
        await _supabaseService.saveMatch(
          lostPetId: lostPet.id,
          foundPetId: foundPet.id,
          similarityScore: similarity,
          matchMethod: 'visual_single_vector',
          individualScores: [similarity],
        );

        matches.add(
          PetMatchCandidateEntity(
            matchedPet: lostPet,
            visualProfile: lostProfile,
            similarityScore: similarity,
            matchMethod: MatchMethod.visual,
            individualImageScores: [similarity],
            matchingDetails:
                'Correspondência visual automática por representação única.',
          ),
        );
      }
    }

    // 6. Ordena do maior score para o menor
    matches.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));

    _logger.i('Matching automático concluído para o pet encontrado.', context: {
      'foundPetId': foundPet.id,
      'matchesRecorded': matches.length,
    });

    return matches;
  }
}
