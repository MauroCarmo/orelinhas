import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/exceptions/error_mapper.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../data/pet_lost_repository.dart';
import '../../domain/pet_lost_entity.dart';
import '../../../pet_recognition/data/repositories/pet_recognition_repository.dart';

import 'public_pet_lost_controller.dart';

final petLostControllerProvider =
    AsyncNotifierProvider<PetLostController, List<PetLostAlertEntity>>(() {
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
      return await _repository.getUserAlerts(user.id);
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e(
        'Erro ao buscar lista inicial no PetLostController.',
        error: appException,
        stackTrace: st,
      );
      throw appException;
    }
  }

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
        'Erro ao atualizar lista no PetLostController.',
        error: appException,
        stackTrace: st,
      );
      state = AsyncError(appException, st);
    }
  }

  Future<void> createAlert(PetLostAlertEntity alert) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw const AppAuthException('Usuário não autenticado.');

    if (state.isLoading) {
      _logger.w('Envio concorrente ignorado em createAlert.');
      return;
    }
    state = const AsyncLoading();
    try {
      final createdAlert = await _repository.createAlert(user.id, alert);
      final alertWithAllImages = createdAlert.copyWith(
        imageUrls: alert.effectiveImageUrls,
      );

      final list = await _repository.getUserAlerts(user.id);
      state = AsyncData(list);
      ref.invalidate(publicPetLostControllerProvider);
      _logger.i(
        'Novo alerta registrado com sucesso no controller.',
        context: {'alertId': createdAlert.id},
      );

      final allUrls = alertWithAllImages.effectiveImageUrls;
      if (allUrls.isNotEmpty) {
        final recognitionRepo = ref.read(petRecognitionRepositoryProvider);
        recognitionRepo
            .processPetImages(
              petId: createdAlert.id,
              petType: createdAlert.petType,
              imageUrls: allUrls,
            )
            .then((visualProfile) {
              recognitionRepo.findMatches(
                queryPet: alertWithAllImages,
                queryVisualProfile: visualProfile,
                origin: 'automatic',
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
        'Erro ao criar alerta no PetLostController.',
        error: appException,
        stackTrace: st,
        context: {'alertId': alert.id},
      );
      state = AsyncError(appException, st);
    }
  }

  Future<void> updateAlert(PetLostAlertEntity alert) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw const AppAuthException('Usuário não autenticado.');

    if (state.isLoading) {
      _logger.w('Envio concorrente ignorado em updateAlert.');
      return;
    }

    final allUrls = alert.effectiveImageUrls;

    state = const AsyncLoading();
    try {
      await _repository.updateAlert(user.id, alert);
      final list = await _repository.getUserAlerts(user.id);
      state = AsyncData(list);
      ref.invalidate(publicPetLostControllerProvider);
      _logger.i(
        'Alerta atualizado com sucesso no controller.',
        context: {'alertId': alert.id},
      );

      // Sincroniza pet_images (reutiliza embeddings já existentes e processa apenas fotos novas)
      if (allUrls.isNotEmpty) {
        final recognitionRepo = ref.read(petRecognitionRepositoryProvider);
        recognitionRepo
            .processPetImages(
              petId: alert.id,
              petType: alert.petType,
              imageUrls: allUrls,
            )
            .then((visualProfile) {
              recognitionRepo.findMatches(
                queryPet: alert,
                queryVisualProfile: visualProfile,
                origin: 'automatic',
              );
            })
            .catchError((e) {
              _logger.w(
                'Reprocessamento de IA ao atualizar alerta falhou suavemente.',
                error: e,
              );
            });
      }
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e(
        'Erro ao atualizar alerta no PetLostController.',
        error: appException,
        stackTrace: st,
        context: {'alertId': alert.id},
      );
      state = AsyncError(appException, st);
    }
  }

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
      ref.invalidate(publicPetLostControllerProvider);
      _logger.i(
        'Alerta excluído com sucesso no controller.',
        context: {'alertId': id},
      );
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e(
        'Erro ao excluir alerta no PetLostController.',
        error: appException,
        stackTrace: st,
        context: {'alertId': id},
      );
      state = AsyncError(appException, st);
    }
  }

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
      ref.invalidate(publicPetLostControllerProvider);
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
