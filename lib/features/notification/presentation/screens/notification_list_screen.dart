import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/notification_entity.dart';
import '../../domain/models/notification_type.dart';
import '../controllers/notification_controller.dart';

/// Tela de listagem de notificações com suporte a redirecionamento automático para anúncios de pets encontrados.
class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Agora mesmo';
    } else if (difference.inMinutes < 60) {
      return 'Há ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Há ${difference.inHours} h';
    } else if (difference.inDays == 1) {
      return 'Ontem às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      return '$day/$month às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  void _handleNotificationTap(
    BuildContext context,
    WidgetRef ref,
    NotificationEntity notification,
  ) {
    // 1. Marca como lida
    if (!notification.isRead) {
      ref
          .read(notificationControllerProvider.notifier)
          .markAsRead(notification.id);
    }

    // 2. Redirecionamento baseado no tipo e IDs relacionados
    if (notification.type == NotificationType.matchFound) {
      if (notification.relatedPetId != null &&
          notification.relatedPetId!.isNotEmpty) {
        // Redireciona diretamente para a tela de matches do pet do usuário
        context.push(AppRoutes.petMatches(notification.relatedPetId!));
      } else if (notification.relatedMatchId != null &&
          notification.relatedMatchId!.isNotEmpty) {
        // Redireciona para o anúncio do pet encontrado
        context.push(AppRoutes.petFoundEdit(notification.relatedMatchId!));
      }
    } else if (notification.type == NotificationType.petStatusUpdate) {
      if (notification.relatedPetId != null &&
          notification.relatedPetId!.isNotEmpty) {
        context.push(AppRoutes.petLostEdit(notification.relatedPetId!));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationControllerProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Marcar lidas'),
              onPressed: () {
                ref
                    .read(notificationControllerProvider.notifier)
                    .markAllAsRead();
              },
            ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text('Erro ao carregar notificações.'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref
                    .read(notificationControllerProvider.notifier)
                    .refreshNotifications(),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Você não possui notificações.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Quando houver novidades sobre seus pets, elas aparecerão aqui.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref
                .read(notificationControllerProvider.notifier)
                .refreshNotifications(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return _buildNotificationTile(context, ref, notif);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    WidgetRef ref,
    NotificationEntity notification,
  ) {
    IconData iconData;
    Color iconColor;
    Color iconBg;

    switch (notification.type) {
      case NotificationType.matchFound:
        iconData = Icons.auto_awesome;
        iconColor = Colors.purple.shade700;
        iconBg = Colors.purple.shade50;
        break;
      case NotificationType.petStatusUpdate:
        iconData = Icons.pets;
        iconColor = AppColors.primary;
        iconBg = Colors.blue.shade50;
        break;
      case NotificationType.system:
        iconData = Icons.info_outline;
        iconColor = Colors.blueGrey.shade700;
        iconBg = Colors.blueGrey.shade50;
        break;
    }

    return InkWell(
      onTap: () => _handleNotificationTap(context, ref, notification),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: notification.isRead ? Colors.transparent : Colors.blue.shade50.withValues(alpha: 0.35),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícone temático
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, size: 22, color: iconColor),
            ),
            const SizedBox(width: 12),

            // Conteúdo textual
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: notification.isRead
                                ? FontWeight.w600
                                : FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        _formatTimestamp(notification.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: notification.isRead
                          ? Colors.grey.shade700
                          : Colors.black87,
                    ),
                  ),
                  if (notification.type == NotificationType.matchFound) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Toque para visualizar correspondência',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: Colors.purple.shade700,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Ponto indicador de não lida
            if (!notification.isRead) ...[
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
