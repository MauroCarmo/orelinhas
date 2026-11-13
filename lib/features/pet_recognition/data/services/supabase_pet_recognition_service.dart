import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart';
import '../../domain/models/pet_cadastral_filter_entity.dart';
import '../../domain/models/pet_visual_profile_entity.dart';
import '../../domain/utils/recognition_config.dart';
import '../../domain/utils/vector_math.dart';

final supabasePetRecognitionServiceProvider =
    Provider<SupabasePetRecognitionService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return SupabasePetRecognitionService(supabase);
});

/// Serviço de integração com Supabase para persistência e busca vetorial de perfis de reconhecimento de pets.
class SupabasePetRecognitionService {
  final SupabaseClient _supabase;
  final _logger = AppLogger.category('SupabasePetRecognitionService');

  // Armazenamento local em memória para fallback/testes/offline
  final Map<String, PetVisualProfileEntity> _inMemoryProfiles = {};
  final Map<String, Map<String, List<double>>> _inMemoryPetImages = {};
  final Map<String, Map<String, dynamic>> _inMemoryMatches = {};

  SupabasePetRecognitionService(this._supabase);

  /// Salva ou atualiza o perfil visual do pet no banco de dados.
  /// Falhas de banco nesta etapa não devem interromper o fluxo principal.
  Future<void> saveVisualProfile(PetVisualProfileEntity profile) async {
    _logger.i('Salvando perfil visual do pet.', context: {
      'petId': profile.petId,
      'imagesCount': profile.images.length,
      'hasAggregatedEmbedding': profile.hasVisualEmbedding,
    });

    // Sempre mantém atualizado em memória
    _inMemoryProfiles[profile.petId] = profile;

    try {
      final json = profile.toJson();
      await _supabase.from('pet_visual_profiles').upsert(
            json,
            onConflict: 'pet_id',
          );
      _logger.i('Perfil visual persistido com sucesso no Supabase.');
    } catch (e, st) {
      _logger.w(
        'Aviso: Não foi possível persistir no Supabase (tabela pode estar em migração). Mantido em cache local.',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Recupera o perfil visual de um pet por ID.
  Future<PetVisualProfileEntity?> getVisualProfile(String petId) async {
    if (_inMemoryProfiles.containsKey(petId)) {
      return _inMemoryProfiles[petId];
    }

    try {
      final data = await _supabase
          .from('pet_visual_profiles')
          .select()
          .eq('pet_id', petId)
          .maybeSingle();

      if (data != null) {
        final profile = PetVisualProfileEntity.fromJson(data);
        _inMemoryProfiles[petId] = profile;
        return profile;
      }
    } catch (e, st) {
      _logger.w('Erro ao consultar perfil visual no Supabase.', error: e, stackTrace: st);
    }

    return _inMemoryProfiles[petId];
  }

  /// Recupera perfis visuais em lote por lista de IDs de pets.
  Future<Map<String, PetVisualProfileEntity>> getVisualProfilesByIds(
    List<String> petIds,
  ) async {
    if (petIds.isEmpty) return {};
    final Map<String, PetVisualProfileEntity> results = {};
    final List<String> missingIds = [];

    for (final id in petIds) {
      if (_inMemoryProfiles.containsKey(id)) {
        results[id] = _inMemoryProfiles[id]!;
      } else {
        missingIds.add(id);
      }
    }

    if (missingIds.isEmpty) return results;

    try {
      final data = await _supabase
          .from('pet_visual_profiles')
          .select()
          .inFilter('pet_id', missingIds);

      for (final row in data) {
        final profile = PetVisualProfileEntity.fromJson(row);
        _inMemoryProfiles[profile.petId] = profile;
        results[profile.petId] = profile;
      }
    } catch (e, st) {
      _logger.w('Erro ao consultar perfis visuais em lote no Supabase.', error: e, stackTrace: st);
    }

    return results;
  }

  /// Recupera todos os perfis visuais cadastrados para uma espécie específica.
  /// A espécie é um filtro estrito (cão != gato).
  Future<List<PetVisualProfileEntity>> getVisualProfilesBySpecies(
    PetType petType,
  ) async {
    final List<PetVisualProfileEntity> results = [];

    try {
      final data = await _supabase
          .from('pet_visual_profiles')
          .select()
          .eq('pet_type', petType.name);

      for (final row in data) {
        results.add(PetVisualProfileEntity.fromJson(row));
      }
    } catch (e, st) {
      _logger.w(
        'Falha ao carregar perfis visuais remotos por espécie. Usando cache.',
        error: e,
        stackTrace: st,
      );
      results.addAll(_inMemoryProfiles.values.where((p) => p.petType == petType));
    }

    // Mescla com os perfis em memória
    for (final memoryProfile in _inMemoryProfiles.values) {
      if (memoryProfile.petType == petType &&
          !results.any((r) => r.petId == memoryProfile.petId)) {
        results.add(memoryProfile);
      }
    }

    return results;
  }

  /// Recupera um único pet encontrado pelo ID, retornando-o como PetLostAlertEntity
  /// (mapeamento compatível com PetMatchCandidateEntity sem alterar a entidade existente).
  Future<PetLostAlertEntity?> getFoundAlertAsCandidate(String foundPetId) async {
    try {
      final data = await _supabase
          .from('pet_found_alerts')
          .select()
          .eq('id', foundPetId)
          .maybeSingle();
      if (data == null) return null;
      final breedStr = data['breed'] as String?;
      return PetLostAlertEntity(
        id: data['id'] as String,
        userId: data['user_id'] as String,
        petName: breedStr != null && breedStr.isNotEmpty
            ? 'Pet Encontrado ($breedStr)'
            : 'Pet Encontrado',
        petType: PetType.values.firstWhere(
            (t) => t.name == (data['pet_type'] as String? ?? ''),
            orElse: () => PetType.other,
          ),
        breed: breedStr,
        description: data['description'] as String? ?? '',
        lastLocation: data['found_location'] as String? ?? '',
        lostDate: data['created_at'] != null
            ? DateTime.parse(data['created_at'] as String)
            : DateTime.now(),
        contact: data['contact'] as String? ?? '',
        imageUrl: data['image_url'] as String?,
        latitude: data['latitude'] != null
            ? (data['latitude'] as num).toDouble()
            : null,
        longitude: data['longitude'] != null
            ? (data['longitude'] as num).toDouble()
            : null,
      );
    } catch (e, st) {
      _logger.w('Aviso ao buscar pet encontrado como candidato por ID.', error: e, stackTrace: st);
      return null;
    }
  }

  /// Recupera um único pet perdido pelo ID, retornando-o como PetLostAlertEntity
  /// (usado na recuperação de matches persistidos).
  Future<PetLostAlertEntity?> getLostAlertById(String lostPetId) async {
    try {
      final data = await _supabase
          .from('pet_lost_alerts')
          .select()
          .eq('id', lostPetId)
          .maybeSingle();
      if (data == null) return null;
      return PetLostAlertEntity.fromJson(data);
    } catch (e, st) {
      _logger.w('Aviso ao buscar pet perdido por ID.', error: e, stackTrace: st);
      return null;
    }
  }

  /// Busca alertas candidatos ativos aplicando filtros cadastrais obrigatórios.
  /// Para um pet perdido, busca prioritariamente em pet_found_alerts (pets encontrados).
  Future<List<PetLostAlertEntity>> getCandidateAlerts({
    required PetCadastralFilterEntity filters,
    String? excludePetId,
    int limit = 50,
  }) async {
    _logger.i('Buscando alertas candidatos cadastrais em pet_found_alerts.', context: {
      'species': filters.petType.name,
      'excludePetId': excludePetId,
    });

    try {
      // 1. Busca em pet_found_alerts (pets encontrados na rua)
      var query = _supabase
          .from('pet_found_alerts')
          .select()
          .eq('status', 'active')
          .eq('pet_type', filters.petType.name);

      if (excludePetId != null && excludePetId.isNotEmpty) {
        query = query.neq('id', excludePetId);
      }

      final foundData = await query.order('created_at', ascending: false).limit(limit);

      final List<PetLostAlertEntity> results = [];

      for (final json in foundData) {
        final breedStr = json['breed'] as String?;
        results.add(
          PetLostAlertEntity(
            id: json['id'] as String,
            userId: json['user_id'] as String,
            petName: breedStr != null && breedStr.isNotEmpty
                ? 'Pet Encontrado ($breedStr)'
                : 'Pet Encontrado',
            petType: filters.petType,
            breed: breedStr,
            description: json['description'] as String? ?? '',
            lastLocation: json['found_location'] as String? ?? '',
            lostDate: json['created_at'] != null
                ? DateTime.parse(json['created_at'] as String)
                : DateTime.now(),
            contact: json['contact'] as String? ?? '',
            imageUrl: json['image_url'] as String?,
            latitude: json['latitude'] != null
                ? (json['latitude'] as num).toDouble()
                : null,
            longitude: json['longitude'] != null
                ? (json['longitude'] as num).toDouble()
                : null,
          ),
        );
      }

      // Se houver registros em pet_found_alerts, retorna eles
      if (results.isNotEmpty) {
        return results;
      }

      // 2. Fallback: busca em pet_lost_alerts caso não haja nenhum pet_found
      var lostQuery = _supabase
          .from('pet_lost_alerts')
          .select()
          .eq('status', 'active')
          .eq('pet_type', filters.petType.name);

      if (excludePetId != null && excludePetId.isNotEmpty) {
        lostQuery = lostQuery.neq('id', excludePetId);
      }

      final lostData = await lostQuery.order('created_at', ascending: false).limit(limit);
      return lostData.map((json) => PetLostAlertEntity.fromJson(json)).toList();
    } catch (e, st) {
      _logger.e('Erro ao buscar candidatos no banco.', error: e, stackTrace: st);
      return [];
    }
  }

  /// Recupera os embeddings de imagens existentes de um pet diretamente do Supabase.
  Future<Map<String, List<double>>> getExistingPetImageEmbeddings(String petId) async {
    final Map<String, List<double>> embeddings = {};
    if (_inMemoryPetImages.containsKey(petId)) {
      embeddings.addAll(_inMemoryPetImages[petId]!);
    }

    try {
      final data = await _supabase
          .from('pet_images')
          .select('image_url, embedding')
          .eq('pet_id', petId);

      for (final row in data) {
        final url = row['image_url'] as String?;
        final rawEmb = row['embedding'];
        if (url != null && rawEmb != null) {
          final emb = VectorMath.parseEmbedding(rawEmb);
          if (emb != null && VectorMath.isValidEmbedding(emb)) {
            embeddings[url] = emb;
          }
        }
      }
      return embeddings;
    } catch (e, st) {
      _logger.w('Erro ao consultar embeddings existentes de pet_images. Usando cache local se houver.', error: e, stackTrace: st);
      return embeddings;
    }
  }

  /// Recupera as URLs das imagens cadastradas para um pet (até 3) na ordem de inserção.
  Future<List<String>> getPetImageUrls(String petId) async {
    try {
      final data = await _supabase
          .from('pet_images')
          .select('image_url')
          .eq('pet_id', petId)
          .order('created_at', ascending: true);

      final urls = <String>[];
      for (final row in data) {
        final url = row['image_url'] as String?;
        if (url != null &&
            url.trim().isNotEmpty &&
            !urls.contains(url.trim())) {
          urls.add(url.trim());
        }
      }
      return urls.take(3).toList();
    } catch (e, st) {
      _logger.w(
        'Erro ao consultar URLs de imagens do pet.',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// Sincroniza a tabela pet_images com as URLs ativas do anúncio:
  /// Remove da tabela pet_images registros que não pertençam mais a [activeImageUrls].
  /// Nunca apaga arquivos do Storage, apenas desassocia registros de embeddings obsoletos.
  Future<void> pruneStalePetImages({
    required String petId,
    required List<String> activeImageUrls,
  }) async {
    if (_inMemoryPetImages.containsKey(petId)) {
      if (activeImageUrls.isEmpty) {
        _inMemoryPetImages.remove(petId);
      } else {
        _inMemoryPetImages[petId]!.removeWhere((url, _) => !activeImageUrls.contains(url));
      }
    }

    try {
      if (activeImageUrls.isEmpty) {
        // Se o anúncio não tem imagens ativas, limpa todas as imagens daquele pet
        await _supabase.from('pet_images').delete().eq('pet_id', petId);
        _logger.i('Todas as imagens de pet_images foram limpas para o pet.', context: {'petId': petId});
        return;
      }

      // Consulta imagens atuais para identificar quais foram removidas
      final current = await _supabase
          .from('pet_images')
          .select('image_url')
          .eq('pet_id', petId);

      final List<String> urlsToDelete = [];
      for (final row in current) {
        final url = row['image_url'] as String?;
        if (url != null && !activeImageUrls.contains(url)) {
          urlsToDelete.add(url);
        }
      }

      if (urlsToDelete.isNotEmpty) {
        await _supabase
            .from('pet_images')
            .delete()
            .eq('pet_id', petId)
            .inFilter('image_url', urlsToDelete);

        _logger.i('Imagens desvinculadas removidas de pet_images com sucesso.', context: {
          'petId': petId,
          'removedCount': urlsToDelete.length,
          'removedUrls': urlsToDelete,
        });
      }
    } catch (e, st) {
      _logger.w('Aviso ao sincronizar e podar imagens obsoletas de pet_images.', error: e, stackTrace: st);
    }
  }

  /// Salva ou atualiza uma imagem individual e seu embedding na tabela pet_images com idempotência.
  Future<void> savePetImage({
    required String petId,
    required String imageUrl,
    String status = 'processed',
    List<double>? embedding,
  }) async {
    if (embedding != null && VectorMath.isValidEmbedding(embedding)) {
      _inMemoryPetImages.putIfAbsent(petId, () => {})[imageUrl] = embedding;
    }

    try {
      await _supabase.from('pet_images').upsert(
        {
          'pet_id': petId,
          'image_url': imageUrl,
          'status': status,
          'embedding': embedding,
        },
        onConflict: 'pet_id,image_url',
      );
      _logger.i('Imagem e embedding persistidos (upsert) em pet_images.', context: {'petId': petId});
    } catch (e, st) {
      _logger.w('Aviso: Não foi possível persistir em pet_images no Supabase.', error: e, stackTrace: st);
    }
  }

  /// Registra uma correspondência utilizando a RPC segura save_match no Supabase.
  /// Apenas correspondências com similarityScore >= 0.88 são persistidas.
  /// O servidor valida autenticação, titularidade, espécies e calcula a pontuação oficial
  /// utilizando a fórmula balanceada multi-sinal (0.50 maior + 0.30 média + 0.20 agregado).
  Future<void> saveMatch({
    required String lostPetId,
    required String foundPetId,
    required double similarityScore,
    String matchMethod = 'visual_multi_vector',
    List<double> individualScores = const [],
    String origin = 'manual',
  }) async {
    if (similarityScore < RecognitionConfig.kSimilarityThreshold) {
      _logger.i('Score de similaridade abaixo do limiar padrão (${RecognitionConfig.kSimilarityThreshold}), match descartado.', context: {
        'lostPetId': lostPetId,
        'foundPetId': foundPetId,
        'similarity': similarityScore,
      });
      return;
    }

    _logger.i('Persistindo correspondência via RPC segura save_match.', context: {
      'lostPetId': lostPetId,
      'foundPetId': foundPetId,
      'similarity': similarityScore,
      'origin': origin,
    });

    final pairKey = '${lostPetId}_$foundPetId';
    _inMemoryMatches[pairKey] = {
      'lost_pet_id': lostPetId,
      'found_pet_id': foundPetId,
      'similarity_score': similarityScore,
      'match_method': matchMethod,
      'status': 'pending',
      'origin': origin,
      'individual_scores': individualScores,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final res = await _supabase.rpc(
        'save_match',
        params: {
          'p_lost_pet_id': lostPetId,
          'p_found_pet_id': foundPetId,
          'p_match_method': matchMethod,
          'p_similarity_threshold': RecognitionConfig.kSimilarityThreshold,
        },
      );
      if (res is Map && res['similarity_score'] != null) {
        final serverScore = (res['similarity_score'] as num).toDouble();
        _inMemoryMatches[pairKey]!['similarity_score'] = serverScore;
        if (res['origin'] != null) {
          _inMemoryMatches[pairKey]!['origin'] = res['origin'];
        }
      }
      _logger.i('Match gravado com sucesso no Supabase via RPC save_match.', context: {'res': res});
    } catch (e, st) {
      _logger.w('Aviso ao persistir match via RPC save_match. Mantido em cache local.', error: e, stackTrace: st);
    }
  }

  /// Executa chamada à função RPC de matching vetorial (match_found_pets_for_lost ou match_lost_pets_for_found).
  /// O embedding oficial é consumido diretamente pelo servidor no PostgreSQL a partir do animal de origem.
  Future<List<Map<String, dynamic>>> callMatchRpc({
    required String functionName,
    required String targetPetType,
    required String excludePetId,
    double similarityThreshold = RecognitionConfig.kSimilarityThreshold,
    int matchLimit = 20,
  }) async {
    try {
      final response = await _supabase.rpc(
        functionName,
        params: {
          'p_source_pet_id': excludePetId,
          'target_pet_type': targetPetType,
          'exclude_pet_id': excludePetId,
          'similarity_threshold': similarityThreshold,
          'match_limit': matchLimit,
        },
      );

      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
      return [];
    } catch (e, st) {
      _logger.w('Aviso ao executar RPC $functionName.', error: e, stackTrace: st);
      return [];
    }
  }

  /// Recupera as correspondências persistidas no banco para um pet perdido.
  Future<List<Map<String, dynamic>>> getMatchesForLostPet(
    String lostPetId, {
    double minScore = RecognitionConfig.kSimilarityThreshold,
  }) async {
    try {
      final data = await _supabase
          .from('matches')
          .select('*, pet_found_alerts(*)')
          .eq('lost_pet_id', lostPetId)
          .gte('similarity_score', minScore)
          .order('similarity_score', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e, st) {
      _logger.w('Aviso ao buscar matches persistidos do pet perdido.', error: e, stackTrace: st);
      return [];
    }
  }

  /// Consulta a pontuação de similaridade persistida para um par de pets na tabela matches.
  Future<double?> getMatchScore(String lostPetId, String foundPetId) async {
    final pairKey = '${lostPetId}_$foundPetId';
    if (_inMemoryMatches.containsKey(pairKey)) {
      final memScore = _inMemoryMatches[pairKey]!['similarity_score'];
      if (memScore != null) return (memScore as num).toDouble();
    }

    try {
      final data = await _supabase
          .from('matches')
          .select('similarity_score')
          .eq('lost_pet_id', lostPetId)
          .eq('found_pet_id', foundPetId)
          .maybeSingle();

      if (data != null && data['similarity_score'] != null) {
        return (data['similarity_score'] as num).toDouble();
      }
    } catch (e, st) {
      _logger.w('Aviso ao consultar score em matches.', error: e, stackTrace: st);
    }
    return null;
  }
}
