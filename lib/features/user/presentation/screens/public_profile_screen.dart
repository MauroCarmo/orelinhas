// user/presentation/screens/public_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_button_styles.dart';
import '../controllers/public_profile_controller.dart';
import '../../domain/profile_entity.dart';

class PublicProfileScreen extends ConsumerWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(publicProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Falar com o tutor')),
      body: profileAsync.when(
        data: (profile) => _ProfileContent(profile: profile),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          final msg = err is AppException
              ? err.message
              : 'Erro ao carregar perfil.';
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 56,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    msg,
                    style: AppTextStyles.body(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () =>
                        ref.invalidate(publicProfileProvider(userId)),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final ProfileEntity profile;

  const _ProfileContent({required this.profile});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = profile.phone;
    final location = profile.location;
    final hasAvatar =
        profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.primarySoft,
                  backgroundImage: hasAvatar
                      ? NetworkImage(profile.avatarUrl!)
                      : null,
                  child: hasAvatar
                      ? null
                      : const Icon(
                          Icons.person_rounded,
                          size: 52,
                          color: AppColors.primary,
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  profile.name,
                  style: AppTextStyles.heading1(),
                  textAlign: TextAlign.center,
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 17,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          location,
                          style: AppTextStyles.body(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    style: AppTextStyles.body(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (phone.isNotEmpty) ...[
            Text(
              'Conte onde e quando você viu o pet. Uma foto ajuda muito.',
              style: AppTextStyles.body(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Botão WhatsApp
            ElevatedButton.icon(
              style: AppButtonStyles.primary(
                backgroundColor: const Color(0xFF1FAF5A),
              ),
              icon: const Icon(Icons.chat_rounded),
              label: const Text('Conversar no WhatsApp'),
              onPressed: () {
                // Assume que o telefone já está no formato DDD + número (ex: 11999999999)
                // Para Brasil, adiciona o código +55. Ajuste conforme necessário.
                final whatsappUrl = 'https://wa.me/55$phone';
                _launchUrl(whatsappUrl);
              },
            ),
            const SizedBox(height: 12),
            // Botão Ligar
            OutlinedButton.icon(
              icon: const Icon(Icons.phone_outlined),
              label: const Text('Ligar'),
              onPressed: () => _launchUrl('tel:$phone'),
            ),
          ] else
            Text(
              'Este tutor ainda não informou um telefone.',
              style: AppTextStyles.body(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
