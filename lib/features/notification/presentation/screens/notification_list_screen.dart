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

  String? _extractPercentageLabel(NotificationEntity notification) {
    final rawScore = notification.metadata?['similarity_score'];
    if (rawScore is num) {
      return '${(rawScore * 100).toStringAsFixed(1)}%';
    }
    final match = RegExp(
      r'\((\d+(?:\.\d+)?%)\)',
    ).firstMatch(notification.title);
    return match?.group(1);
  }

  String _cleanNotificationTitle(NotificationEntity notification) {
    if (notification.type != NotificationType.matchFound) {
      return notification.title;
    }
    final petName = notification.metadata?['lost_pet_name'] as String?;
    if (petName != null && petName.isNotEmpty) {
      return 'Pet semelhante a "$petName"';
    }
    return notification.title
        .replaceAll(RegExp(r'\s*\(\d+(?:\.\d+)?%\)'), '')
        .trim();
  }

  String _cleanNotificationBody(NotificationEntity notification) {
    if (notification.type != NotificationType.matchFound) {
      return notification.body;
    }

    final raw = notification.body;
    String cityUf = '';

    if (raw.contains('Cidade/UF:')) {
      for (final part in raw.split(' | ')) {
        final item = part.trim();
        if (item.startsWith('Cidade/UF:')) {
          cityUf = item.substring(10).trim();
          final dotIndex = cityUf.indexOf('.');
          if (dotIndex != -1) {
            cityUf = cityUf.substring(0, dotIndex).trim();
          }
          break;
        }
      }
    } else {
      final metaLoc = notification.metadata?['found_location'] as String?;
      if (metaLoc != null && metaLoc.trim().isNotEmpty) {
        cityUf = metaLoc.trim();
      }
    }

    if (cityUf.isNotEmpty) {
      return 'Localizado em ${cityUf.replaceAll('/', '-')}';
    }

    return raw;
  }

  void _handleNotificationTap(
    BuildContext context,
    WidgetRef ref,
    NotificationEntity notification,
  ) {
    if (!notification.isRead) {
      ref
          .read(notificationControllerProvider.notifier)
          .markAsRead(notification.id);
    }

    if (notification.type == NotificationType.matchFound) {
      final foundId = notification.relatedMatchId;
      if (foundId != null && foundId.isNotEmpty) {
        final rawScore = notification.metadata?['similarity_score'];
        final score = rawScore is num ? rawScore.toDouble() : null;

        context.push(
          AppRoutes.matchDetail(
            foundPetId: foundId,
            lostPetId: notification.relatedPetId,
            score: score,
          ),
        );
      } else if (notification.relatedPetId != null &&
          notification.relatedPetId!.isNotEmpty) {
        context.push(AppRoutes.petMatches(notification.relatedPetId!));
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
      backgroundColor: AppColors.scaffoldLight,
      appBar: AppBar(
        title: Text(
          'Notificações',
          style: AppTextStyles.heading2(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              icon: const Icon(Icons.done_all, size: 18, color: Colors.white),
              label: const Text(
                'Marcar lidas',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                ref
                    .read(notificationControllerProvider.notifier)
                    .markAllAsRead();
              },
            ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
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
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Você não possui notificações.',
                      style: AppTextStyles.heading3(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Quando houver novidades sobre seus pets, elas aparecerão aqui.',
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref
                .read(notificationControllerProvider.notifier)
                .refreshNotifications(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: AppColors.border),
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

    final percentageLabel = notification.type == NotificationType.matchFound
        ? _extractPercentageLabel(notification)
        : null;

    return InkWell(
      onTap: () => _handleNotificationTap(context, ref, notification),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: notification.isRead
            ? Colors.transparent
            : Colors.blue.shade50.withValues(alpha: 0.35),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(iconData, size: 22, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _cleanNotificationTitle(notification),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: notification.isRead
                                ? FontWeight.w600
                                : FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (percentageLabel != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            percentageLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade800,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
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
                    _cleanNotificationBody(notification),
                    style: TextStyle(
                      fontSize: 13,
                      color: notification.isRead
                          ? Colors.grey.shade700
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (notification.type == NotificationType.matchFound) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Clique para visualizar correspondência',
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
