// user/presentation/screens/public_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../controllers/public_profile_controller.dart';
import '../../domain/profile_entity.dart';

class PublicProfileScreen extends ConsumerWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(publicProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil do Dono')),
      body: profileAsync.when(
        data: (profile) => _ProfileContent(profile: profile),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          final msg = err is AppException
              ? err.message
              : 'Erro ao carregar perfil.';
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(msg, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(publicProfileProvider(userId)),
                  child: const Text('Tentar novamente'),
                ),
              ],
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

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Foto placeholder (futuramente avatar)
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.blueGrey[100],
            child: Icon(Icons.person, size: 60, color: Colors.blueGrey[600]),
          ),
          const SizedBox(height: 24),
          Text(
            profile.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (phone.isNotEmpty)
            Text(
              phone,
              style: const TextStyle(fontSize: 18, color: Colors.black87),
            ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    location,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
          if (phone.isNotEmpty) ...[
            // Botão Ligar
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.green,
              ),
              icon: const Icon(Icons.phone, color: Colors.white),
              label: const Text(
                'Ligar',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              onPressed: () => _launchUrl('tel:$phone'),
            ),
            const SizedBox(height: 12),
            // Botão WhatsApp
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF25D366),
              ),
              icon: const Icon(Icons.chat, color: Colors.white),
              label: const Text(
                'WhatsApp',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              onPressed: () {
                // Assume que o telefone já está no formato DDD + número (ex: 11999999999)
                // Para Brasil, adiciona o código +55. Ajuste conforme necessário.
                final whatsappUrl = 'https://wa.me/55$phone';
                _launchUrl(whatsappUrl);
              },
            ),
          ],
        ],
      ),
    );
  }
}
