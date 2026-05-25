// user/presentation/controllers/public_profile_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/profile_repository.dart';
import '../../domain/profile_entity.dart';

/// Provider que busca o perfil de qualquer usuário pelo ID.
/// Usado para visualização pública, sem estado de edição.
final publicProfileProvider = FutureProvider.family<ProfileEntity, String>((
  ref,
  userId,
) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getProfile(userId);
});
