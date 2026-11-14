import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart';
import '../../../pet_found/domain/pet_found_entity.dart';
import '../../domain/models/analysis_status.dart';
import '../../domain/models/bounding_box_entity.dart';
import '../../domain/models/pet_image_analysis_entity.dart';
import '../../domain/models/pet_match_candidate_entity.dart';
import '../../domain/models/pet_visual_profile_entity.dart';
import '../../domain/utils/recognition_config.dart';
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
      await _supabaseService.pruneStalePetImages(
        petId: petId,
        activeImageUrls: targetUrls,
      );

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

    // 1. Recupera embeddings de fotos anteriores já salvas para este pet (evita reprocessar fotos inalteradas)
    final existingImagesMap = await _supabaseService.getExistingPetImageEmbeddings(petId);

    // Processa cada imagem individualmente (YOLOv8n + SigLIP) - até 3 fotos
    for (int i = 0; i < targetUrls.length; i++) {
      final imgUrl = targetUrls[i];
      final imageId = 'img_${petId}_$i';
      final selectedBox = selectedAnimalPerImage?[imgUrl];

      // Se a imagem já possui embedding válido persistido e nenhuma bbox manual foi enviada, reutiliza
      if (existingImagesMap.containsKey(imgUrl) && selectedBox == null) {
        final cachedEmbedding = existingImagesMap[imgUrl]!;
        analyzedImages.add(
          PetImageAnalysisEntity(
            id: imageId,
            imageUrl: imgUrl,
            status: AnalysisStatus.processed,
            embedding: cachedEmbedding,
            processedAt: DateTime.now(),
          ),
        );
        continue;
      }

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

    // 2. Sincroniza a tabela pet_images com as imagens ativas atuais:
    // Imagens que deixaram de pertencer ao anúncio são expurgadas da tabela de embeddings
    await _supabaseService.pruneStalePetImages(
      petId: petId,
      activeImageUrls: targetUrls,
    );

    // 3. Mescla os embeddings recém-processados com os existentes preservados
    final Map<String, List<double>> mergedEmbeddings = {};
    for (final url in targetUrls) {
      if (existingImagesMap.containsKey(url)) {
        mergedEmbeddings[url] = existingImagesMap[url]!;
      }
    }
    for (final img in analyzedImages) {
      if (img.hasValidEmbedding && img.embedding != null) {
        mergedEmbeddings[img.imageUrl] = img.embedding!;
      }
    }

    final validEmbeddings = mergedEmbeddings.values.toList();
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

  /// Executa a busca por possíveis correspondências para um pet perdido.
  /// Suporta tanto o fluxo automático quanto a busca manual disparada pelo usuário.
  /// 
  /// Utiliza a função RPC pgvector `match_found_pets_for_lost` com índices HNSW no PostgreSQL.
  Future<List<PetMatchCandidateEntity>> findMatches({
    required PetLostAlertEntity queryPet,
    PetVisualProfileEntity? queryVisualProfile,
    double minSimilarity = RecognitionConfig.kSimilarityThreshold,
    String origin = 'manual',
  }) async {
    _logger.i('Iniciando busca visual unificada de matches via pgvector.', context: {
      'queryPetId': queryPet.id,
      'petType': queryPet.petType.name,
      'origin': origin,
      'minSimilarity': minSimilarity,
    });

    final profile = queryVisualProfile ?? await getVisualProfile(queryPet.id);
    if (profile == null || !profile.hasVisualEmbedding || !profile.isEligibleForVisualAi) {
      _logger.i('Pet não possui perfil visual ou espécie não elegível para IA.');
      return [];
    }

    final queryEmbedding = profile.representativeEmbedding;
    if (queryEmbedding == null || !VectorMath.isValidEmbedding(queryEmbedding)) {
      _logger.w('Embedding representativo do pet da busca inválido.');
      return [];
    }

    final List<PetMatchCandidateEntity> matches = [];

    // Consulta vetorial via RPC do Supabase (pgvector + HNSW)
    final rpcResults = await _supabaseService.callMatchRpc(
      functionName: 'match_found_pets_for_lost',
      targetPetType: queryPet.petType.name,
      excludePetId: queryPet.id,
      similarityThreshold: minSimilarity,
      matchLimit: 20,
    );

    for (final row in rpcResults) {
      final foundPetId = row['pet_id'] as String;
      final score = (row['similarity_score'] as num).toDouble();

      // Usa o método do serviço que retorna PetLostAlertEntity (compatível com matchedPet)
      final foundAsCandidate = await _supabaseService.getFoundAlertAsCandidate(foundPetId);
      if (foundAsCandidate == null) continue;

      final foundProfile = await getVisualProfile(foundPetId);

      // Persiste com a origem informada ('automatic' ou 'manual')
      await _supabaseService.saveMatch(
        lostPetId: queryPet.id,
        foundPetId: foundPetId,
        similarityScore: score,
        matchMethod: 'visual_single_vector',
        individualScores: [score],
        origin: origin,
      );

      matches.add(
        PetMatchCandidateEntity(
          matchedPet: foundAsCandidate,
          visualProfile: foundProfile,
          similarityScore: score,
          matchMethod: MatchMethod.visual,
          individualImageScores: [score],
          matchingDetails: 'Correspondência visual unificada por busca vetorial pgvector.',
        ),
      );
    }

    matches.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    return matches;
  }

  /// Recupera as correspondências persistidas no Supabase sem recalcular IA.
  Future<List<PetMatchCandidateEntity>> getPersistedMatchesForLostPet(
    String lostPetId, {
    double minSimilarity = RecognitionConfig.kSimilarityThreshold,
  }) async {
    _logger.i('Carregando matches persistidos para pet perdido.', context: {'lostPetId': lostPetId});
    final rawMatches = await _supabaseService.getMatchesForLostPet(lostPetId, minScore: minSimilarity);

    final List<PetMatchCandidateEntity> results = [];
    for (final m in rawMatches) {
      final foundPetId = m['found_pet_id'] as String?;
      final score = (m['similarity_score'] as num?)?.toDouble() ?? 0.0;
      if (foundPetId == null || score < minSimilarity) continue;

      dynamic matchedPet;
      // Usa o método do serviço que retorna PetLostAlertEntity (compatível com matchedPet)
      matchedPet = await _supabaseService.getFoundAlertAsCandidate(foundPetId);

      final profile = await getVisualProfile(foundPetId);

      if (matchedPet != null) {
        results.add(
          PetMatchCandidateEntity(
            matchedPet: matchedPet,
            visualProfile: profile,
            similarityScore: score,
            matchMethod: MatchMethod.visual,
            individualImageScores: [score],
            matchingDetails: 'Correspondência recuperada do histórico persistido.',
          ),
        );
      }
    }

    return results;
  }

  /// Executa o matching automático simplificado e otimizado quando um pet encontrado é cadastrado.
  /// 
  /// Compara a representação visual única do pet encontrado exclusivamente contra os pets perdidos ativos
  /// da mesma espécie.
  /// 
  /// - Utiliza a representação visual única por pet (embedding agregado quando disponível, ou o embedding individual).
  /// - Executa a busca vetorial via RPC pgvector `match_lost_pets_for_found`.
  /// - Persiste com origin = 'automatic' para notificar o tutor do pet perdido.
  /// - Garante a ordem canônica dos IDs: lost_pet_id (pet perdido) e found_pet_id (pet encontrado).
  Future<List<PetMatchCandidateEntity>> matchFoundPetAgainstLostPets({
    required PetFoundAlertEntity foundPet,
    required PetVisualProfileEntity foundVisualProfile,
    List<PetLostAlertEntity>? activeLostPets,
    double minSimilarity = RecognitionConfig.kSimilarityThreshold,
    String origin = 'automatic',
  }) async {
    _logger.i('Iniciando matching automático para pet encontrado via pgvector.', context: {
      'foundPetId': foundPet.id,
      'petType': foundPet.petType.name,
      'origin': origin,
    });

    if (!foundVisualProfile.isEligibleForVisualAi) {
      _logger.i('Espécie não elegível para matching visual automático.');
      return [];
    }

    final foundEmbedding = foundVisualProfile.representativeEmbedding;
    if (foundEmbedding == null || !VectorMath.isValidEmbedding(foundEmbedding)) {
      _logger.w('Pet encontrado sem representação visual válida de 768d.');
      return [];
    }

    final List<PetMatchCandidateEntity> matches = [];

    // Consulta vetorial via RPC do Supabase (pgvector + HNSW)
    final rpcResults = await _supabaseService.callMatchRpc(
      functionName: 'match_lost_pets_for_found',
      targetPetType: foundPet.petType.name,
      excludePetId: foundPet.id,
      similarityThreshold: minSimilarity,
      matchLimit: 20,
    );

    for (final row in rpcResults) {
      final lostPetId = row['pet_id'] as String;
      final score = (row['similarity_score'] as num).toDouble();

      // Usa o método do serviço que retorna PetLostAlertEntity diretamente
      final lostAlert = await _supabaseService.getLostAlertById(lostPetId);
      if (lostAlert == null) continue;

      final lostProfile = await getVisualProfile(lostPetId);

      await _supabaseService.saveMatch(
        lostPetId: lostPetId,
        foundPetId: foundPet.id,
        similarityScore: score,
        matchMethod: 'visual_single_vector',
        individualScores: [score],
        origin: origin,
      );

      matches.add(
        PetMatchCandidateEntity(
          matchedPet: lostAlert,
          visualProfile: lostProfile,
          similarityScore: score,
          matchMethod: MatchMethod.visual,
          individualImageScores: [score],
          matchingDetails: 'Correspondência visual automática por busca vetorial pgvector.',
        ),
      );
    }

    matches.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));

    _logger.i('Matching automático concluído para o pet encontrado.', context: {
      'foundPetId': foundPet.id,
      'matchesRecorded': matches.length,
    });

    return matches;
  }
}
