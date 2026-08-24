import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart';
import '../../data/repositories/pet_recognition_repository.dart';
import '../../domain/models/pet_match_candidate_entity.dart';
import '../../domain/models/pet_visual_profile_entity.dart';

/// Estado da busca de correspondências.
class PetMatchState {
  final bool isLoading;
  final List<PetMatchCandidateEntity> matches;
  final double minSimilarityThreshold;
  final String? errorMessage;
  final PetVisualProfileEntity? queryVisualProfile;

  const PetMatchState({
    this.isLoading = false,
    this.matches = const [],
    this.minSimilarityThreshold = 0.70,
    this.errorMessage,
    this.queryVisualProfile,
  });

  PetMatchState copyWith({
    bool? isLoading,
    List<PetMatchCandidateEntity>? matches,
    double? minSimilarityThreshold,
    String? errorMessage,
    PetVisualProfileEntity? queryVisualProfile,
  }) {
    return PetMatchState(
      isLoading: isLoading ?? this.isLoading,
      matches: matches ?? this.matches,
      minSimilarityThreshold:
          minSimilarityThreshold ?? this.minSimilarityThreshold,
      errorMessage: errorMessage,
      queryVisualProfile: queryVisualProfile ?? this.queryVisualProfile,
    );
  }
}

final petMatchControllerProvider =
    NotifierProvider.autoDispose<PetMatchController, PetMatchState>(() {
  return PetMatchController();
});

/// Controller responsável pela busca, ordenação e refinamento de matches para um pet selecionado.
class PetMatchController extends Notifier<PetMatchState> {
  late PetRecognitionRepository _repository;
  final _logger = AppLogger.category('PetMatchController');

  @override
  PetMatchState build() {
    _repository = ref.watch(petRecognitionRepositoryProvider);
    return const PetMatchState();
  }

  /// Executa a busca em duas etapas de possíveis correspondências para o pet fornecido.
  Future<void> findMatchesForPet({
    required PetLostAlertEntity pet,
    double? customThreshold,
  }) async {
    final threshold = customThreshold ?? state.minSimilarityThreshold;
    _logger.i('Executando busca de matches para o pet.', context: {
      'petId': pet.id,
      'petType': pet.petType.name,
      'threshold': threshold,
    });

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // 1. Carrega o perfil visual da query se for cão/gato
      PetVisualProfileEntity? visualProfile;
      if (pet.petType == PetType.dog || pet.petType == PetType.cat) {
        visualProfile = await _repository.getVisualProfile(pet.id);
      }

      // 2. Executa busca em duas etapas (recuperação + refinamento)
      final results = await _repository.findMatches(
        queryPet: pet,
        queryVisualProfile: visualProfile,
        minSimilarity: threshold,
      );

      state = state.copyWith(
        isLoading: false,
        matches: results,
        queryVisualProfile: visualProfile,
        minSimilarityThreshold: threshold,
      );

      _logger.i('Busca de matches concluída.', context: {
        'petId': pet.id,
        'matchesFound': results.length,
      });
    } catch (e, st) {
      _logger.e('Erro ao buscar matches para o pet.', error: e, stackTrace: st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Não foi possível buscar correspondências no momento.',
      );
    }
  }

  /// Atualiza o limiar experimental de similaridade e reordena/refiltra os resultados.
  void updateThreshold(PetLostAlertEntity pet, double newThreshold) {
    findMatchesForPet(pet: pet, customThreshold: newThreshold);
  }
}
