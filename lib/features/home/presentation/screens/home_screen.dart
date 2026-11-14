import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/orelinhas_logo.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../notification/presentation/widgets/notification_badge_button.dart';
import '../../../pet_lost/presentation/controllers/public_pet_lost_controller.dart';
import '../../../pet_lost/presentation/widgets/pet_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final fullName = (user?.userMetadata?['name'] as String?)?.trim();
    final firstName = (fullName == null || fullName.isEmpty)
        ? null
        : fullName.split(' ').first;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref
              .read(publicPetLostControllerProvider.notifier)
              .refreshAlerts(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Row(
                children: [
                  const OrelinhasLogo(markSize: 30, fontSize: 24),
                  const Spacer(),
                  const NotificationBadgeButton(),
                  const SizedBox(width: 6),
                  _RoundIconButton(
                    icon: Icons.person_outline_rounded,
                    tooltip: 'Meu perfil',
                    onTap: () => context.go(AppRoutes.profile),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                firstName == null ? 'Olá!' : 'Olá, $firstName!',
                style: AppTextStyles.heading2(),
              ),
              const SizedBox(height: 4),
              Text(
                'Gerenciamento inteligente para proteção e bem-estar animal.',
                style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              _ReportAbuseBanner(
                onTap: () => context.push(AppRoutes.reportAbuse),
              ),
              const SizedBox(height: 14),
              const _HeroCard(),
              const SizedBox(height: 18),
              const _QuickActions(),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Animais recentes',
                      style: AppTextStyles.sectionHeader(),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.petLost),
                    child: const Text('Ver todos'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const _RecentPets(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: 0,
            bottom: 0,
            width: 190,
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                colors: [Colors.transparent, Colors.black],
                stops: [0, 0.35],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: FittedBox(
                fit: BoxFit.cover,
                child: ClipRect(
                  child: Align(
                    alignment: const Alignment(-0.6, 0.02),
                    widthFactor: 0.6,
                    heightFactor: 0.34,
                    child: Image.asset(
                      'assets/images/welcome.webp',
                      width: 720,
                      height: 1280,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 150, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'E se quem encontrou seu pet não souber que você está procurando?',
                  style: AppTextStyles.heading3(color: Colors.white).copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Registre um alerta e deixe a vizinhança ajudar.',
                  style: AppTextStyles.bodySmall(
                    color: Colors.white.withAlpha(210),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        icon: Icons.pets,
        title: 'Pets Perdidos',
        desc: 'Mural de alertas e buscas',
        onTap: () => context.go(AppRoutes.petLost),
      ),
      (
        icon: Icons.check_circle_outline,
        title: 'Pets Encontrados',
        desc: 'Mural de achados',
        onTap: () => context.push(AppRoutes.petFound),
      ),
      (
        icon: Icons.favorite_border_rounded,
        title: 'Adoção de Pets',
        desc: 'Divulgue ou encontre pets',
        onTap: () => context.push(AppRoutes.petAdoption),
      ),
      (
        icon: Icons.map_outlined,
        title: 'Mapa de Alertas',
        desc: 'Alertas perto de você',
        onTap: () => context.go(AppRoutes.petLostMap),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Em telas pequenas (< 360) usa aspect ratio menor (cards mais altos)
        final ratio = constraints.maxWidth < 340 ? 1.55 : 1.85;
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: ratio,
          children: [
            for (final a in actions)
              Material(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: a.onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(a.icon, color: Colors.white, size: 20),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          a.title,
                          style: AppTextStyles.label().copyWith(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a.desc,
                          style: AppTextStyles.bodySmall().copyWith(
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecentPets extends ConsumerWidget {
  const _RecentPets();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsState = ref.watch(publicPetLostControllerProvider);

    return alertsState.when(
      data: (alerts) {
        if (alerts.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.favorite_border_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nenhum pet perdido por perto agora. Que bom!',
                    style: AppTextStyles.body(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          );
        }

        final recent = alerts.take(10).toList();
        return SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final alert = recent[index];
              return SizedBox(
                width: 156,
                child: PetGridCard(
                  alert: alert,
                  onTap: () => context.push(
                    AppRoutes.petLostDetails(alert.id),
                    extra: alert,
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 214,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Não foi possível carregar os alertas. Puxe para baixo para tentar de novo.',
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surfaceLight,
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 42,
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
        ),
      ),
    );
  }
}

class _ReportAbuseBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _ReportAbuseBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF2D1CC)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC75A47).withAlpha(15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFC75A47),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Denunciar Maus-Tratos',
                      style: AppTextStyles.heading3(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Relate situações de risco ou abandono de forma segura e anônima.',
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
