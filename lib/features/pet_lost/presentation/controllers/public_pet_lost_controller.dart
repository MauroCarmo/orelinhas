import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/exceptions/error_mapper.dart';
import '../../../../core/logger/app_logger.dart';
import '../../data/pet_lost_repository.dart';
import '../../domain/pet_lost_entity.dart';

final publicPetLostControllerProvider = AsyncNotifierProvider<PublicPetLostController, List<PetLostAlertEntity>>(() {
  return PublicPetLostController();
});

class PublicPetLostController extends AsyncNotifier<List<PetLostAlertEntity>> {
  late PetLostRepository _repository;
  final _logger = AppLogger.category('PublicPetLostController');

  @override
  FutureOr<List<PetLostAlertEntity>> build() async {
    _repository = ref.watch(petLostRepositoryProvider);

    _logger.i('Inicializando PublicPetLostController e buscando feed público.');

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
