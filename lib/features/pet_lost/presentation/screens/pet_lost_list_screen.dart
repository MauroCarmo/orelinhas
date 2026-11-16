import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_button_styles.dart';
import '../../../../core/widgets/explore_layout.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../controllers/pet_lost_controller.dart';
import '../controllers/public_pet_lost_controller.dart';
import '../../domain/pet_lost_entity.dart';
import '../widgets/pet_widgets.dart';

class PetLostListScreen extends ConsumerStatefulWidget {
  /// 0 = feed público, 1 = meus alertas.
  final int initialTab;

  const PetLostListScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<PetLostListScreen> createState() => _PetLostListScreenState();
}

class _PetLostListScreenState extends ConsumerState<PetLostListScreen> {
  late int _tab = widget.initialTab;
  final _searchController = TextEditingController();
  String _query = '';
  PetType? _typeFilter;

  @override
  void didUpdateWidget(covariant PetLostListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _tab = widget.initialTab;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (_tab == 0) {
      ref.read(publicPetLostControllerProvider.notifier).refreshAlerts();
    } else {
      ref.read(petLostControllerProvider.notifier).refreshAlerts();
    }
  }

  List<PetLostAlertEntity> _applyFilters(List<PetLostAlertEntity> alerts) {
    final q = _query.trim().toLowerCase();
    return alerts.where((a) {
      if (_typeFilter != null && a.petType != _typeFilter) return false;
      if (q.isEmpty) return true;
      return a.petName.toLowerCase().contains(q) ||
          (a.breed ?? '').toLowerCase().contains(q) ||
          a.description.toLowerCase().contains(q) ||
          a.lastLocation.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _confirmDelete(PetLostAlertEntity alert) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Excluir Alerta', style: AppTextStyles.heading2()),
        content: Text(
          'Deseja realmente excluir permanentemente o alerta do pet "${alert.petName}"?',
          style: AppTextStyles.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: AppButtonStyles.danger(),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(petLostControllerProvider.notifier).deleteAlert(alert.id);
    }
  }

  Future<void> _confirmResolve(PetLostAlertEntity alert) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Pet Encontrado', style: AppTextStyles.heading2()),
        content: Text(
          'Deseja marcar o alerta de "${alert.petName}" como resolvido? Ele sairá da lista pública.',
          style: AppTextStyles.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: AppButtonStyles.success(),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sim, foi encontrado'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(petLostControllerProvider.notifier).resolveAlert(alert.id);
    }
  }

  void _showMyAlertOptions(PetLostAlertEntity alert) {
    final isResolved = alert.status == AlertStatus.resolved;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Ver detalhes do alerta'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(
                    '${AppRoutes.publicProfile(alert.userId)}?lostId=${alert.id}',
                    extra: alert,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar alerta'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(AppRoutes.petLostEdit(alert.id));
                },
              ),
              if (!isResolved)
                ListTile(
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                  ),
                  title: const Text('Marcar como encontrado'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmResolve(alert);
                  },
                ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Excluir alerta',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(alert);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<PetLostAlertEntity>>>(
      petLostControllerProvider,
      (previous, next) {
        next.whenOrNull(
          error: (error, _) {
            final errorMessage = error is AppException
                ? error.message
                : 'Ocorreu um erro inesperado.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: AppColors.error,
              ),
            );
          },
        );
      },
    );

    final user = ref.watch(currentUserProvider);
    final AsyncValue<List<PetLostAlertEntity>> source = _tab == 0
        ? ref
              .watch(publicPetLostControllerProvider)
              .whenData(
                (alerts) =>
                    alerts.where((a) => a.userId != (user?.id ?? '')).toList(),
              )
        : ref.watch(petLostControllerProvider);

    return ExploreLayout(
      section: ExploreSection.lost,
      searchController: _searchController,
      query: _query,
      searchHint: 'Buscar por nome, raça ou local',
      onQueryChanged: (v) => setState(() => _query = v),
      tab: _tab,
      tabLabels: const ['Feed público', 'Meus alertas'],
      onTabChanged: (i) => setState(() => _tab = i),
      filterLabels: [
        for (final type in PetType.values)
          switch (type) {
            PetType.dog => 'Cachorros',
            PetType.cat => 'Gatos',
            PetType.other => 'Outros',
          },
      ],
      selectedFilter: _typeFilter == null
          ? -1
          : PetType.values.indexOf(_typeFilter!),
      onFilterChanged: (i) =>
          setState(() => _typeFilter = i == -1 ? null : PetType.values[i]),
      mapRoute: AppRoutes.petLostMap,
      onRefresh: _refresh,
      bodyBuilder: (hPad) => _buildGrid(source, hPad),
    );
  }

  Widget _buildGrid(AsyncValue<List<PetLostAlertEntity>> source, double hPad) {
    return source.when(
      data: (alerts) {
        final filtered = _applyFilters(alerts);
        if (alerts.isEmpty) {
          return _tab == 0
              ? const EmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: 'Nenhum pet perdido no momento',
                  message:
                      'Tudo tranquilo por aqui. Volte mais tarde ou veja o mapa.',
                )
              : EmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'Você ainda não registrou alertas',
                  message:
                      'Se o seu pet sumiu, registre um alerta para que outras pessoas possam ajudar.',
                  actionLabel: 'Registrar pet perdido',
                  onAction: () => context.push(AppRoutes.petLostCreate),
                );
        }
        if (filtered.isEmpty) {
          return const EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Nenhum pet com esses filtros',
            message: 'Tente outro nome ou remova o filtro de espécie.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
            gridDelegate: ExploreLayout.gridDelegate,
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final alert = filtered[index];
              return PetGridCard(
                alert: alert,
                onTap: () {
                  if (_tab == 1) {
                    _showMyAlertOptions(alert);
                  } else {
                    context.push(
                      '${AppRoutes.publicProfile(alert.userId)}?lostId=${alert.id}',
                      extra: alert,
                    );
                  }
                },
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => EmptyState(
        icon: Icons.wifi_off_rounded,
        color: AppColors.error,
        title: err is AppException ? err.message : 'Falha ao carregar alertas.',
        message: 'Verifique sua conexão e tente novamente.',
        actionLabel: 'Tentar novamente',
        onAction: _refresh,
      ),
    );
  }
}

/// Seções do Explorar: Perdidos, Encontrados e Adoção.
