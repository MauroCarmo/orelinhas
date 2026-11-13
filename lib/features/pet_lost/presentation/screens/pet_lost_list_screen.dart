import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar pets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
            tooltip: 'Atualizar',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
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
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SegmentedTabs(
              index: _tab,
              labels: const ['Feed público', 'Meus alertas'],
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
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
            ),
          ),
          Expanded(
            child: source.when(
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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 240,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.74,
                        ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final alert = filtered[index];
                      return PetGridCard(
                        alert: alert,
                        onTap: () => context.push(
                          AppRoutes.petLostDetails(alert.id),
                          extra: alert,
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => EmptyState(
                icon: Icons.wifi_off_rounded,
                color: AppColors.error,
                title: err is AppException
                    ? err.message
                    : 'Falha ao carregar alertas.',
                message: 'Verifique sua conexão e tente novamente.',
                actionLabel: 'Tentar novamente',
                onAction: _refresh,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
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
