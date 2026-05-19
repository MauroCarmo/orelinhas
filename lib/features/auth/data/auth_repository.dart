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

  // Registrar (Email & Senha)
  Future<void> signUp(String email, String password) async {
    await _supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'orelinhas://login-callback',
    );
  }

  // Login (Email & Senha)
  Future<void> signInWithEmail(String email, String password) async {
    await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Login com Google OAuth
  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'orelinhas://login-callback',
    );
  }

  // Recuperação de senha
  Future<void> sendPasswordReset(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'orelinhas://login-callback',
    );
  }

  // Sair (Logout)
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
