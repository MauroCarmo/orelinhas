import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/exceptions/error_mapper.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/validation/sanitizers.dart';
import '../domain/pet_adoption_entity.dart';

final petAdoptionRepositoryProvider = Provider<PetAdoptionRepository>((ref) {
  final supabase = ref.read(supabaseClientProvider);
  return PetAdoptionRepository(supabase);
});

class PetAdoptionRepository {
  final SupabaseClient _supabase;
  final _logger = AppLogger.category('PetAdoptionRepository');

  PetAdoptionRepository(this._supabase);

  /// Recupera todos os anúncios públicos de adoção (Feed).
  Future<List<PetAdoptionAlertEntity>> getPublicAdoptions({int limit = 50, int offset = 0}) async {
    _logger.i('Buscando feed público de adoção de pets.', context: {'limit': limit, 'offset': offset});

    try {
      final data = await _supabase
          .from('pet_adoption_alerts')
          .select()
          .eq('status', 'available')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      _logger.i('Feed público de adoção recuperado com sucesso.', context: {
        'count': data.length,
      });

      return data.map((json) => PetAdoptionAlertEntity.fromJson(json)).toList();
    } catch (e, st) {
      _logger.e('Erro técnico ao buscar feed público de adoção no Supabase.', error: e, stackTrace: st);
      throw AppErrorMapper.map(e, st);
    }
  }

  /// Recupera todos os anúncios de adoção do usuário logado.
  Future<List<PetAdoptionAlertEntity>> getUserAdoptions(String userId, {int limit = 50, int offset = 0}) async {
    _logger.i('Buscando anúncios de adoção do usuário.', context: {'userId': userId, 'limit': limit, 'offset': offset});

    try {
      final data = await _supabase
          .from('pet_adoption_alerts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      _logger.i('Anúncios de adoção do usuário recuperados com sucesso.', context: {
        'userId': userId,
        'count': data.length,
      });

      return data.map((json) => PetAdoptionAlertEntity.fromJson(json)).toList();
    } catch (e, st) {
      _logger.e('Erro técnico ao buscar anúncios de adoção no Supabase.', error: e, stackTrace: st, context: {'userId': userId});
      throw AppErrorMapper.map(e, st);
    }
  }

  /// Insere um novo anúncio de adoção.
  Future<void> createAdoption(String userId, PetAdoptionAlertEntity adoption) async {
    _logger.i('Iniciando criação de anúncio de adoção no repositório.', context: {'userId': userId});

    final sanitized = adoption.copyWith(
      userId: userId,
      name: AppSanitizers.sanitizeText(adoption.name),
      characteristics: AppSanitizers.sanitizeText(adoption.characteristics),
      region: AppSanitizers.sanitizeText(adoption.region),
      imageUrl: AppSanitizers.trim(adoption.imageUrl),
    );

    try {
      await _supabase.from('pet_adoption_alerts').insert(sanitized.toJson());
      _logger.i('Anúncio de adoção inserido com sucesso.', context: {'userId': userId});
    } catch (e, st) {
      _logger.e('Erro técnico ao inserir anúncio de adoção no Supabase.', error: e, stackTrace: st, context: {'userId': userId});
      throw AppErrorMapper.map(e, st);
    }
  }

  /// Atualiza um anúncio de adoção existente.
  Future<void> updateAdoption(String userId, PetAdoptionAlertEntity adoption) async {
    _logger.i('Iniciando atualização de anúncio de adoção no repositório.', context: {'id': adoption.id, 'userId': userId});

    final sanitized = adoption.copyWith(
      userId: userId,
      name: AppSanitizers.sanitizeText(adoption.name),
      characteristics: AppSanitizers.sanitizeText(adoption.characteristics),
      region: AppSanitizers.sanitizeText(adoption.region),
      imageUrl: AppSanitizers.trim(adoption.imageUrl),
    );

    try {
      await _supabase
          .from('pet_adoption_alerts')
          .update(sanitized.toJson())
          .eq('id', adoption.id)
          .eq('user_id', userId);
      _logger.i('Anúncio de adoção atualizado com sucesso.', context: {'id': adoption.id, 'userId': userId});
    } catch (e, st) {
      _logger.e('Erro técnico ao atualizar anúncio de adoção no Supabase.', error: e, stackTrace: st, context: {'id': adoption.id, 'userId': userId});
      throw AppErrorMapper.map(e, st);
    }
  }

  /// Exclui um anúncio de adoção do banco.
  Future<void> deleteAdoption(String userId, String id) async {
    _logger.i('Iniciando exclusão de anúncio de adoção no repositório.', context: {'id': id, 'userId': userId});

    try {
      await _supabase
          .from('pet_adoption_alerts')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
      _logger.i('Anúncio de adoção excluído com sucesso.', context: {'id': id, 'userId': userId});
    } catch (e, st) {
      _logger.e('Erro técnico ao excluir anúncio de adoção no Supabase.', error: e, stackTrace: st, context: {'id': id, 'userId': userId});
      throw AppErrorMapper.map(e, st);
    }
  }

  /// Marca um anúncio como adotado (status = 'adopted').
  Future<void> markAsAdopted(String userId, String id) async {
    _logger.i('Marcando anúncio de adoção como adotado.', context: {'id': id, 'userId': userId});

    try {
      await _supabase
          .from('pet_adoption_alerts')
          .update({'status': 'adopted'})
          .eq('id', id)
          .eq('user_id', userId);
      _logger.i('Anúncio marcado como adotado com sucesso.', context: {'id': id});
    } catch (e, st) {
      _logger.e('Erro ao marcar anúncio como adotado.', error: e, stackTrace: st, context: {'id': id});
      throw AppErrorMapper.map(e, st);
    }
  }
}
