import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/exceptions/error_mapper.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../data/profile_repository.dart';
import '../../domain/profile_entity.dart';

final profileControllerProvider = AsyncNotifierProvider<ProfileController, ProfileEntity?>(() {
  return ProfileController();
});

class ProfileController extends AsyncNotifier<ProfileEntity?> {
  late ProfileRepository _repository;
  final _logger = AppLogger.category('ProfileController');

  @override
  FutureOr<ProfileEntity?> build() async {
    _repository = ref.watch(profileRepositoryProvider);
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return null;
    }

    try {
      return await _repository.getProfile(user.id);
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao buscar perfil inicial no ProfileController.', error: appException, stackTrace: st, context: {'userId': user.id});
      // Propaga o erro de inicialização de forma limpa para a UI tratar
      throw appException;
    }
  }

  /// Atualiza o perfil do usuário e atualiza o estado local do Riverpod.
  Future<void> updateProfile(ProfileEntity profile) async {
    if (state is AsyncLoading) {
      _logger.w('Envio concorrente ignorado em updateProfile.');
      return;
    }
    state = const AsyncLoading();
    try {
      // 1. Executa as validações do modelo de domínio no controller (Defesa em Profundidade)
      final validationError = profile.validate();
      if (validationError != null) {
        throw ValidationException(validationError);
      }

      await _repository.updateProfile(profile);
      state = AsyncData(profile);
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao atualizar perfil no ProfileController.', error: appException, stackTrace: st, context: {'userId': profile.id});
      state = AsyncError(appException, st);
    }
  }

  /// Exclui permanentemente a conta e recarrega o estado.
  Future<void> deleteAccount() async {
    if (state is AsyncLoading) {
      _logger.w('Ação concorrente ignorada em deleteAccount.');
      return;
    }
    state = const AsyncLoading();
    final user = ref.read(currentUserProvider);
    final userId = user?.id ?? 'desconhecido';
    
    try {
      await _repository.deleteAccount();
      state = const AsyncData(null);
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro crítico ao excluir conta no ProfileController.', error: appException, stackTrace: st, context: {'userId': userId});
      state = AsyncError(appException, st);
    }
  }
}
