import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart';
import '../../data/repositories/pet_recognition_repository.dart';
import '../../domain/models/pet_match_candidate_entity.dart';
import '../../domain/models/pet_visual_profile_entity.dart';
import '../../domain/utils/recognition_config.dart';

/// Estado da busca de correspondências.
class PetMatchState {
  final bool isLoading;
  final List<PetMatchCandidateEntity> allMatches;
  final List<PetMatchCandidateEntity> matches;
  final String? errorMessage;
  final PetVisualProfileEntity? queryVisualProfile;

  const PetMatchState({
    this.isLoading = false,
    this.allMatches = const [],
    this.matches = const [],
    this.errorMessage,
    this.queryVisualProfile,
  });

  PetMatchState copyWith({
    bool? isLoading,
    List<PetMatchCandidateEntity>? allMatches,
    List<PetMatchCandidateEntity>? matches,
    String? errorMessage,
    PetVisualProfileEntity? queryVisualProfile,
  }) {
    return PetMatchState(
      isLoading: isLoading ?? this.isLoading,
      allMatches: allMatches ?? this.allMatches,
      matches: matches ?? this.matches,
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

  /// Carrega as correspondências já persistidas no Supabase para o pet sem recalcular IA.
  Future<void> loadPersistedMatches(PetLostAlertEntity pet) async {
    _logger.i('Carregando matches persistidos do pet.', context: {'petId': pet.id});
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final visualProfile = await _repository.getVisualProfile(pet.id);
      final persisted = await _repository.getPersistedMatchesForLostPet(
        pet.id,
        minSimilarity: RecognitionConfig.kSimilarityThreshold,
      );

      final filtered = persisted
          .where((m) => m.similarityScore >= RecognitionConfig.kSimilarityThreshold)
          .toList();

      state = state.copyWith(
        isLoading: false,
        allMatches: persisted,
        matches: filtered,
        queryVisualProfile: visualProfile,
      );
    } catch (e, st) {
      _logger.e('Erro ao carregar matches persistidos.', error: e, stackTrace: st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Não foi possível carregar as correspondências.',
      );
    }
  }

  /// Executa nova busca ativa/manual no backend (origin = 'manual', sem disparar notificações).
  Future<void> runNewSearch({
    required PetLostAlertEntity pet,
  }) async {
    _logger.i('Executando nova busca manual de matches para o pet.', context: {
      'petId': pet.id,
      'petType': pet.petType.name,
    });

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      PetVisualProfileEntity? visualProfile;
      if (pet.petType == PetType.dog || pet.petType == PetType.cat) {
        visualProfile = await _repository.getVisualProfile(pet.id);
      }

      final results = await _repository.findMatches(
        queryPet: pet,
        queryVisualProfile: visualProfile,
        minSimilarity: RecognitionConfig.kSimilarityThreshold,
        origin: 'manual',
      );

      final filtered = results
          .where((m) => m.similarityScore >= RecognitionConfig.kSimilarityThreshold)
          .toList();

      state = state.copyWith(
        isLoading: false,
        allMatches: results,
        matches: filtered,
        queryVisualProfile: visualProfile,
      );

      _logger.i('Busca manual de matches concluída.', context: {
        'petId': pet.id,
        'matchesFound': results.length,
      });
    } catch (e, st) {
      _logger.e('Erro ao buscar matches manualmente.', error: e, stackTrace: st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Não foi possível buscar correspondências no momento.',
      );
    }
  }
}
