import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/exceptions/error_mapper.dart';
import '../../../../core/logger/app_logger.dart';
import '../../data/pet_adoption_repository.dart';
import '../../domain/pet_adoption_entity.dart';

final publicPetAdoptionControllerProvider = AsyncNotifierProvider<PublicPetAdoptionController, List<PetAdoptionAlertEntity>>(() {
  return PublicPetAdoptionController();
});

class PublicPetAdoptionController extends AsyncNotifier<List<PetAdoptionAlertEntity>> {
  late PetAdoptionRepository _repository;
  final _logger = AppLogger.category('PublicPetAdoptionController');

  @override
  FutureOr<List<PetAdoptionAlertEntity>> build() async {
    _repository = ref.watch(petAdoptionRepositoryProvider);

    _logger.i('Inicializando PublicPetAdoptionController e buscando feed público.');

    try {
      return await _repository.getPublicAdoptions();
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao buscar feed público de adoções.', error: appException, stackTrace: st);
      throw appException;
    }
  }

  /// Recarrega a lista de adoções públicas manualmente.
  Future<void> refreshAdoptions() async {
    state = const AsyncLoading();
    try {
      final list = await _repository.getPublicAdoptions();
      state = AsyncData(list);
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao atualizar feed público de adoções.', error: appException, stackTrace: st);
      state = AsyncError(appException, st);
    }
  }
}
