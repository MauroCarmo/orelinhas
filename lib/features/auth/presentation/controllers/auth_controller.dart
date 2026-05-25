import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/exceptions/error_mapper.dart';
import '../../../../core/logger/app_logger.dart';
import '../../data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User, AuthState, Supabase;

// Escuta a sessão global do usuário logado
final authStateProvider = StreamProvider<AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

// Fornece acesso direto ao usuário, reagindo a mudanças de sessão (login/logout)
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentUser;
});

// Provider do Controller para manejar as lógicas da UI (Modern Riverpod AsyncNotifier)
final authControllerProvider = AsyncNotifierProvider<AuthController, void>(() {
  return AuthController();
});

class AuthController extends AsyncNotifier<void> {
  late AuthRepository _repository;
  final _logger = AppLogger.category('AuthController');

  @override
  FutureOr<void> build() {
    _repository = ref.watch(authRepositoryProvider);
  }

  Future<void> signIn(String email, String password) async {
    if (state is AsyncLoading) {
      _logger.w('Ação concorrente ignorada em signIn.');
      return;
    }
    state = const AsyncLoading();
    try {
      // 1. Verificar se a conta está atualmente bloqueada
      final lockStatus = await _repository.checkLock(email);
      if (lockStatus['is_locked'] == true) {
        final remainingSec = lockStatus['remaining_seconds'] as int? ?? 0;
        final minutes = (remainingSec / 60).ceil();
        throw AppAuthException(
          'Conta temporariamente bloqueada devido a 3 tentativas falhas. Tente novamente em $minutes minuto(s).',
          technicalMessage: 'Conta bloqueada temporariamente (RPC is_email_locked).',
        );
      }

      // 2. Tentar o login
      try {
        await _repository.signInWithEmail(email, password);
        
        // Login com sucesso: reseta tentativas
        await _repository.registerAttempt(email, true);

        // Validar se o email está confirmado
        final user = _repository.currentUser;
        if (user != null && user.emailConfirmedAt == null) {
          _logger.w('Tentativa de login por usuário com e-mail não confirmado.', context: {'email': email});
          state = AsyncError(
            const AppAuthException('Por favor, verifique seu e-mail antes de fazer login.'),
            StackTrace.current,
          );
          await _repository.signOut();
          return;
        }
        state = const AsyncData(null);
      } on AppAuthException catch (e) {
        // Falha no login: registra tentativa malsucedida
        await _repository.registerAttempt(email, false);

        // Verifica se bloqueou após essa falha
        final postLockStatus = await _repository.checkLock(email);
        if (postLockStatus['is_locked'] == true) {
          throw const AppAuthException(
            'Usuário ou senha inválidos. Conta bloqueada por 15 minutos.',
            technicalMessage: 'Erro de credencial resultando em bloqueio temporário.',
          );
        }

        // Mensagem padrão amigável exigida pelo IBL02
        throw AppAuthException(
          'Usuário ou senha inválidos.',
          technicalMessage: e.technicalMessage ?? e.message,
        );
      }
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao realizar login no AuthController.', error: appException, stackTrace: st, context: {'email': email});
      state = AsyncError(appException, st);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String location,
  }) async {
    if (state is AsyncLoading) {
      _logger.w('Ação concorrente ignorada em signUp.');
      return;
    }
    state = const AsyncLoading();
    try {
      await _repository.signUp(
        email: email,
        password: password,
        name: name,
        phone: phone,
        location: location,
      );
      state = const AsyncData(null);
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao realizar cadastro no AuthController.', error: appException, stackTrace: st, context: {'email': email});
      state = AsyncError(appException, st);
    }
  }

  Future<void> signInWithGoogle() async {
    if (state is AsyncLoading) {
      _logger.w('Ação concorrente ignorada em signInWithGoogle.');
      return;
    }
    state = const AsyncLoading();
    try {
      await _repository.signInWithGoogle();
      state = const AsyncData(null);
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro no login via Google OAuth no AuthController.', error: appException, stackTrace: st);
      state = AsyncError(appException, st);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    if (state is AsyncLoading) {
      _logger.w('Ação concorrente ignorada em sendPasswordReset.');
      return;
    }
    state = const AsyncLoading();
    try {
      await _repository.sendPasswordReset(email);
      state = const AsyncData(null);
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao solicitar redefinição de senha no AuthController.', error: appException, stackTrace: st, context: {'email': email});
      state = AsyncError(appException, st);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    if (state is AsyncLoading) {
      _logger.w('Ação concorrente ignorada em updatePassword.');
      return;
    }
    state = const AsyncLoading();
    try {
      await _repository.updatePassword(newPassword);
      state = const AsyncData(null);
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao atualizar senha no AuthController.', error: appException, stackTrace: st);
      state = AsyncError(appException, st);
    }
  }

  Future<void> signOut() async {
    if (state is AsyncLoading) {
      _logger.w('Ação concorrente ignorada em signOut.');
      return;
    }
    state = const AsyncLoading();
    try {
      await _repository.signOut();
      state = const AsyncData(null);
    } catch (e, st) {
      final appException = AppErrorMapper.map(e, st);
      _logger.e('Erro ao efetuar encerramento de sessão no AuthController.', error: appException, stackTrace: st);
      state = AsyncError(appException, st);
    }
  }
}
