import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/exceptions/error_mapper.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/validation/sanitizers.dart';
import '../domain/pet_lost_entity.dart';

final petLostRepositoryProvider = Provider<PetLostRepository>((ref) {
  final supabase = ref.read(supabaseClientProvider);
  return PetLostRepository(supabase);
});

class PetLostRepository {
  final SupabaseClient _supabase;
  final _logger = AppLogger.category('PetLostRepository');

  PetLostRepository(this._supabase);

  /// Recupera todos os alertas públicos (Feed).
  Future<List<PetLostAlertEntity>> getPublicAlerts({int limit = 20, int offset = 0}) async {
    _logger.i('Buscando feed público de alertas de pets perdidos.', context: {'limit': limit, 'offset': offset});

    try {
      final data = await _supabase
          .from('pet_lost_alerts')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      _logger.i('Feed público recuperado com sucesso.', context: {
        'count': data.length,
      });

      return data.map((json) => PetLostAlertEntity.fromJson(json)).toList();
    } catch (e, st) {
      _logger.e('Erro técnico ao buscar feed público no Supabase.', error: e, stackTrace: st);
      throw AppErrorMapper.map(e, st);
    }
  }

  /// Recupera todos os alertas de pets perdidos do usuário logado.
  /// A segurança é garantida pela RLS do Supabase, mas também aplicamos o
  /// Defensive Query Design realizando o filtro explícito no código.
  Future<List<PetLostAlertEntity>> getUserAlerts(String userId, {int limit = 20, int offset = 0}) async {
    _logger.i('Buscando alertas de pets perdidos do usuário.', context: {'userId': userId, 'limit': limit, 'offset': offset});

    try {
      final data = await _supabase
          .from('pet_lost_alerts')
          .select()
          .eq('user_id', userId) // Defensive Query Design
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      _logger.i('Alertas recuperados com sucesso.', context: {
        'userId': userId,
        'count': data.length,
      });

      return data.map((json) => PetLostAlertEntity.fromJson(json)).toList();
    } catch (e, st) {
      _logger.e('Erro técnico ao buscar alertas no Supabase.', error: e, stackTrace: st, context: {'userId': userId});
      throw AppErrorMapper.map(e, st);
    }
  }

  /// Insere um novo alerta de pet perdido.
  /// Realiza a sanitização exclusiva dos campos técnicos antes de persistir.
  /// O user_id é imperativamente injetado a partir da sessão autenticada.
  Future<void> createAlert(String userId, PetLostAlertEntity alert) async {
    _logger.i('Iniciando criação de alerta de pet perdido no repositório.', context: {'userId': userId});

    // Sanitização de dados ANTES da persistência (Exclusividade do Repositório)
    // E injeção estritamente imperativa do user_id da sessão ativa (UI input is ignored)
    final sanitizedAlert = alert.copyWith(
      userId: userId,
      petName: AppSanitizers.sanitizeText(alert.petName),
      breed: alert.breed != null ? AppSanitizers.sanitizeText(alert.breed) : null,
      age: alert.age != null ? AppSanitizers.sanitizeText(alert.age) : null,
      description: AppSanitizers.sanitizeText(alert.description),
      lastLocation: AppSanitizers.sanitizeText(alert.lastLocation),
      contact: AppSanitizers.digitsOnly(alert.contact),
      imageUrl: alert.imageUrl != null ? AppSanitizers.trim(alert.imageUrl) : null,
    );

    try {
      await _supabase.from('pet_lost_alerts').insert(sanitizedAlert.toJson());
      _logger.i('Alerta de pet perdido inserido com sucesso.', context: {'userId': userId});
    } catch (e, st) {
      _logger.e('Erro técnico ao inserir alerta no Supabase.', error: e, stackTrace: st, context: {'userId': userId});
      throw AppErrorMapper.map(e, st);
    }
  }

  /// Atualiza um alerta de pet perdido existente.
  /// Realiza a sanitização exclusiva dos campos técnicos antes de persistir.
  /// Valida o pertencimento de forma defensiva usando o user_id da sessão autenticada.
  Future<void> updateAlert(String userId, PetLostAlertEntity alert) async {
    _logger.i('Iniciando atualização de alerta de pet perdido no repositório.', context: {'alertId': alert.id, 'userId': userId});

    // Sanitização de dados ANTES da persistência (Exclusividade do Repositório)
    // E injeção estritamente imperativa do user_id da sessão ativa
    final sanitizedAlert = alert.copyWith(
      userId: userId,
      petName: AppSanitizers.sanitizeText(alert.petName),
      breed: alert.breed != null ? AppSanitizers.sanitizeText(alert.breed) : null,
      age: alert.age != null ? AppSanitizers.sanitizeText(alert.age) : null,
      description: AppSanitizers.sanitizeText(alert.description),
      lastLocation: AppSanitizers.sanitizeText(alert.lastLocation),
      contact: AppSanitizers.digitsOnly(alert.contact),
      imageUrl: alert.imageUrl != null ? AppSanitizers.trim(alert.imageUrl) : null,
    );

    try {
      await _supabase
          .from('pet_lost_alerts')
          .update(sanitizedAlert.toJson())
          .eq('id', alert.id)
          .eq('user_id', userId); // Defensive Query Design: Scope strictly to active user
      _logger.i('Alerta de pet perdido atualizado com sucesso.', context: {'alertId': alert.id, 'userId': userId});
    } catch (e, st) {
      _logger.e('Erro técnico ao atualizar alerta no Supabase.', error: e, stackTrace: st, context: {'alertId': alert.id, 'userId': userId});
      throw AppErrorMapper.map(e, st);
    }
  }

  /// Exclui um alerta de pet perdido do banco com filtro de user_id defensivo.
  Future<void> deleteAlert(String userId, String id) async {
    _logger.i('Iniciando exclusão de alerta de pet perdido no repositório.', context: {'alertId': id, 'userId': userId});

    try {
      await _supabase
          .from('pet_lost_alerts')
          .delete()
          .eq('id', id)
          .eq('user_id', userId); // Defensive Query Design: Scope strictly to active user
      _logger.i('Alerta de pet perdido excluído com sucesso.', context: {'alertId': id, 'userId': userId});
    } catch (e, st) {
      _logger.e('Erro técnico ao excluir alerta no Supabase.', error: e, stackTrace: st, context: {'alertId': id, 'userId': userId});
      throw AppErrorMapper.map(e, st);
    }
  }

  /// Marca um alerta como resolvido (status = 'resolved').
  Future<void> resolveAlert(String userId, String alertId) async {
    _logger.i(
      'Marcando alerta como resolvido.',
      context: {'alertId': alertId, 'userId': userId},
    );

    try {
      await _supabase
          .from('pet_lost_alerts')
          .update({'status': 'resolved'})
          .eq('id', alertId)
          .eq('user_id', userId); // Defensive Query Design
      _logger.i('Alerta resolvido com sucesso.', context: {'alertId': alertId});
    } catch (e, st) {
      _logger.e(
        'Erro ao marcar alerta como resolvido.',
        error: e,
        stackTrace: st,
        context: {'alertId': alertId},
      );
      throw AppErrorMapper.map(e, st);
    }
  }
}
