import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/models/notification_entity.dart';
import '../../domain/models/notification_type.dart';
import '../services/supabase_notification_service.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final service = ref.watch(supabaseNotificationServiceProvider);
  return NotificationRepository(service);
});

/// Repositório para orquestrar as notificações do usuário.
class NotificationRepository {
  final SupabaseNotificationService _service;
  final _logger = AppLogger.category('NotificationRepository');

  NotificationRepository(this._service);

  /// Busca a lista de notificações do usuário autenticado.
  Future<List<NotificationEntity>> getUserNotifications(String userId) async {
    _logger.i('Obtendo notificações do usuário no repositório.', context: {'userId': userId});
    return await _service.getNotifications(userId);
  }

  /// Marca uma notificação como lida.
  Future<void> markAsRead(String userId, String notificationId) async {
    await _service.markAsRead(userId, notificationId);
  }

  /// Marca todas as notificações como lidas.
  Future<void> markAllAsRead(String userId) async {
    await _service.markAllAsRead(userId);
  }

  /// Registra o token de push do dispositivo do usuário.
  Future<void> registerPushToken(String userId, String token) async {
    await _service.updatePushToken(userId, token);
  }

  /// Gera uma notificação de match de IA para o tutor do pet perdido.
  Future<void> notifyMatchFound({
    required String recipientUserId,
    required String lostPetName,
    required String foundLocation,
    required String lostPetId,
    required String foundPetId,
    required double similarityScore,
  }) async {
    _logger.i('Gerando notificação de match visual/cadastral.', context: {
      'recipientUserId': recipientUserId,
      'lostPetId': lostPetId,
      'foundPetId': foundPetId,
      'similarity': similarityScore,
    });

    final percentage = (similarityScore * 100).toStringAsFixed(1);
    final notification = NotificationEntity(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      userId: recipientUserId,
      type: NotificationType.matchFound,
      title: 'Possível correspondência encontrada! ($percentage%)',
      body: 'Um pet com características semelhantes a "$lostPetName" foi avistado em $foundLocation. Toque para conferir.',
      createdAt: DateTime.now(),
      isRead: false,
      relatedPetId: lostPetId,
      relatedMatchId: foundPetId,
      metadata: {
        'similarity_score': similarityScore,
        'lost_pet_name': lostPetName,
        'found_location': foundLocation,
      },
    );

    await _service.createNotification(notification);
  }
}
