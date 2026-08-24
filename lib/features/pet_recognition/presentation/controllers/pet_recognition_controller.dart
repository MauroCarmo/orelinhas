import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart';
import '../../data/repositories/pet_recognition_repository.dart';
import '../../domain/models/bounding_box_entity.dart';
import '../../domain/models/pet_visual_profile_entity.dart';

final petRecognitionControllerProvider =
    AsyncNotifierProvider<PetRecognitionController, PetVisualProfileEntity?>(() {
  return PetRecognitionController();
});

/// Controller de apresentação para o ciclo de vida do reconhecimento visual.
/// Não bloqueia a navegação nem o fluxo de cadastro.
class PetRecognitionController extends AsyncNotifier<PetVisualProfileEntity?> {
  late PetRecognitionRepository _repository;
  final _logger = AppLogger.category('PetRecognitionController');

  @override
  FutureOr<PetVisualProfileEntity?> build() {
    _repository = ref.watch(petRecognitionRepositoryProvider);
    return null;
  }

  /// Processa em segundo plano a lista de imagens cadastradas para o pet.
  Future<PetVisualProfileEntity?> processImages({
    required String petId,
    required PetType petType,
    required List<String> imageUrls,
    Map<String, BoundingBoxEntity>? selectedAnimalPerImage,
  }) async {
    _logger.i('Iniciando processamento não-bloqueante no controller.', context: {
      'petId': petId,
      'imageCount': imageUrls.length,
    });

    state = const AsyncLoading();

    try {
      final profile = await _repository.processPetImages(
        petId: petId,
        petType: petType,
        imageUrls: imageUrls,
        selectedAnimalPerImage: selectedAnimalPerImage,
      );

      state = AsyncData(profile);
      _logger.i('Processamento visual finalizado com sucesso.', context: {
        'petId': petId,
        'validCount': profile.validEmbeddingsCount,
      });
      return profile;
    } catch (e, st) {
      _logger.e('Erro capturado no controller durante processamento visual.', error: e, stackTrace: st);
      state = AsyncError(e, st);
      return null;
    }
  }

  /// Carrega o perfil visual já existente de um pet.
  Future<void> loadProfile(String petId) async {
    state = const AsyncLoading();
    try {
      final profile = await _repository.getVisualProfile(petId);
      state = AsyncData(profile);
    } catch (e, st) {
      _logger.e('Erro ao carregar perfil visual.', error: e, stackTrace: st);
      state = AsyncError(e, st);
    }
  }
}
