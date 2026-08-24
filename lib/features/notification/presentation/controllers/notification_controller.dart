import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/models/notification_entity.dart';

final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, List<NotificationEntity>>(() {
  return NotificationController();
});

/// Provider auxiliar para obter a quantidade de notificações não lidas.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final state = ref.watch(notificationControllerProvider);
  return state.maybeWhen(
    data: (notifications) => notifications.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});

/// Controller responsável pelo ciclo de vida e estado das notificações do usuário.
class NotificationController extends AsyncNotifier<List<NotificationEntity>> {
  late NotificationRepository _repository;
  final _logger = AppLogger.category('NotificationController');

  @override
  FutureOr<List<NotificationEntity>> build() async {
    _repository = ref.watch(notificationRepositoryProvider);
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return [];
    }

    _logger.i('Carregando lista de notificações para o usuário.', context: {'userId': user.id});
    try {
      return await _repository.getUserNotifications(user.id);
    } catch (e, st) {
      _logger.e('Erro ao carregar notificações.', error: e, stackTrace: st);
      return [];
    }
  }

  /// Recarrega as notificações manualmente a partir do repositório/banco.
  Future<void> refreshNotifications() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = const AsyncLoading();
    try {
      final list = await _repository.getUserNotifications(user.id);
      state = AsyncData(list);
      _logger.i('Notificações atualizadas com sucesso.', context: {'count': list.length});
    } catch (e, st) {
      _logger.e('Erro ao atualizar notificações.', error: e, stackTrace: st);
      state = AsyncError(e, st);
    }
  }

  /// Marca uma notificação individual como lida.
  Future<void> markAsRead(String notificationId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final currentList = state.value ?? [];
    final updatedList = currentList.map((n) {
      if (n.id == notificationId) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    // Atualização otimista no estado local
    state = AsyncData(updatedList);

    try {
      await _repository.markAsRead(user.id, notificationId);
      _logger.i('Notificação marcada como lida.', context: {'id': notificationId});
    } catch (e, st) {
      _logger.w('Erro ao persistir status de leitura da notificação. Revertendo estado local.', error: e, stackTrace: st);
      // Rollback: restaura o estado anterior para manter consistência com o banco
      state = AsyncData(currentList);
    }
  }

  /// Marca todas as notificações como lidas.
  Future<void> markAllAsRead() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final currentList = state.value ?? [];
    final updatedList = currentList.map((n) => n.copyWith(isRead: true)).toList();

    state = AsyncData(updatedList);

    try {
      await _repository.markAllAsRead(user.id);
      _logger.i('Todas as notificações foram marcadas como lidas.');
    } catch (e, st) {
      _logger.w('Erro ao marcar todas notificações como lidas. Revertendo estado local.', error: e, stackTrace: st);
      // Rollback: restaura o estado anterior para manter consistência com o banco
      state = AsyncData(currentList);
    }
  }
}
