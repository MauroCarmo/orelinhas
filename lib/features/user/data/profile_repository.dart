import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/exceptions/error_mapper.dart';
import '../../../core/logger/app_logger.dart';
import '../domain/profile_entity.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final supabase = ref.read(supabaseClientProvider);
  return ProfileRepository(supabase);
});

class ProfileRepository {
  final SupabaseClient _supabase;
  final _logger = AppLogger.category('ProfileRepository');

  ProfileRepository(this._supabase);

  /// Obtém o perfil de usuário com base no ID único do usuário autenticado.
  Future<ProfileEntity> getProfile(String id) async {
    _logger.i('Buscando perfil público do usuário.', context: {'userId': id});
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', id)
          .single();
      _logger.i('Perfil de usuário obtido com sucesso.', context: {'userId': id});
      return ProfileEntity.fromJson(data);
    } catch (e, st) {
      _logger.e('Falha técnica ao obter perfil de usuário.', error: e, stackTrace: st, context: {'userId': id});
      throw AppErrorMapper.map(e, st);
    }
  }

  /// Atualiza os dados do perfil de usuário na tabela do banco de dados.
  Future<void> updateProfile(ProfileEntity profile) async {
    _logger.i('Iniciando atualização de perfil.', context: {'userId': profile.id});
    
    // 1. Validação estrita de negócio no nível de domínio/repositório (Defesa em Profundidade)
    final validationError = profile.validate();
    if (validationError != null) {
      _logger.w('Validação de domínio falhou no repositório.', context: {'userId': profile.id, 'erro': validationError});
      throw ValidationException(validationError);
    }

    try {
      await _supabase
          .from('profiles')
          .update(profile.toJson())
          .eq('id', profile.id);
      _logger.i('Perfil de usuário atualizado no Supabase com sucesso.', context: {'userId': profile.id});
    } catch (e, st) {
      _logger.e('Falha técnica ao atualizar o perfil na tabela.', error: e, stackTrace: st, context: {'userId': profile.id});
      throw AppErrorMapper.map(e, st);
    }
  }

  /// Exclui a conta do usuário por completo chamando a função RPC 'delete_own_user' no banco.
  Future<void> deleteAccount() async {
    final user = _supabase.auth.currentUser;
    final userId = user?.id ?? 'desconhecido';
    
    _logger.w('Iniciando exclusão permanente de conta de usuário.', context: {'userId': userId});
    try {
      await _supabase.rpc('delete_own_user');
      // Limpa a sessão local após exclusão
      await _supabase.auth.signOut();
      _logger.i('Conta de usuário excluída e sessão encerrada com sucesso.', context: {'userId': userId});
    } catch (e, st) {
      _logger.e('Falha crítica ao excluir conta de usuário via RPC.', error: e, stackTrace: st, context: {'userId': userId});
      throw AppErrorMapper.map(e, st);
    }
  }
}
