import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/exceptions/error_mapper.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../data/pet_adoption_repository.dart';
import '../../domain/pet_adoption_entity.dart';
import 'public_pet_adoption_controller.dart';

final petAdoptionControllerProvider = AsyncNotifierProvider<PetAdoptionController, List<PetAdoptionAlertEntity>>(() {
  return PetAdoptionController();
});

class PetAdoptionController extends AsyncNotifier<List<PetAdoptionAlertEntity>> {
  late PetAdoptionRepository _repository;
  final _logger = AppLogger.category('PetAdoptionController');

  @override
  FutureOr<List<PetAdoptionAlertEntity>> build() async {
    _repository = ref.watch(petAdoptionRepositoryProvider);
    final user = ref.watch(currentUserProvider);
    
    if (user == null) {
      return [];
    }

    _logger.i('Inicializando PetAdoptionController e buscando lista de anúncios de adoção.');

    try {
      return await _repository.getUserAdoptions(user.id);
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao buscar lista inicial no PetAdoptionController.', error: appException, stackTrace: st);
      throw appException;
    }
  }

  /// Recarrega a lista de anúncios manualmente a partir do repositório.
  Future<void> refreshAdoptions() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = const AsyncLoading();
    try {
      final list = await _repository.getUserAdoptions(user.id);
      state = AsyncData(list);
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao atualizar lista no PetAdoptionController.', error: appException, stackTrace: st);
      state = AsyncError(appException, st);
    }
  }

  /// Cria um novo anúncio de adoção.
  Future<void> createAdoption(PetAdoptionAlertEntity adoption) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw const AppAuthException('Usuário não autenticado.');

    if (state.isLoading) {
      _logger.w('Envio concorrente ignorado em createAdoption.');
      return;
    }
    state = const AsyncLoading();
    try {
      await _repository.createAdoption(user.id, adoption);
      final list = await _repository.getUserAdoptions(user.id);
      state = AsyncData(list);
      ref.invalidate(publicPetAdoptionControllerProvider);
      _logger.i('Novo anúncio de adoção registrado com sucesso no controller.', context: {'id': adoption.id});
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao criar anúncio de adoção no PetAdoptionController.', error: appException, stackTrace: st, context: {'id': adoption.id});
      state = AsyncError(appException, st);
    }
  }

  /// Atualiza um anúncio existente.
  Future<void> updateAdoption(PetAdoptionAlertEntity adoption) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw const AppAuthException('Usuário não autenticado.');

    if (state.isLoading) {
      _logger.w('Envio concorrente ignorado em updateAdoption.');
      return;
    }
    state = const AsyncLoading();
    try {
      await _repository.updateAdoption(user.id, adoption);
      final list = await _repository.getUserAdoptions(user.id);
      state = AsyncData(list);
      ref.invalidate(publicPetAdoptionControllerProvider);
      _logger.i('Anúncio de adoção atualizado com sucesso no controller.', context: {'id': adoption.id});
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao atualizar anúncio de adoção no PetAdoptionController.', error: appException, stackTrace: st, context: {'id': adoption.id});
      state = AsyncError(appException, st);
    }
  }

  /// Exclui um anúncio de adoção por ID.
  Future<void> deleteAdoption(String id) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw const AppAuthException('Usuário não autenticado.');

    if (state.isLoading) {
      _logger.w('Ação concorrente ignorada em deleteAdoption.');
      return;
    }
    state = const AsyncLoading();
    try {
      await _repository.deleteAdoption(user.id, id);
      final list = await _repository.getUserAdoptions(user.id);
      state = AsyncData(list);
      ref.invalidate(publicPetAdoptionControllerProvider);
      _logger.i('Anúncio de adoção excluído com sucesso no controller.', context: {'id': id});
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao excluir anúncio de adoção no PetAdoptionController.', error: appException, stackTrace: st, context: {'id': id});
      state = AsyncError(appException, st);
    }
  }

  /// Marca um anúncio como adotado por ID.
  Future<void> markAsAdopted(String id) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw const AppAuthException('Usuário não autenticado.');

    if (state.isLoading) {
      _logger.w('Ação concorrente ignorada em markAsAdopted.');
      return;
    }
    state = const AsyncLoading();
    try {
      await _repository.markAsAdopted(user.id, id);
      final list = await _repository.getUserAdoptions(user.id);
      state = AsyncData(list);
      ref.invalidate(publicPetAdoptionControllerProvider);
      _logger.i('Anúncio marcado como adotado no controller.', context: {'id': id});
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao marcar adoção como adotada no PetAdoptionController.', error: appException, stackTrace: st, context: {'id': id});
      state = AsyncError(appException, st);
    }
  }
}
