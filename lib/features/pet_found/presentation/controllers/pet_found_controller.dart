import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/exceptions/error_mapper.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../data/pet_found_repository.dart';
import '../../domain/pet_found_entity.dart';
import '../../../pet_lost/data/pet_lost_repository.dart';
import '../../../pet_recognition/data/repositories/pet_recognition_repository.dart';

import 'public_pet_found_controller.dart';

final petFoundControllerProvider =
    AsyncNotifierProvider<PetFoundController, List<PetFoundAlertEntity>>(() {
      return PetFoundController();
    });

class PetFoundController extends AsyncNotifier<List<PetFoundAlertEntity>> {
  late PetFoundRepository _repository;
  final _logger = AppLogger.category('PetFoundController');

  @override
  FutureOr<List<PetFoundAlertEntity>> build() async {
    _repository = ref.watch(petFoundRepositoryProvider);
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return [];
    }

    _logger.i('Inicializando PetFoundController e buscando lista de alertas.');

    try {
      return await _repository.getUserAlerts(user.id);
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e(
        'Erro ao buscar lista inicial no PetFoundController.',
        error: appException,
        stackTrace: st,
      );
      throw appException;
    }
  }

  /// Recarrega a lista de alertas manualmente a partir do repositório.
  Future<void> refreshAlerts() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = const AsyncLoading();
    try {
      final list = await _repository.getUserAlerts(user.id);
      state = AsyncData(list);
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e(
        'Erro ao atualizar lista no PetFoundController.',
        error: appException,
        stackTrace: st,
      );
      state = AsyncError(appException, st);
    }
  }

  /// Cria um novo alerta de pet encontrado e dispara o pipeline visual (até 3 fotos).
  Future<void> createAlert(PetFoundAlertEntity alert) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw const AppAuthException('Usuário não autenticado.');

    if (state.isLoading) {
      _logger.w('Envio concorrente ignorado em createAlert.');
      return;
    }
    state = const AsyncLoading();
    try {
      final createdAlert = await _repository.createAlert(user.id, alert);
      final enrichedCreated = createdAlert.copyWith(
        imageUrls: alert.effectiveImageUrls,
      );

      final list = await _repository.getUserAlerts(user.id);
      state = AsyncData(list);
      ref.invalidate(publicPetFoundControllerProvider);
      _logger.i(
        'Novo alerta registrado com sucesso no controller.',
        context: {'alertId': createdAlert.id},
      );

      final urls = enrichedCreated.effectiveImageUrls;
      if (urls.isNotEmpty) {
        final recognitionRepo = ref.read(petRecognitionRepositoryProvider);
        final petLostRepo = ref.read(petLostRepositoryProvider);

        recognitionRepo
            .processPetImages(
              petId: enrichedCreated.id,
              petType: enrichedCreated.petType,
              imageUrls: urls,
            )
            .then((foundVisualProfile) async {
              final activeLostPets = await petLostRepo.getPublicAlerts(
                limit: 50,
                petType: enrichedCreated.petType,
              );

              await recognitionRepo.matchFoundPetAgainstLostPets(
                foundPet: enrichedCreated,
                foundVisualProfile: foundVisualProfile,
                activeLostPets: activeLostPets,
              );
            })
            .catchError((e) {
              _logger.w(
                'Processamento de IA em background falhou suavemente.',
                error: e,
              );
            });
      }
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e(
        'Erro ao criar alerta no PetFoundController.',
        error: appException,
        stackTrace: st,
        context: {'alertId': alert.id},
      );
      state = AsyncError(appException, st);
    }
  }

  /// Atualiza um alerta existente e reprocessa a IA apenas se fotos ou espécie mudarem.
  Future<void> updateAlert(PetFoundAlertEntity alert) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw const AppAuthException('Usuário não autenticado.');

    if (state.isLoading) {
      _logger.w('Envio concorrente ignorado em updateAlert.');
      return;
    }

    final previousAlert = state.value?.firstWhere(
      (a) => a.id == alert.id,
      orElse: () => alert,
    );
    final newUrls = alert.effectiveImageUrls;
    final oldUrls = previousAlert?.effectiveImageUrls ?? const <String>[];
    final imagesChanged =
        previousAlert != null && !listEquals(oldUrls, newUrls);
    final typeChanged =
        previousAlert != null && previousAlert.petType != alert.petType;

    state = const AsyncLoading();
    try {
      await _repository.updateAlert(user.id, alert);
      final list = await _repository.getUserAlerts(user.id);
      state = AsyncData(list);
      ref.invalidate(publicPetFoundControllerProvider);
      _logger.i(
        'Alerta atualizado com sucesso no controller.',
        context: {'alertId': alert.id},
      );

      if ((imagesChanged || typeChanged) && newUrls.isNotEmpty) {
        final recognitionRepo = ref.read(petRecognitionRepositoryProvider);
        final petLostRepo = ref.read(petLostRepositoryProvider);

        recognitionRepo
            .processPetImages(
              petId: alert.id,
              petType: alert.petType,
              imageUrls: newUrls,
            )
            .then((foundVisualProfile) async {
              final activeLostPets = await petLostRepo.getPublicAlerts(
                limit: 50,
                petType: alert.petType,
              );
              await recognitionRepo.matchFoundPetAgainstLostPets(
                foundPet: alert,
                foundVisualProfile: foundVisualProfile,
                activeLostPets: activeLostPets,
              );
            })
            .catchError((e) {
              _logger.w(
                'Reprocessamento de IA ao atualizar alerta encontrado falhou.',
                error: e,
              );
            });
      }
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e(
        'Erro ao atualizar alerta no PetFoundController.',
        error: appException,
        stackTrace: st,
        context: {'alertId': alert.id},
      );
      state = AsyncError(appException, st);
    }
  }

  /// Exclui um alerta do pet encontrado por ID.
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
      final list = await _repository.getUserAlerts(user.id);
      state = AsyncData(list);
      ref.invalidate(publicPetFoundControllerProvider);
      _logger.i(
        'Alerta excluído com sucesso no controller.',
        context: {'alertId': id},
      );
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e(
        'Erro ao excluir alerta no PetFoundController.',
        error: appException,
        stackTrace: st,
        context: {'alertId': id},
      );
      state = AsyncError(appException, st);
    }
  }

  /// Marca um alerta como resolvido por ID.
  Future<void> resolveAlert(String alertId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw const AppAuthException('Usuário não autenticado.');

    if (state.isLoading) {
      _logger.w('Ação concorrente ignorada em resolveAlert.');
      return;
    }
    state = const AsyncLoading();
    try {
      await _repository.resolveAlert(user.id, alertId);
      final list = await _repository.getUserAlerts(user.id);
      state = AsyncData(list);
      ref.invalidate(publicPetFoundControllerProvider);
      _logger.i(
        'Alerta resolvido com sucesso no controller.',
        context: {'alertId': alertId},
      );
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e(
        'Erro ao resolver alerta.',
        error: appException,
        stackTrace: st,
        context: {'alertId': alertId},
      );
      state = AsyncError(appException, st);
    }
  }
}
