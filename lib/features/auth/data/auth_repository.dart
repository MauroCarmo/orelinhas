import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/exceptions/error_mapper.dart';
import '../../../core/logger/app_logger.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = ref.read(supabaseClientProvider);
  return AuthRepository(supabase);
});

class AuthRepository {
  final SupabaseClient _supabase;
  final _logger = AppLogger.category('AuthRepository');

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
    _logger.i('Iniciando processo de cadastro (signUp).', context: {'email': email});
    try {
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
      _logger.i('Cadastro (signUp) concluído com sucesso.', context: {'email': email});
    } catch (e, st) {
      _logger.e('Falha no processo de cadastro (signUp).', error: e, stackTrace: st, context: {'email': email});
      throw AppErrorMapper.map(e, st);
    }
  }

  // Login (Email & Senha)
  Future<void> signInWithEmail(String email, String password) async {
    _logger.i('Iniciando login com e-mail.', context: {'email': email});
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _logger.i('Login com e-mail realizado com sucesso.', context: {'email': email});
    } catch (e, st) {
      _logger.e('Falha no login com e-mail.', error: e, stackTrace: st, context: {'email': email});
      throw AppErrorMapper.map(e, st);
    }
  }

  // Verificar se o e-mail está bloqueado temporariamente
  Future<Map<String, dynamic>> checkLock(String email) async {
    _logger.i('Verificando status de bloqueio da conta.', context: {'email': email});
    try {
      final response = await _supabase.rpc(
        'is_email_locked',
        params: {'user_email': email},
      );
      if (response is Map) {
        final data = Map<String, dynamic>.from(response);
        _logger.i('Status de bloqueio obtido com sucesso.', context: {'email': email, 'is_locked': data['is_locked']});
        return data;
      }
      return {'is_locked': false, 'remaining_seconds': 0, 'attempts_count': 0};
    } catch (e, st) {
      _logger.e('Erro ao verificar status de bloqueio no RPC.', error: e, stackTrace: st, context: {'email': email});
      // Em caso de falha física de infraestrutura, retorna falso para não travar completamente o app, 
      // mas propaga erro de rede se for o caso
      throw AppErrorMapper.map(e, st);
    }
  }

  // Registrar tentativa de login (sucesso ou falha)
  Future<void> registerAttempt(String email, bool isSuccess) async {
    _logger.i('Registrando tentativa de login.', context: {'email': email, 'sucesso': isSuccess});
    try {
      await _supabase.rpc(
        'register_login_attempt',
        params: {
          'user_email': email,
          'is_success': isSuccess,
        },
      );
    } catch (e) {
      _logger.w('Falha técnica silenciosa ao registrar tentativa no RPC.', context: {'email': email, 'erro': e.toString()});
      // RPC secundário não deve travar o fluxo primário do app
    }
  }

  // Login com Google OAuth
  Future<void> signInWithGoogle() async {
    _logger.i('Iniciando login via Google OAuth.');
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'orelinhas://login-callback',
      );
    } catch (e, st) {
      _logger.e('Erro no login via Google OAuth.', error: e, stackTrace: st);
      throw AppErrorMapper.map(e, st);
    }
  }

  // Recuperação de senha (Dispara e-mail)
  Future<void> sendPasswordReset(String email) async {
    _logger.i('Solicitando redefinição de senha.', context: {'email': email});
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'orelinhas://login-callback',
      );
      _logger.i('E-mail de redefinição enviado com sucesso.', context: {'email': email});
    } catch (e, st) {
      _logger.e('Erro ao solicitar redefinição de senha.', error: e, stackTrace: st, context: {'email': email});
      throw AppErrorMapper.map(e, st);
    }
  }

  // Atualizar senha (Chamado na tela após clicar no link do e-mail)
  Future<void> updatePassword(String newPassword) async {
    _logger.i('Solicitando alteração de senha de usuário.');
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      _logger.i('Senha alterada com sucesso.');
    } catch (e, st) {
      _logger.e('Erro ao atualizar senha no Supabase.', error: e, stackTrace: st);
      throw AppErrorMapper.map(e, st);
    }
  }

  // Sair (Logout)
  Future<void> signOut() async {
    _logger.i('Solicitando encerramento de sessão (signOut).');
    try {
      await _supabase.auth.signOut();
      _logger.i('Sessão encerrada com sucesso.');
    } catch (e, st) {
      _logger.e('Erro ao encerrar sessão.', error: e, stackTrace: st);
      throw AppErrorMapper.map(e, st);
    }
  }
}
