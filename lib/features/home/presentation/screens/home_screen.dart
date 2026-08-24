import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profileName = user?.userMetadata?['name'] ?? 'Visitante';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.pets, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Text('Orelinhas', style: AppTextStyles.heading2(color: AppColors.primary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
            tooltip: 'Sair',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: AppTextStyles.heading1(),
                children: [
                  const TextSpan(text: 'Olá, '),
                  TextSpan(
                    text: profileName,
                    style: const TextStyle(color: AppColors.primary),
                  ),
                  const TextSpan(text: '! 👋'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gerenciamento inteligente para proteção e bem-estar animal.',
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 25),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: (() {
                final width = MediaQuery.of(context).size.width;
                final computed = (width / 2 - 26) / 115;
                return computed > 0 ? computed : 1.2;
              })(),
              children: [
                _buildHubItem(
                  icon: Icons.pets,
                  title: 'Pets Perdidos',
                  desc: 'Mural de alertas e buscas',
                  onTap: () => context.push(AppRoutes.petLost),
                ),
                _buildHubItem(
                  icon: Icons.check_circle_outline,
                  title: 'Pets Encontrados',
                  desc: 'Mural de achados',
                  onTap: () => context.push(AppRoutes.petFound),
                ),
                _buildHubItem(
                  icon: Icons.favorite,
                  title: 'Adoção de Pets',
                  desc: 'Divulgue ou encontre pets',
                  onTap: () => context.push(AppRoutes.petAdoption),
                ),
                _buildHubItem(
                  icon: Icons.person,
                  title: 'Minha Conta',
                  desc: 'Perfil e configurações',
                  onTap: () => context.push(AppRoutes.profile),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHubItem({
    required IconData icon,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 28, color: AppColors.primary),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.heading3(),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

