import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/exceptions/error_mapper.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/validation/sanitizers.dart';
import '../domain/pet_found_entity.dart';

final petFoundRepositoryProvider = Provider<PetFoundRepository>((ref) {
  final supabase = ref.read(supabaseClientProvider);
  return PetFoundRepository(supabase);
});

class PetFoundRepository {
  final SupabaseClient _supabase;
  final _logger = AppLogger.category('PetFoundRepository');

  PetFoundRepository(this._supabase);

  /// Recupera todos os alertas públicos (Feed).
  Future<List<PetFoundAlertEntity>> getPublicAlerts({int limit = 20, int offset = 0}) async {
    _logger.i('Buscando feed público de alertas de pets encontrados.', context: {'limit': limit, 'offset': offset});

    try {
      final data = await _supabase
          .from('pet_found_alerts')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      _logger.i('Feed público recuperado com sucesso.', context: {
        'count': data.length,
      });

      return data.map((json) => PetFoundAlertEntity.fromJson(json)).toList();
    } catch (e, st) {
      _logger.e('Erro técnico ao buscar feed público no Supabase.', error: e, stackTrace: st);
      throw AppErrorMapper.map(e, st);
    }
  }

  /// Recupera todos os alertas de pets encontrados do usuário logado.
  Future<List<PetFoundAlertEntity>> getUserAlerts(String userId, {int limit = 20, int offset = 0}) async {
    _logger.i('Buscando alertas de pets encontrados do usuário.', context: {'userId': userId, 'limit': limit, 'offset': offset});

    try {
      final data = await _supabase
          .from('pet_found_alerts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      _logger.i('Alertas recuperados com sucesso.', context: {
        'userId': userId,
        'count': data.length,
      });

      return data.map((json) => PetFoundAlertEntity.fromJson(json)).toList();
    } catch (e, st) {
      _logger.e('Erro técnico ao buscar alertas no Supabase.', error: e, stackTrace: st, context: {'userId': userId});
      throw AppErrorMapper.map(e, st);
    }
  }

  /// Insere um novo alerta de pet encontrado.
  Future<void> createAlert(String userId, PetFoundAlertEntity alert) async {
    _logger.i('Iniciando criação de alerta de pet encontrado no repositório.', context: {'userId': userId});

    final sanitizedAlert = alert.copyWith(
      userId: userId,
      breed: alert.breed != null ? AppSanitizers.sanitizeText(alert.breed) : null,
      apparentAge: alert.apparentAge != null ? AppSanitizers.sanitizeText(alert.apparentAge) : null,
      description: AppSanitizers.sanitizeText(alert.description),
      foundLocation: AppSanitizers.sanitizeText(alert.foundLocation),
      contact: alert.contact != null && alert.contact!.isNotEmpty
          ? AppSanitizers.digitsOnly(alert.contact)
          : null,
      imageUrl: AppSanitizers.trim(alert.imageUrl),
    );

    try {
      await _supabase.from('pet_found_alerts').insert(sanitizedAlert.toJson());
      _logger.i('Alerta de pet encontrado inserido com sucesso.', context: {'userId': userId});
    } catch (e, st) {
      _logger.e('Erro técnico ao inserir alerta no Supabase.', error: e, stackTrace: st, context: {'userId': userId});
      throw AppErrorMapper.map(e, st);
    }
  }

  /// Atualiza um alerta de pet encontrado existente.
  Future<void> updateAlert(String userId, PetFoundAlertEntity alert) async {
    _logger.i('Iniciando atualização de alerta de pet encontrado no repositório.', context: {'alertId': alert.id, 'userId': userId});

    final sanitizedAlert = alert.copyWith(
      userId: userId,
      breed: alert.breed != null ? AppSanitizers.sanitizeText(alert.breed) : null,
      apparentAge: alert.apparentAge != null ? AppSanitizers.sanitizeText(alert.apparentAge) : null,
      description: AppSanitizers.sanitizeText(alert.description),
      foundLocation: AppSanitizers.sanitizeText(alert.foundLocation),
      contact: alert.contact != null && alert.contact!.isNotEmpty
          ? AppSanitizers.digitsOnly(alert.contact)
          : null,
      imageUrl: AppSanitizers.trim(alert.imageUrl),
    );

    try {
      await _supabase
          .from('pet_found_alerts')
          .update(sanitizedAlert.toJson())
          .eq('id', alert.id)
          .eq('user_id', userId);
      _logger.i('Alerta de pet encontrado atualizado com sucesso.', context: {'alertId': alert.id, 'userId': userId});
    } catch (e, st) {
      _logger.e('Erro técnico ao atualizar alerta no Supabase.', error: e, stackTrace: st, context: {'alertId': alert.id, 'userId': userId});
      throw AppErrorMapper.map(e, st);
    }
  }

  /// Exclui um alerta de pet encontrado do banco.
  Future<void> deleteAlert(String userId, String id) async {
    _logger.i('Iniciando exclusão de alerta de pet encontrado no repositório.', context: {'alertId': id, 'userId': userId});

    try {
      await _supabase
          .from('pet_found_alerts')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
      _logger.i('Alerta de pet encontrado excluído com sucesso.', context: {'alertId': id, 'userId': userId});
    } catch (e, st) {
      _logger.e('Erro técnico ao excluir alerta no Supabase.', error: e, stackTrace: st, context: {'alertId': id, 'userId': userId});
      throw AppErrorMapper.map(e, st);
    }
  }

  /// Marca um alerta como resolvido (status = 'resolved').
  Future<void> resolveAlert(String userId, String alertId) async {
    _logger.i('Marcando alerta como resolvido.', context: {'alertId': alertId, 'userId': userId});

    try {
      await _supabase
          .from('pet_found_alerts')
          .update({'status': 'resolved'})
          .eq('id', alertId)
          .eq('user_id', userId);
      _logger.i('Alerta resolvido com sucesso.', context: {'alertId': alertId});
    } catch (e, st) {
      _logger.e('Erro ao marcar alerta como resolvido.', error: e, stackTrace: st, context: {'alertId': alertId});
      throw AppErrorMapper.map(e, st);
    }
  }
}
