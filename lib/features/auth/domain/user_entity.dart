class UserEntity {
  final String id;
  final String email;
  final bool isEmailVerified;

  UserEntity({
    required this.id,
    required this.email,
    required this.isEmailVerified,
  });

  factory UserEntity.fromSupabase(dynamic supabaseUser) {
    return UserEntity(
      id: supabaseUser.id,
      email: supabaseUser.email ?? '',
      // No Supabase v2, confirmamos se o emailAppConfirmAt não é nulo.
      isEmailVerified: supabaseUser.emailConfirmedAt != null,
    );
  }
}
