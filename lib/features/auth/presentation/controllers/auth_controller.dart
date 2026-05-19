import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/auth_repository.dart';

// Escuta a sessão global do usuário logado
final authStateProvider = StreamProvider<AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

// Fornece acesso direto ao usuário, reagindo a mudanças de sessão (login/logout)
final currentUserProvider = Provider<User?>((ref) {
  // Ao observar o authStateProvider, esse provider recalcula sempre que a sessão mudar
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentUser;
});

// Provider do Controller para manejar as lógicas da UI (Modern Riverpod AsyncNotifier)
final authControllerProvider = AsyncNotifierProvider<AuthController, void>(() {
  return AuthController();
});

class AuthController extends AsyncNotifier<void> {
  late AuthRepository _repository;

  @override
  FutureOr<void> build() {
    _repository = ref.watch(authRepositoryProvider);
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    try {
      // 1. Verificar se a conta está atualmente bloqueada
      final lockStatus = await _repository.checkLock(email);
      if (lockStatus['is_locked'] == true) {
        final remainingSec = lockStatus['remaining_seconds'] as int? ?? 0;
        final minutes = (remainingSec / 60).ceil();
        throw Exception(
          'Conta temporariamente bloqueada devido a 3 tentativas falhas. '
          'Tente novamente em $minutes minuto(s).',
        );
      }

      // 2. Tentar o login
      try {
        await _repository.signInWithEmail(email, password);
        
        // Login com sucesso: reseta tentativas
        await _repository.registerAttempt(email, true);

        // Validar se o email está confirmado se a flag 'Email Confirm' estiver ativa no Supabase
        if (_repository.currentUser != null && _repository.currentUser!.emailConfirmedAt == null) {
          state = AsyncError('Por favor, verifique seu e-mail antes de fazer login.', StackTrace.current);
          await _repository.signOut();
          return;
        }
        state = const AsyncData(null);
      } on AuthException catch (_) {
        // Falha no login: registra tentativa malsucedida
        await _repository.registerAttempt(email, false);

        // Verifica se bloqueou após essa falha
        final postLockStatus = await _repository.checkLock(email);
        if (postLockStatus['is_locked'] == true) {
          throw Exception('Usuário ou senha inválidos. Conta bloqueada por 15 minutos.');
        }

        // Mensagem padrão amigável exigida pelo IBL02
        throw Exception('Usuário ou senha inválidos');
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String location,
  }) async {
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
      state = AsyncError(e, st);
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      await _repository.signInWithGoogle();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    try {
      await _repository.sendPasswordReset(email);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    state = const AsyncLoading();
    try {
      await _repository.updatePassword(newPassword);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await _repository.signOut();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
