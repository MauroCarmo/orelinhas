import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_button_styles.dart';
import '../../../../core/theme/widgets/app_input_decoration.dart';
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

    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final hPad = isDesktop ? 40.0 : 20.0;

    final searchField = TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _query = v),
      decoration: AppInputDecoration.defaultDecoration(
        labelText: '',
        hintText: 'Buscar por nome, raça ou local',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        isSearch: true,
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpar busca',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
      ),
    );

    final feedTabs = _SegmentedTabs(
      index: _tab,
      labels: const ['Feed público', 'Meus alertas'],
      onChanged: (i) => setState(() => _tab = i),
    );

    final speciesChips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterChip(
          label: 'Todos',
          selected: _typeFilter == null,
          onTap: () => setState(() => _typeFilter = null),
        ),
        for (final type in PetType.values)
          _FilterChip(
            label: switch (type) {
              PetType.dog => 'Cachorros',
              PetType.cat => 'Gatos',
              PetType.other => 'Outros',
            },
            selected: _typeFilter == type,
            onTap: () => setState(() => _typeFilter = type),
          ),
      ],
    );

    final grid = source.when(
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
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.74,
            ),
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

    final actions = [
      if (isDesktop)
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 42),
            shape: const StadiumBorder(),
          ),
          onPressed: () => context.go(AppRoutes.petLostMap),
          icon: const Icon(Icons.map_outlined, size: 18),
          label: const Text('Ver no mapa'),
        )
      else
        IconButton(
          icon: const Icon(Icons.map_outlined),
          onPressed: () => context.go(AppRoutes.petLostMap),
          tooltip: 'Ver no mapa',
        ),
      const SizedBox(width: 4),
      IconButton(
        icon: const Icon(Icons.refresh_rounded),
        onPressed: _refresh,
        tooltip: 'Atualizar',
      ),
    ];

    // Conteúdo do topo (limitado à mesma largura das outras telas no PC)
    Widget constrained(Widget child) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: child,
      ),
    );

    final header = isDesktop
        ? Padding(
            padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 0),
            child: constrained(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Explorar',
                              style: AppTextStyles.heading1().copyWith(
                                fontSize: 28,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pets perdidos, encontrados e para adoção perto de você.',
                              style: AppTextStyles.body(
                                color: AppColors.textSecondary,
                              ).copyWith(fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _ExploreSections(current: 0),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 16),
                      SizedBox(width: 320, child: feedTabs),
                    ],
                  ),
                  const SizedBox(height: 14),
                  speciesChips,
                  const SizedBox(height: 10),
                ],
              ),
            ),
          )
        : Padding(
            padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ExploreSections(current: 0),
                const SizedBox(height: 12),
                searchField,
                const SizedBox(height: 12),
                feedTabs,
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: speciesChips,
                ),
                const SizedBox(height: 6),
              ],
            ),
          );

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              // Aba principal (Explorar): sem botão de voltar
              automaticallyImplyLeading: false,
              title: const Text('Explorar'),
              actions: actions,
            ),
      body: Column(
        children: [
          header,
          Expanded(
            child: isDesktop
                ? Center(
                    child: ConstrainedBox(
                      // a grade usa a mesma largura máxima (+ margens)
                      constraints: BoxConstraints(maxWidth: 1120 + hPad * 2),
                      child: grid,
                    ),
                  )
                : grid,
          ),
        ],
      ),
    );
  }
}

/// Seções do Explorar: Perdidos, Encontrados e Adoção.
class _ExploreSections extends StatelessWidget {
  /// 0 = Perdidos, 1 = Encontrados, 2 = Adoção.
  final int current;

  const _ExploreSections({required this.current});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.campaign_outlined, 'Perdidos', AppRoutes.petLost),
      (Icons.check_circle_outline, 'Encontrados', AppRoutes.petFound),
      (Icons.favorite_border_rounded, 'Adoção', AppRoutes.petAdoption),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _SectionButton(
              icon: items[i].$1,
              label: items[i].$2,
              selected: i == current,
              onTap: i == current
                  ? null
                  : () => i == 0
                        ? context.go(items[i].$3)
                        : context.push(items[i].$3),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _SectionButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.primaryDark;
    return Material(
      color: selected ? AppColors.primaryDark : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.primaryDark : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Botões estreitos (celular): ícone e texto menores
            final compact = constraints.maxWidth < 150;
            return Padding(
              padding: EdgeInsets.symmetric(
                vertical: 12,
                horizontal: compact ? 4 : 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: compact ? 16 : 19, color: fg),
                  SizedBox(width: compact ? 5 : 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label(
                        color: fg,
                      ).copyWith(fontSize: compact ? 13 : 14),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _SegmentedTabs({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == index
                        ? AppColors.surfaceLight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: i == index
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: AppTextStyles.label(
                      color: i == index
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        labelStyle: AppTextStyles.label(
          color: selected ? Colors.white : AppColors.textPrimary,
        ),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
    );
  }
}
