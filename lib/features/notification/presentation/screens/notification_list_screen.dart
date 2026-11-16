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
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final hPad = isDesktop ? 40.0 : 20.0;

    void markAll() =>
        ref.read(notificationControllerProvider.notifier).markAllAsRead();

    final markAllButton = unreadCount > 0
        ? TextButton.icon(
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: Text(isDesktop ? 'Marcar todas como lidas' : 'Marcar lidas'),
            onPressed: markAll,
          )
        : null;

    final content = notificationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => EmptyState(
        icon: Icons.wifi_off_rounded,
        color: AppColors.error,
        title: 'Erro ao carregar os avisos.',
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
            title: 'Nenhum aviso por aqui',
            message:
                'Quando houver correspondências da IA ou novidades sobre seus pets, elas aparecerão aqui.',
          );
        }

        final unread = notifications.where((n) => !n.isRead).toList();
        final read = notifications.where((n) => n.isRead).toList();

        final items = <Widget>[
          if (unread.isNotEmpty) ...[
            _SectionLabel('Novos', count: unread.length),
            for (final n in unread) _buildNotificationCard(context, ref, n),
          ],
          if (read.isNotEmpty) ...[
            if (unread.isNotEmpty) const SizedBox(height: 10),
            const _SectionLabel('Anteriores'),
            for (final n in read) _buildNotificationCard(context, ref, n),
          ],
        ];

        return RefreshIndicator(
          onRefresh: () => ref
              .read(notificationControllerProvider.notifier)
              .refreshNotifications(),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 28),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => Center(
              child: ConstrainedBox(
                // Largura confortável de leitura no PC
                constraints: const BoxConstraints(maxWidth: 820),
                child: items[index],
              ),
            ),
          ),
        );
      },
    );

    if (isDesktop) {
      return Scaffold(
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Avisos',
                              style: AppTextStyles.heading1().copyWith(
                                fontSize: 28,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Correspondências da IA e novidades sobre seus pets.',
                              style: AppTextStyles.body(
                                color: AppColors.textSecondary,
                              ).copyWith(fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                      ?markAllButton,
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        // Aba principal (Avisos): sem botão de voltar
        automaticallyImplyLeading: false,
        title: const Text('Avisos'),
        actions: [?markAllButton, const SizedBox(width: 4)],
      ),
      body: content,
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    WidgetRef ref,
    NotificationEntity notification,
  ) {
    final isMatch = notification.type == NotificationType.matchFound;

    // Cores na mesma família da tela de início
    final (
      IconData iconData,
      Color iconColor,
      Color iconBg,
    ) = switch (notification.type) {
      NotificationType.matchFound => (
        Icons.auto_awesome_rounded,
        const Color(0xFF24506A),
        const Color(0xFFE3EEF3),
      ),
      NotificationType.petStatusUpdate => (
        Icons.pets_rounded,
        AppColors.primary,
        AppColors.primarySoft,
      ),
      NotificationType.system => (
        Icons.info_outline_rounded,
        const Color(0xFF6B4A12),
        const Color(0xFFF4E7C9),
      ),
    };

    final percentageLabel = isMatch
        ? _extractPercentageLabel(notification)
        : null;
    final unread = !notification.isRead;

    return Material(
      // Não lidos com fundo verde-claro, lidos em branco
      color: unread ? const Color(0xFFEEF5F0) : AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _handleNotificationTap(context, ref, notification),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: unread
                  ? AppColors.primary.withAlpha(60)
                  : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(iconData, size: 22, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _cleanNotificationTitle(notification),
                            style: AppTextStyles.heading3().copyWith(
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimestamp(notification.createdAt),
                          style: AppTextStyles.bodySmall(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _cleanNotificationBody(notification),
                      style: AppTextStyles.body(
                        color: unread
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (isMatch) ...[
                      const SizedBox(height: 10),
                      // Quebra em duas linhas quando falta espaço (celular)
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          if (percentageLabel != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3EEF3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$percentageLabel de semelhança',
                                style: AppTextStyles.label(
                                  color: const Color(0xFF24506A),
                                ).copyWith(fontSize: 12),
                              ),
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Ver correspondência',
                                style: AppTextStyles.label(
                                  color: AppColors.primary,
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 10),
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 9,
                  height: 9,
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

/// Título de grupo ("Novos" / "Anteriores").
class _SectionLabel extends StatelessWidget {
  final String text;
  final int? count;

  const _SectionLabel(this.text, {this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: AppTextStyles.label(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12, letterSpacing: 0.8),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: AppTextStyles.label(
                  color: Colors.white,
                ).copyWith(fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
