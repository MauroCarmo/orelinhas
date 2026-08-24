import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/exceptions/error_mapper.dart';
import '../../../../core/logger/app_logger.dart';
import '../../data/pet_found_repository.dart';
import '../../domain/pet_found_entity.dart';

final publicPetFoundControllerProvider = AsyncNotifierProvider<PublicPetFoundController, List<PetFoundAlertEntity>>(() {
  return PublicPetFoundController();
});

class PublicPetFoundController extends AsyncNotifier<List<PetFoundAlertEntity>> {
  late PetFoundRepository _repository;
  final _logger = AppLogger.category('PublicPetFoundController');

  @override
  FutureOr<List<PetFoundAlertEntity>> build() async {
    _repository = ref.watch(petFoundRepositoryProvider);

    _logger.i('Inicializando PublicPetFoundController e buscando feed público.');

    try {
      return await _repository.getPublicAlerts();
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao buscar feed público.', error: appException, stackTrace: st);
      throw appException;
    }
  }

  /// Recarrega a lista de alertas públicos manualmente.
  Future<void> refreshAlerts() async {
    state = const AsyncLoading();
    try {
      final list = await _repository.getPublicAlerts();
      state = AsyncData(list);
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao atualizar feed público.', error: appException, stackTrace: st);
      state = AsyncError(appException, st);
    }
  }
}
