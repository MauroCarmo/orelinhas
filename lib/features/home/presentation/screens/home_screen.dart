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
                        style: isDesktop
                            ? AppTextStyles.heading1().copyWith(fontSize: 28)
                            : AppTextStyles.heading2(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gerenciamento inteligente para proteção e bem-estar animal.',
                        style: AppTextStyles.bodySmall(
                          color: AppColors.textSecondary,
                        ).copyWith(fontSize: isDesktop ? 14 : 12),
                      ),
                      SizedBox(height: isDesktop ? 22 : 14),
                      const _HeroCard(),
                      const SizedBox(height: 16),
                      const _QuickActions(),
                      const SizedBox(height: 16),
                      _ReportAbuseBanner(
                        onTap: () => context.push(AppRoutes.reportAbuse),
                      ),
                      const SizedBox(height: 28),
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

/// Banner de destaque: texto sobre o verde à esquerda e a foto do cachorro
/// à direita. Um degradê do mesmo verde do fundo passa POR CIMA da foto, então
/// a transição entre o verde e a imagem fica contínua, sem borda.
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isWide = width >= 640;
        final height = isWide ? 220.0 : 200.0;
        // A área da foto acompanha a proporção do recorte (cachorro e gato),
        // para não ampliar demais em telas largas.
        final photoWidth = isWide
            ? (height * 1.6).clamp(0.0, width * 0.5)
            : width * 0.55;

        return Container(
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            children: [
              // Foto recortada no rosto do cachorro
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: photoWidth,
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    alignment: Alignment.center,
                    child: ClipRect(
                      // Recorte do rosto do cachorro com o gato
                      child: Align(
                        alignment: const Alignment(0, 0.23),
                        heightFactor: 0.43,
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
              // Degradê do verde do fundo sobre a foto (transição suave).
              // Começa um pouco antes da foto para esconder a emenda.
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: photoWidth + 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: const [
                        AppColors.primaryDark,
                        Color(0xD9143F30),
                        Color(0x66143F30),
                        Color(0x00143F30),
                      ],
                      stops: isWide
                          ? const [0.02, 0.25, 0.55, 0.85]
                          : const [0.05, 0.45, 0.75, 1.0],
                    ),
                  ),
                ),
              ),
              // Texto e botão
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 32 : 20,
                  20,
                  isWide ? photoWidth * 0.75 : width * 0.32,
                  20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'E se quem encontrou seu pet não souber que você está procurando?',
                      style: AppTextStyles.heading3(color: Colors.white)
                          .copyWith(
                            fontSize: isWide ? 22 : 17,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Registre um alerta e deixe a vizinhança ajudar.',
                      style: AppTextStyles.bodySmall(
                        color: Colors.white.withAlpha(215),
                      ).copyWith(fontSize: isWide ? 14 : 12),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () => context.push(AppRoutes.petLostCreate),
                      icon: const Icon(Icons.campaign_outlined, size: 18),
                      label: const Text('Registrar alerta'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
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
        // PC: os 4 atalhos numa linha só. Celular: grade 2x2 compacta.
        final wide = constraints.maxWidth >= 760;
        final columns = wide ? 4 : 2;
        final tileHeight = wide ? 92.0 : 116.0;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio:
              (constraints.maxWidth - 12 * (columns - 1)) /
              columns /
              tileHeight,
          children: [
            for (final a in actions)
              _QuickActionTile(action: a, horizontal: wide),
          ],
        );
      },
    );
  }
}

typedef _QuickAction = ({
  IconData icon,
  String title,
  String desc,
  VoidCallback onTap,
});

/// Atalho compacto: ícone à esquerda, título e descrição, seta à direita.
class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;

  /// PC: ícone à esquerda. Celular: ícone em cima (cabe melhor em 2 colunas).
  final bool horizontal;

  const _QuickActionTile({required this.action, this.horizontal = true});

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(action.icon, color: AppColors.primary, size: 22),
    );
    final texts = Column(
      mainAxisAlignment: horizontal
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          action.title,
          style: AppTextStyles.heading3().copyWith(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          action.desc,
          style: AppTextStyles.bodySmall(),
          maxLines: horizontal ? 2 : 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: action.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: horizontal
              ? Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: texts),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      icon,
                      const SizedBox(height: 10),
                      Expanded(child: texts),
                    ],
                  ),
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
                  AppRoutes.petLostDetails(alert.id),
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
                      style: AppTextStyles.heading3(
                        color: AppColors.textPrimary,
                      ),
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
