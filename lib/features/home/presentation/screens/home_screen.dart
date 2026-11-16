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

/// Cores extras usadas só nos blocos de atalho da home.
class _HomeColors {
  static const sun = Color(0xFFF4E7C9);
  static const sunText = Color(0xFF6B4A12);
  static const sky = Color(0xFFE3EEF3);
  static const skyText = Color(0xFF24506A);
  static const red = Color(0xFFC75A47);
  static const redSoft = Color(0xFFFDF1EE);
  static const redText = Color(0xFF8E3526);
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final fullName = (user?.userMetadata?['name'] as String?)?.trim();
    final firstName = (fullName == null || fullName.isEmpty)
        ? null
        : fullName.split(' ').first;

    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref
              .read(publicPetLostControllerProvider.notifier)
              .refreshAlerts(),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 40 : 20,
              isDesktop ? 32 : 12,
              isDesktop ? 40 : 20,
              32,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  // No PC o conteúdo fica centralizado com largura máxima
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // No PC o logo, os avisos e o perfil já estão no menu
                      // lateral; no celular ficam no topo.
                      if (!isDesktop) ...[
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
                      ],
                      Text(
                        firstName == null ? 'Olá!' : 'Olá, $firstName!',
                        style: AppTextStyles.heading1().copyWith(
                          fontSize: isDesktop ? 28 : 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gerenciamento inteligente para proteção e bem-estar animal.',
                        style: AppTextStyles.body(
                          color: AppColors.textSecondary,
                        ).copyWith(fontSize: isDesktop ? 15 : 13),
                      ),
                      SizedBox(height: isDesktop ? 22 : 16),
                      const _HeroCard(),
                      SizedBox(height: isDesktop ? 18 : 14),
                      const _QuickTiles(),
                      SizedBox(height: isDesktop ? 18 : 14),
                      _ReportAbuseStrip(
                        onTap: () => context.push(AppRoutes.reportAbuse),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Animais recentes',
                              style: AppTextStyles.sectionHeader().copyWith(
                                fontSize: 18,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go(AppRoutes.petLost),
                            child: const Text('Ver todos'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _RecentPets(grid: isDesktop),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Foto do banner: pessoa abraçando o cachorro reencontrado no parque.
class _BannerPhoto extends StatelessWidget {
  const _BannerPhoto();

  /// Proporção da imagem (1200x600).
  static const double aspect = 2;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/home_banner.webp',
      fit: BoxFit.cover,
      semanticLabel: 'Pessoa abraçando um cachorro num parque',
    );
  }
}

/// Banner dividido: texto sobre fundo branco e a foto ao lado (PC) ou em
/// cima (celular), sempre inteira. Sem degradê, sem emenda entre cor e foto.
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;

        final text = Padding(
          padding: wide
              ? const EdgeInsets.fromLTRB(36, 30, 28, 30)
              : const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'PET PERDIDO?',
                style: AppTextStyles.label(
                  color: AppColors.primary,
                ).copyWith(fontSize: 11.5, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'E se quem encontrou seu pet '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'não souber',
                          style: _titleStyle(wide, AppColors.primary),
                        ),
                      ),
                    ),
                    const TextSpan(text: ' que você está procurando?'),
                  ],
                ),
                style: _titleStyle(wide, AppColors.primaryDark),
              ),
              const SizedBox(height: 10),
              Text(
                'Registre um alerta e deixe a vizinhança ajudar.',
                style: AppTextStyles.body(
                  color: AppColors.textSecondary,
                ).copyWith(fontSize: wide ? 15 : 13),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => context.push(AppRoutes.petLostCreate),
                icon: const Icon(Icons.campaign_outlined, size: 19),
                label: const Text('Registrar alerta'),
              ),
            ],
          ),
        );

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border),
          ),
          child: wide
              ? SizedBox(
                  height: 250,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: text),
                      // Foto na proporção dela (2:1), então aparece inteira
                      const AspectRatio(
                        aspectRatio: _BannerPhoto.aspect,
                        child: _BannerPhoto(),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AspectRatio(
                      aspectRatio: _BannerPhoto.aspect,
                      child: _BannerPhoto(),
                    ),
                    text,
                  ],
                ),
        );
      },
    );
  }

  static TextStyle _titleStyle(bool wide, Color color) =>
      AppTextStyles.heading1(color: color).copyWith(
        fontSize: wide ? 26 : 20,
        fontWeight: FontWeight.w900,
        height: 1.2,
      );
}

typedef _Tile = ({
  IconData icon,
  String title,
  String desc,
  Color background,
  Color foreground,
  VoidCallback onTap,
});

/// Atalhos em blocos coloridos com um ícone grande de fundo.
class _QuickTiles extends ConsumerWidget {
  const _QuickTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Quantidade de alertas já carregados na lista de perdidos
    final lostCount = ref.watch(publicPetLostControllerProvider).value?.length;

    final tiles = <_Tile>[
      (
        icon: Icons.pets,
        title: 'Pets perdidos',
        desc: lostCount == null || lostCount == 0
            ? 'Mural de alertas'
            : lostCount == 1
            ? '1 alerta ativo'
            : '$lostCount alertas ativos',
        background: AppColors.primaryDark,
        foreground: Colors.white,
        onTap: () => context.go(AppRoutes.petLost),
      ),
      (
        icon: Icons.check_circle_outline,
        title: 'Encontrados',
        desc: 'Mural de achados',
        background: AppColors.accent,
        foreground: AppColors.primaryDark,
        onTap: () => context.push(AppRoutes.petFound),
      ),
      (
        icon: Icons.favorite_border_rounded,
        title: 'Adoção',
        desc: 'Divulgue ou adote',
        background: _HomeColors.sun,
        foreground: _HomeColors.sunText,
        onTap: () => context.push(AppRoutes.petAdoption),
      ),
      (
        icon: Icons.map_outlined,
        title: 'Mapa',
        desc: 'Alertas perto de você',
        background: _HomeColors.sky,
        foreground: _HomeColors.skyText,
        onTap: () => context.go(AppRoutes.petLostMap),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // PC: os 4 numa linha. Celular: grade 2x2.
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        final tileHeight = columns == 4 ? 150.0 : 128.0;
        const gap = 14.0;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          childAspectRatio:
              (constraints.maxWidth - gap * (columns - 1)) /
              columns /
              tileHeight,
          children: [for (final t in tiles) _QuickTile(tile: t)],
        );
      },
    );
  }
}

class _QuickTile extends StatelessWidget {
  final _Tile tile;

  const _QuickTile({required this.tile});

  @override
  Widget build(BuildContext context) {
    final dark = tile.background == AppColors.primaryDark;
    return Material(
      color: tile.background,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: tile.onTap,
        child: Stack(
          children: [
            // Ícone grande decorativo no canto
            Positioned(
              right: -10,
              top: -10,
              child: ExcludeSemantics(
                child: Icon(
                  tile.icon,
                  size: 84,
                  color: tile.foreground.withAlpha(dark ? 45 : 55),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: dark
                          ? Colors.white.withAlpha(38)
                          : Colors.white.withAlpha(180),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(tile.icon, size: 20, color: tile.foreground),
                  ),
                  const Spacer(),
                  Text(
                    tile.title,
                    style: AppTextStyles.heading3(
                      color: tile.foreground,
                    ).copyWith(fontSize: 16, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tile.desc,
                    style: AppTextStyles.bodySmall(
                      color: tile.foreground.withAlpha(205),
                    ).copyWith(fontSize: 12.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Faixa discreta para denunciar maus-tratos.
class _ReportAbuseStrip extends StatelessWidget {
  final VoidCallback onTap;

  const _ReportAbuseStrip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _HomeColors.redSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 520;
              final question = Text(
                'Viu maus-tratos ou abandono?',
                style: AppTextStyles.label(
                  color: _HomeColors.redText,
                ).copyWith(fontSize: 14),
              );
              final link = Text(
                'Denunciar de forma anônima',
                style: AppTextStyles.label(color: _HomeColors.redText).copyWith(
                  fontSize: wide ? 14 : 13,
                  decoration: TextDecoration.underline,
                  decorationColor: _HomeColors.redText,
                ),
              );
              return Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: _HomeColors.red,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: wide
                        ? Row(children: [question, const Spacer(), link])
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              question,
                              const SizedBox(height: 2),
                              link,
                            ],
                          ),
                  ),
                  if (!wide)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _HomeColors.redText,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RecentPets extends ConsumerWidget {
  /// No PC mostra os animais em grade em vez de carrossel.
  final bool grid;

  const _RecentPets({this.grid = false});

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

        if (grid) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recent.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisExtent: 240,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
            ),
            itemBuilder: (context, index) {
              final alert = recent[index];
              return PetGridCard(
                alert: alert,
                onTap: () => context.push(
                  // Mesma tela de detalhes do Explorar
                  '${AppRoutes.publicProfile(alert.userId)}?lostId=${alert.id}',
                  extra: alert,
                ),
              );
            },
          );
        }

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
                    // Mesma tela de detalhes do Explorar
                    '${AppRoutes.publicProfile(alert.userId)}?lostId=${alert.id}',
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
