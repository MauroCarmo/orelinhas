import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/notification/presentation/controllers/notification_controller.dart';
import '../routing/app_routes.dart';
import '../theme/app_theme.dart';
import 'orelinhas_logo.dart';
import 'publish_sheet.dart';

/// Estrutura de navegação das áreas principais do app.
///
/// - Celular: barra inferior (Início, Explorar, Publicar, Avisos, Perfil).
/// - PC (>= 900 px): menu lateral fixo com os mesmos destinos, botão
///   "Publicar anúncio" e o link "Sobre o Orelinhas" no rodapé.
class AppShell extends StatelessWidget {
  final Widget child;
  final String location;

  const AppShell({super.key, required this.child, required this.location});

  static const double desktopBreakpoint = 900;

  int get _currentIndex {
    if (location.startsWith(AppRoutes.petLost)) return 1;
    if (location.startsWith(AppRoutes.notifications)) return 2;
    if (location.startsWith(AppRoutes.profile) ||
        location.startsWith(AppRoutes.about)) {
      return 3;
    }
    return 0;
  }

  static final _destinations = [
    (
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Início',
      route: AppRoutes.home,
    ),
    (
      icon: Icons.travel_explore_rounded,
      activeIcon: Icons.travel_explore_rounded,
      label: 'Explorar',
      route: AppRoutes.petLost,
    ),
    (
      icon: Icons.notifications_none_rounded,
      activeIcon: Icons.notifications_rounded,
      label: 'Avisos',
      route: AppRoutes.notifications,
    ),
    (
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Perfil',
      route: AppRoutes.profile,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= desktopBreakpoint;
    final index = _currentIndex;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SideMenu(
              selectedIndex: index,
              aboutSelected: location.startsWith(AppRoutes.about),
            ),
            const VerticalDivider(width: 1, color: AppColors.border),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomBar(selectedIndex: index),
    );
  }
}

/// Menu lateral do PC.
class _SideMenu extends StatelessWidget {
  final int selectedIndex;
  final bool aboutSelected;

  const _SideMenu({required this.selectedIndex, required this.aboutSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 244,
      color: AppColors.surfaceLight,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => context.go(AppRoutes.home),
                    borderRadius: BorderRadius.circular(10),
                    child: const OrelinhasLogo(markSize: 28, fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              for (var i = 0; i < AppShell._destinations.length; i++) ...[
                _SideMenuItem(
                  icon: AppShell._destinations[i].icon,
                  activeIcon: AppShell._destinations[i].activeIcon,
                  label: AppShell._destinations[i].label,
                  selected: i == selectedIndex && !aboutSelected,
                  showBadge: i == 2,
                  onTap: () => context.go(AppShell._destinations[i].route),
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  shape: const StadiumBorder(),
                  minimumSize: const Size(0, 48),
                ),
                onPressed: () => showPublishSheet(context),
                icon: const Icon(Icons.add_rounded, size: 22),
                label: const Text('Publicar anúncio'),
              ),
              const Spacer(),
              _SideMenuItem(
                icon: Icons.info_outline_rounded,
                activeIcon: Icons.info_rounded,
                label: 'Sobre o Orelinhas',
                selected: aboutSelected,
                compact: true,
                onTap: () => context.go(AppRoutes.about),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Text(
                  'Encontre, registre e ajude pets a voltarem para casa.',
                  style: AppTextStyles.bodySmall(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideMenuItem extends ConsumerWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final bool showBadge;
  final bool compact;
  final VoidCallback onTap;

  const _SideMenuItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showBadge = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = selected ? AppColors.primary : AppColors.textPrimary;
    final unread = showBadge ? ref.watch(unreadNotificationCountProvider) : 0;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: compact ? 9 : 13,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                  size: compact ? 20 : 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style:
                        (compact
                                ? AppTextStyles.label(color: AppColors.primary)
                                : AppTextStyles.heading3(color: color))
                            .copyWith(
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                  ),
                ),
                if (unread > 0) _CountBadge(count: unread),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra inferior do celular.
class _BottomBar extends StatelessWidget {
  final int selectedIndex;

  const _BottomBar({required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    final d = AppShell._destinations;

    Widget item(int i) => _NavItem(
      icon: d[i].icon,
      activeIcon: d[i].activeIcon,
      label: d[i].label,
      selected: selectedIndex == i,
      showBadge: i == 2,
      onTap: () => context.go(d[i].route),
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              item(0),
              item(1),
              Expanded(
                child: Center(
                  child: Tooltip(
                    message: 'Publicar anúncio',
                    child: Material(
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      elevation: 3,
                      shadowColor: AppColors.primary.withAlpha(90),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => showPublishSheet(context),
                        child: const SizedBox.square(
                          dimension: 52,
                          child: Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              item(2),
              item(3),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends ConsumerWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final bool showBadge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    final unread = showBadge ? ref.watch(unreadNotificationCountProvider) : 0;

    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: unread > 0 ? '$label, $unread não lidos' : null,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primarySoft
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      selected ? activeIcon : icon,
                      color: color,
                      size: 24,
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 8,
                      top: -4,
                      child: _CountBadge(count: unread),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppTextStyles.bodySmall(color: color).copyWith(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      constraints: const BoxConstraints(minWidth: 18),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
