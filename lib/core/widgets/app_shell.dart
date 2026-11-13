import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../routing/app_routes.dart';
import '../theme/app_theme.dart';

/// Estrutura com a barra de navegação inferior das áreas principais do app
/// (Início, Buscar, Novo alerta, Mapa e Perfil).
class AppShell extends StatelessWidget {
  final Widget child;
  final String location;

  const AppShell({super.key, required this.child, required this.location});

  int get _currentIndex {
    if (location.startsWith(AppRoutes.petLostMap)) return 3;
    if (location.startsWith(AppRoutes.petLost)) return 1;
    if (location.startsWith(AppRoutes.profile)) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
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
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Início',
                  selected: index == 0,
                  onTap: () => context.go(AppRoutes.home),
                ),
                _NavItem(
                  icon: Icons.search_rounded,
                  activeIcon: Icons.search_rounded,
                  label: 'Buscar',
                  selected: index == 1,
                  onTap: () => context.go(AppRoutes.petLost),
                ),
                Expanded(
                  child: Center(
                    child: Tooltip(
                      message: 'Registrar pet perdido',
                      child: Material(
                        color: AppColors.primary,
                        shape: const CircleBorder(),
                        elevation: 3,
                        shadowColor: AppColors.primary.withAlpha(90),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => context.push(AppRoutes.petLostCreate),
                          child: const SizedBox.square(
                            dimension: 50,
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
                _NavItem(
                  icon: Icons.map_outlined,
                  activeIcon: Icons.map_rounded,
                  label: 'Mapa',
                  selected: index == 3,
                  onTap: () => context.go(AppRoutes.petLostMap),
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Perfil',
                  selected: index == 4,
                  onTap: () => context.go(AppRoutes.profile),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, color: color, size: 25),
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
