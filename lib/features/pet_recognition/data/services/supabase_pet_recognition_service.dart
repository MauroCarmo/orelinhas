import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart';
import '../../domain/models/pet_cadastral_filter_entity.dart';
import '../../domain/models/pet_visual_profile_entity.dart';

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

  /// Salva uma imagem individual e seu embedding na tabela pet_images.
  Future<void> savePetImage({
    required String petId,
    required String imageUrl,
    String status = 'processed',
    List<double>? embedding,
  }) async {
    try {
      await _supabase.from('pet_images').insert({
        'pet_id': petId,
        'image_url': imageUrl,
        'status': status,
        'embedding': embedding,
      });
      _logger.i('Imagem e embedding persistidos em pet_images.', context: {'petId': petId});
    } catch (e, st) {
      _logger.w('Aviso: Não foi possível persistir em pet_images no Supabase.', error: e, stackTrace: st);
    }
  }

  /// Registra uma correspondência na tabela matches (ativa o trigger de notificação).
  Future<void> saveMatch({
    required String lostPetId,
    required String foundPetId,
    required double similarityScore,
    String matchMethod = 'visual',
    List<double> individualScores = const [],
  }) async {
    _logger.i('Persistindo correspondência na tabela matches.', context: {
      'lostPetId': lostPetId,
      'foundPetId': foundPetId,
      'similarity': similarityScore,
    });

    try {
      await _supabase.from('matches').upsert(
        {
          'lost_pet_id': lostPetId,
          'found_pet_id': foundPetId,
          'similarity_score': similarityScore,
          'match_method': matchMethod,
          'status': 'pending',
          'individual_scores': individualScores,
          'created_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'lost_pet_id,found_pet_id',
      );
      _logger.i('Match gravado com sucesso no Supabase.');
    } catch (e, st) {
      _logger.w('Aviso ao persistir match no Supabase.', error: e, stackTrace: st);
    }
  }
}
