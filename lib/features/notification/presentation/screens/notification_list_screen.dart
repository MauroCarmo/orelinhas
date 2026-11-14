import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../pet_lost/presentation/widgets/pet_widgets.dart';
import '../../domain/models/notification_entity.dart';
import '../../domain/models/notification_type.dart';
import '../controllers/notification_controller.dart';

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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Voltar',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        title: const Text('Notificações'),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Marcar lidas'),
              onPressed: () {
                ref
                    .read(notificationControllerProvider.notifier)
                    .markAllAsRead();
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => EmptyState(
          icon: Icons.wifi_off_rounded,
          color: AppColors.error,
          title: 'Erro ao carregar notificações.',
          message: 'Verifique sua conexão e tente novamente.',
          actionLabel: 'Tentar novamente',
          onAction: () => ref
              .read(notificationControllerProvider.notifier)
              .refreshNotifications(),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Nenhuma notificação por aqui',
              message:
                  'Quando houver correspondências de IA ou novidades sobre seus pets, elas aparecerão aqui.',
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref
                .read(notificationControllerProvider.notifier)
                .refreshNotifications(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return _buildNotificationCard(context, ref, notif);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    WidgetRef ref,
    NotificationEntity notification,
  ) {
    final isMatch = notification.type == NotificationType.matchFound;

    IconData iconData;
    Color iconColor;
    Color iconBg;

    switch (notification.type) {
      case NotificationType.matchFound:
        iconData = Icons.auto_awesome_rounded;
        iconColor = AppColors.primary;
        iconBg = AppColors.primarySoft;
        break;
      case NotificationType.petStatusUpdate:
        iconData = Icons.pets_rounded;
        iconColor = AppColors.success;
        iconBg = AppColors.success.withAlpha(28);
        break;
      case NotificationType.system:
        iconData = Icons.info_outline_rounded;
        iconColor = AppColors.textSecondary;
        iconBg = AppColors.scaffoldLight;
        break;
    }

    final percentageLabel = isMatch
        ? _extractPercentageLabel(notification)
        : null;

    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _handleNotificationTap(context, ref, notification),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: notification.isRead
                  ? Colors.transparent
                  : AppColors.primary.withAlpha(90),
              width: 1.2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, size: 22, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _cleanNotificationTitle(notification),
                            style: AppTextStyles.heading3(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (percentageLabel != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              percentageLabel,
                              style: AppTextStyles.label(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _cleanNotificationBody(notification),
                      style: AppTextStyles.body(
                        color: notification.isRead
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _formatTimestamp(notification.createdAt),
                          style: AppTextStyles.bodySmall(),
                        ),
                        if (isMatch) ...[
                          const Spacer(),
                          Text(
                            'Ver correspondência',
                            style: AppTextStyles.label(
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!notification.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.only(top: 6),
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
      ),
    );
  }
}
