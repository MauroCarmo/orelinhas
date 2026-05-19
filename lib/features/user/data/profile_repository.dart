import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/profile_entity.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final supabase = ref.read(supabaseClientProvider);
  return ProfileRepository(supabase);
});

class ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepository(this._supabase);

  /// Obtém o perfil de usuário com base no ID único do usuário autenticado.
  Future<ProfileEntity> getProfile(String id) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', id)
          .single();
      return ProfileEntity.fromJson(data);
    } catch (e) {
      throw Exception('Falha ao obter perfil de usuário: $e');
    }
  }

  /// Atualiza os dados do perfil de usuário na tabela do banco de dados.
  Future<void> updateProfile(ProfileEntity profile) async {
    // Validação de negócio antes da persistência para segurança extra
    final validationError = profile.validate();
    if (validationError != null) {
      throw Exception(validationError);
    }

    try {
      await _supabase
          .from('profiles')
          .update(profile.toJson())
          .eq('id', profile.id);
    } catch (e) {
      throw Exception('Falha ao atualizar o perfil: $e');
    }
  }

  /// Exclui a conta do usuário por completo chamando a função RPC 'delete_own_user' no banco.
  Future<void> deleteAccount() async {
    try {
      await _supabase.rpc('delete_own_user');
      // Limpa a sessão local após exclusão
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Falha ao excluir a conta: $e');
    }
  }
}
