import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/exceptions/error_mapper.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../data/pet_lost_repository.dart';
import '../../domain/pet_lost_entity.dart';

final petLostControllerProvider = AsyncNotifierProvider<PetLostController, List<PetLostAlertEntity>>(() {
  return PetLostController();
});

class PetLostController extends AsyncNotifier<List<PetLostAlertEntity>> {
  late PetLostRepository _repository;
  final _logger = AppLogger.category('PetLostController');

  @override
  FutureOr<List<PetLostAlertEntity>> build() async {
    _repository = ref.watch(petLostRepositoryProvider);
    final user = ref.watch(currentUserProvider);
    
    if (user == null) {
      return [];
    }

    _logger.i('Inicializando PetLostController e buscando lista de alertas.');

    try {
      return await _repository.getAlerts(user.id);
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao buscar lista inicial no PetLostController.', error: appException, stackTrace: st);
      throw appException;
    }
  }

  /// Recarrega a lista de alertas manualmente a partir do repositório.
  Future<void> refreshAlerts() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = const AsyncLoading();
    try {
      final list = await _repository.getAlerts(user.id);
      state = AsyncData(list);
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao atualizar lista no PetLostController.', error: appException, stackTrace: st);
      state = AsyncError(appException, st);
    }
  }

  /// Cria um novo alerta de pet perdido chamando o repositório.
  /// O controller não realiza validação ou sanitização, apenas orquestra o estado.
  /// Contém proteção contra envio concorrente redundante (double submit).
  Future<void> createAlert(PetLostAlertEntity alert) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw const AppAuthException('Usuário não autenticado.');

    if (state.isLoading) {
      _logger.w('Envio concorrente ignorado em createAlert.');
      return;
    }
    state = const AsyncLoading();
    try {
      await _repository.createAlert(user.id, alert);
      // Recarrega a lista reativamente
      final list = await _repository.getAlerts(user.id);
      state = AsyncData(list);
      _logger.i('Novo alerta registrado com sucesso no controller.', context: {'alertId': alert.id});
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao criar alerta no PetLostController.', error: appException, stackTrace: st, context: {'alertId': alert.id});
      state = AsyncError(appException, st);
    }
  }

  /// Atualiza um alerta existente com proteção contra envio concorrente.
  Future<void> updateAlert(PetLostAlertEntity alert) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw const AppAuthException('Usuário não autenticado.');

    if (state.isLoading) {
      _logger.w('Envio concorrente ignorado em updateAlert.');
      return;
    }
    state = const AsyncLoading();
    try {
      await _repository.updateAlert(user.id, alert);
      // Recarrega a lista reativamente
      final list = await _repository.getAlerts(user.id);
      state = AsyncData(list);
      _logger.i('Alerta atualizado com sucesso no controller.', context: {'alertId': alert.id});
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao atualizar alerta no PetLostController.', error: appException, stackTrace: st, context: {'alertId': alert.id});
      state = AsyncError(appException, st);
    }
  }

  /// Exclui um alerta do pet perdido por ID com proteção contra exclusão concorrente.
  Future<void> deleteAlert(String id) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw const AppAuthException('Usuário não autenticado.');

    if (state.isLoading) {
      _logger.w('Ação concorrente ignorada em deleteAlert.');
      return;
    }
    state = const AsyncLoading();
    try {
      await _repository.deleteAlert(user.id, id);
      // Recarrega a lista reativamente
      final list = await _repository.getAlerts(user.id);
      state = AsyncData(list);
      _logger.i('Alerta excluído com sucesso no controller.', context: {'alertId': id});
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao excluir alerta no PetLostController.', error: appException, stackTrace: st, context: {'alertId': id});
      state = AsyncError(appException, st);
    }
  }
}
