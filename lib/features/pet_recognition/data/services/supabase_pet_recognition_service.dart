import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart';
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

  SupabasePetRecognitionService(this._supabase);

  /// Salva ou atualiza o perfil visual do pet no banco de dados Supabase.
  Future<void> saveVisualProfile(PetVisualProfileEntity profile) async {
    _logger.i('Salvando perfil visual do pet no Supabase.', context: {
      'petId': profile.petId,
      'imagesCount': profile.images.length,
      'hasAggregatedEmbedding': profile.hasVisualEmbedding,
    });

    try {
      final json = profile.toJson();
      await _supabase.from('pet_visual_profiles').upsert(
            json,
            onConflict: 'pet_id',
          );
      _logger.i('Perfil visual persistido com sucesso no Supabase.');
    } catch (e, st) {
      _logger.e(
        'Erro ao persistir perfil visual no Supabase.',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Recupera o perfil visual de um pet por ID diretamente do Supabase.
  Future<PetVisualProfileEntity?> getVisualProfile(String petId) async {
    try {
      final data = await _supabase
          .from('pet_visual_profiles')
          .select()
          .eq('pet_id', petId)
          .maybeSingle();

      if (data != null) {
        return PetVisualProfileEntity.fromJson(data);
      }
      return null;
    } catch (e, st) {
      _logger.w('Erro ao consultar perfil visual no Supabase.', error: e, stackTrace: st);
      return null;
    }
  }

  /// Recupera perfis visuais em lote por lista de IDs de pets diretamente do Supabase.
  Future<Map<String, PetVisualProfileEntity>> getVisualProfilesByIds(
    List<String> petIds,
  ) async {
    if (petIds.isEmpty) return {};
    final Map<String, PetVisualProfileEntity> results = {};

    try {
      final data = await _supabase
          .from('pet_visual_profiles')
          .select()
          .inFilter('pet_id', petIds);

      for (final row in data) {
        final profile = PetVisualProfileEntity.fromJson(row);
        results[profile.petId] = profile;
      }
    } catch (e, st) {
      _logger.w('Erro ao consultar perfis visuais em lote no Supabase.', error: e, stackTrace: st);
    }

    return results;
  }

  /// Recupera todos os perfis visuais cadastrados para uma espécie específica.
  Future<List<PetVisualProfileEntity>> getVisualProfilesBySpecies(
    PetType petType,
  ) async {
    try {
      final data = await _supabase
          .from('pet_visual_profiles')
          .select()
          .eq('pet_type', petType.name);

      return data.map((row) => PetVisualProfileEntity.fromJson(row)).toList();
    } catch (e, st) {
      _logger.w('Falha ao carregar perfis visuais por espécie no Supabase.', error: e, stackTrace: st);
      return [];
    }
  }

  /// Recupera um único pet encontrado pelo ID, retornando-o como PetLostAlertEntity
  /// (mapeamento compatível com PetMatchCandidateEntity).
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

  /// Recupera um único pet perdido pelo ID, retornando-o como PetLostAlertEntity.
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

  /// Recupera os embeddings de imagens existentes de um pet diretamente do Supabase.
  Future<Map<String, List<double>>> getExistingPetImageEmbeddings(String petId) async {
    final Map<String, List<double>> embeddings = {};

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
    } catch (e, st) {
      _logger.w('Erro ao consultar embeddings existentes de pet_images no Supabase.', error: e, stackTrace: st);
    }
    return embeddings;
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
        'Erro ao consultar URLs de imagens do pet no Supabase.',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// Sincroniza a tabela pet_images com as URLs ativas do anúncio:
  /// Remove da tabela pet_images registros que não pertençam mais a [activeImageUrls].
  Future<void> pruneStalePetImages({
    required String petId,
    required List<String> activeImageUrls,
  }) async {
    try {
      if (activeImageUrls.isEmpty) {
        await _supabase.from('pet_images').delete().eq('pet_id', petId);
        _logger.i('Todas as imagens de pet_images foram limpas para o pet.', context: {'petId': petId});
        return;
      }

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
      _logger.w('Aviso ao sincronizar imagens de pet_images no Supabase.', error: e, stackTrace: st);
    }
  }

  /// Salva ou atualiza uma imagem individual e seu embedding na tabela pet_images com idempotência.
  Future<void> savePetImage({
    required String petId,
    required String imageUrl,
    String status = 'processed',
    List<double>? embedding,
  }) async {
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
      _logger.i('Imagem e embedding persistidos (upsert) em pet_images no Supabase.', context: {'petId': petId});
    } catch (e, st) {
      _logger.w('Aviso: Não foi possível persistir em pet_images no Supabase.', error: e, stackTrace: st);
    }
  }

  /// Registra uma correspondência utilizando a RPC segura save_match no Supabase.
  /// Apenas correspondências com similarityScore >= RecognitionConfig.kSimilarityThreshold são persistidas.
  Future<void> saveMatch({
    required String lostPetId,
    required String foundPetId,
    required double similarityScore,
    String matchMethod = 'visual_multi_vector',
    List<double> individualScores = const [],
    String origin = 'manual',
  }) async {
    if (similarityScore < RecognitionConfig.kSimilarityThreshold) {
      _logger.i('Score de similaridade abaixo do limiar (${RecognitionConfig.kSimilarityThreshold}), match descartado.', context: {
        'lostPetId': lostPetId,
        'foundPetId': foundPetId,
        'similarity': similarityScore,
      });
      return;
    }

    _logger.i('Persistindo correspondência via RPC segura save_match no Supabase.', context: {
      'lostPetId': lostPetId,
      'foundPetId': foundPetId,
      'similarity': similarityScore,
      'origin': origin,
    });

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
      _logger.i('Match gravado com sucesso no Supabase via RPC save_match.', context: {'res': res});
    } catch (e, st) {
      _logger.w('Aviso ao persistir match via RPC save_match no Supabase.', error: e, stackTrace: st);
    }
  }

  /// Executa chamada à função RPC de matching vetorial (match_found_pets_for_lost ou match_lost_pets_for_found).
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
      _logger.w('Aviso ao executar RPC $functionName no Supabase.', error: e, stackTrace: st);
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
      _logger.w('Aviso ao buscar matches persistidos do pet perdido no Supabase.', error: e, stackTrace: st);
      return [];
    }
  }

  /// Consulta a pontuação de similaridade persistida para um par de pets na tabela matches.
  Future<double?> getMatchScore(String lostPetId, String foundPetId) async {
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
      _logger.w('Aviso ao consultar score em matches no Supabase.', error: e, stackTrace: st);
    }
    return null;
  }
}
