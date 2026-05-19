import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../data/profile_repository.dart';
import '../../domain/profile_entity.dart';

final profileControllerProvider = AsyncNotifierProvider<ProfileController, ProfileEntity?>(() {
  return ProfileController();
});

class ProfileController extends AsyncNotifier<ProfileEntity?> {
  late ProfileRepository _repository;

  @override
  FutureOr<ProfileEntity?> build() async {
    _repository = ref.watch(profileRepositoryProvider);
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return null;
    }

    return await _repository.getProfile(user.id);
  }

  /// Atualiza o perfil do usuário e atualiza o estado local do Riverpod.
  Future<void> updateProfile(ProfileEntity profile) async {
    state = const AsyncLoading();
    try {
      // Executa as validações do modelo de domínio no controller antes de enviar
      final validationError = profile.validate();
      if (validationError != null) {
        throw Exception(validationError);
      }

      await _repository.updateProfile(profile);
      state = AsyncData(profile);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Exclui permanentemente a conta e recarrega o estado.
  Future<void> deleteAccount() async {
    state = const AsyncLoading();
    try {
      await _repository.deleteAccount();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
