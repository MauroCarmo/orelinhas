import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/models/notification_entity.dart';

final supabaseNotificationServiceProvider =
    Provider<SupabaseNotificationService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return SupabaseNotificationService(supabase);
});

/// Serviço de integração com o Supabase para gerenciar a persistência e atualização de notificações.
class SupabaseNotificationService {
  final SupabaseClient _supabase;
  final _logger = AppLogger.category('SupabaseNotificationService');

  SupabaseNotificationService(this._supabase);

  /// Recupera as notificações do usuário ordenadas da mais recente para a mais antiga diretamente do Supabase.
  Future<List<NotificationEntity>> getNotifications(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    _logger.i('Buscando notificações do usuário no Supabase.', context: {
      'userId': userId,
      'limit': limit,
    });

    try {
      final data = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final list = (data as List<dynamic>)
          .map((json) =>
              NotificationEntity.fromJson(json as Map<String, dynamic>))
          .toList();

      return list;
    } catch (e, st) {
      _logger.e(
        'Falha ao carregar notificações do Supabase.',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// Marca uma notificação específica como lida no Supabase.
  Future<void> markAsRead(String userId, String notificationId) async {
    _logger.i('Marcando notificação como lida no Supabase.', context: {
      'userId': userId,
      'notificationId': notificationId,
    });

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', userId);
    } catch (e, st) {
      _logger.w('Erro ao marcar notificação no Supabase.', error: e, stackTrace: st);
    }
  }

  /// Marca todas as notificações do usuário como lidas no Supabase.
  Future<void> markAllAsRead(String userId) async {
    _logger.i('Marcando todas as notificações como lidas no Supabase.', context: {
      'userId': userId,
    });

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e, st) {
      _logger.w('Erro ao marcar todas notificações no Supabase.', error: e, stackTrace: st);
    }
  }

  /// Registra ou atualiza o token de push do usuário no Supabase.
  Future<void> updatePushToken(
    String userId,
    String token, {
    String deviceType = 'flutter',
  }) async {
    _logger.i('Atualizando token de push do usuário.', context: {
      'userId': userId,
      'deviceType': deviceType,
    });

    try {
      await _supabase.from('user_push_tokens').upsert(
        {
          'user_id': userId,
          'token': token,
          'device_type': deviceType,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,token',
      );
    } catch (e, st) {
      _logger.w('Erro ao salvar token de push no Supabase.', error: e, stackTrace: st);
    }
  }

  /// Registra notificação diretamente no Supabase.
  Future<void> createNotification(NotificationEntity notification) async {
    try {
      await _supabase.from('notifications').upsert(
            notification.toJson(),
            onConflict: 'id',
          );
    } catch (e, st) {
      _logger.w('Erro ao inserir notificação no Supabase.', error: e, stackTrace: st);
    }
  }
}
