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
  Future<List<PetLostAlertEntity>> getCandidateAlerts({
    required PetCadastralFilterEntity filters,
    String? excludePetId,
    int limit = 50,
  }) async {
    _logger.i('Buscando alertas candidatos cadastrais.', context: {
      'species': filters.petType.name,
      'excludePetId': excludePetId,
    });

    try {
      var query = _supabase
          .from('pet_lost_alerts')
          .select()
          .eq('status', 'active')
          .eq('pet_type', filters.petType.name); // Filtro estrito de espécie

      if (excludePetId != null && excludePetId.isNotEmpty) {
        query = query.neq('id', excludePetId);
      }

      final data = await query.order('created_at', ascending: false).limit(limit);

      return data.map((json) => PetLostAlertEntity.fromJson(json)).toList();
    } catch (e, st) {
      _logger.e('Erro ao buscar candidatos no banco.', error: e, stackTrace: st);
      return [];
    }
  }
}
