import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/orelinhas_logo.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
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
              const SizedBox(height: 14),
              const _HeroCard(),
              const SizedBox(height: 18),
              _QuickActions(),
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
          // Foto do cachorro, recortada da arte de entrada
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
              // Recorta só o rosto do cachorro (sem o texto da arte)
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
  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        icon: Icons.campaign_outlined,
        title: 'Pet perdido',
        desc: 'Registre um alerta',
        onTap: () => context.push(AppRoutes.petLostCreate),
      ),
      (
        icon: Icons.search_rounded,
        title: 'Buscar pets',
        desc: 'Veja animais perdidos',
        onTap: () => context.go(AppRoutes.petLost),
      ),
      (
        icon: Icons.map_outlined,
        title: 'Mapa',
        desc: 'Alertas perto de você',
        onTap: () => context.go(AppRoutes.petLostMap),
      ),
      (
        icon: Icons.article_outlined,
        title: 'Meus alertas',
        desc: 'Acompanhe seus registros',
        onTap: () => context.go(AppRoutes.myAlerts),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.15,
      children: [
        for (final a in actions)
          Material(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: a.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(a.icon, color: Colors.white, size: 21),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            style: AppTextStyles.label().copyWith(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                  ],
                ),
              ),
            ),
          ),
      ],
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
