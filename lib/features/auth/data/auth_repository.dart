import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = ref.read(supabaseClientProvider);
  return AuthRepository(supabase);
});

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  // Escutar as mudanças de estado (logado, deslogado)
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Obter o usuário atual
  User? get currentUser => _supabase.auth.currentUser;

  // Registrar (Email & Senha) com metadados obrigatórios de Perfil
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String location,
  }) async {
    await _supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'orelinhas://login-callback',
      data: {
        'name': name,
        'phone': phone,
        'location': location,
      },
    );
  }

  // Login (Email & Senha)
  Future<void> signInWithEmail(String email, String password) async {
    await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Verificar se o e-mail está bloqueado temporariamente
  Future<Map<String, dynamic>> checkLock(String email) async {
    try {
      final response = await _supabase.rpc(
        'is_email_locked',
        params: {'user_email': email},
      );
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return {'is_locked': false, 'remaining_seconds': 0, 'attempts_count': 0};
    } catch (_) {
      return {'is_locked': false, 'remaining_seconds': 0, 'attempts_count': 0};
    }
  }

  // Registrar tentativa de login (sucesso ou falha)
  Future<void> registerAttempt(String email, bool isSuccess) async {
    try {
      await _supabase.rpc(
        'register_login_attempt',
        params: {
          'user_email': email,
          'is_success': isSuccess,
        },
      );
    } catch (_) {
      // Ignora erro do RPC para não travar o fluxo se o banco falhar
    }
  }

  // Login com Google OAuth
  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'orelinhas://login-callback',
    );
  }

  // Recuperação de senha (Dispara e-mail)
  Future<void> sendPasswordReset(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'orelinhas://login-callback',
    );
  }

  // Atualizar senha (Chamado na tela após clicar no link do e-mail)
  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // Sair (Logout)
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
