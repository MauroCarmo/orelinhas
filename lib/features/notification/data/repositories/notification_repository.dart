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
    _logger.i(
      'Obtendo notificações do usuário no repositório.',
      context: {'userId': userId},
    );
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

  String _extractCityUf(String rawLocation) {
    final trimmed = rawLocation.trim();
    if (trimmed.contains('Cidade/UF:')) {
      for (final part in trimmed.split(' | ')) {
        final item = part.trim();
        if (item.startsWith('Cidade/UF:')) {
          return item.substring(10).trim().replaceAll('/', '-');
        }
      }
    }
    return trimmed.replaceAll('/', '-');
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
    _logger.i(
      'Gerando notificação de match visual/cadastral.',
      context: {
        'recipientUserId': recipientUserId,
        'lostPetId': lostPetId,
        'foundPetId': foundPetId,
        'similarity': similarityScore,
      },
    );

    final cityUf = _extractCityUf(foundLocation);
    final bodyText = cityUf.isNotEmpty
        ? 'Localizado em $cityUf'
        : 'Nova correspondência visual identificada';
    final deterministicId =
        'notif_match_${recipientUserId}_${lostPetId}_$foundPetId';

    final notification = NotificationEntity(
      id: deterministicId,
      userId: recipientUserId,
      type: NotificationType.matchFound,
      title: 'Pet semelhante a "$lostPetName"',
      body: bodyText,
      createdAt: DateTime.now(),
      isRead: false,
      relatedPetId: lostPetId,
      relatedMatchId: foundPetId,
      metadata: {
        'similarity_score': similarityScore,
        'lost_pet_name': lostPetName,
        'found_location': cityUf,
      },
    );

    await _service.createNotification(notification);
  }
}
