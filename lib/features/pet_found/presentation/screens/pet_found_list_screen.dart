import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_button_styles.dart';
import '../../../../core/theme/widgets/app_input_decoration.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart'
    show PetType, AlertStatus;
import '../../../pet_lost/presentation/widgets/pet_widgets.dart';
import '../controllers/pet_found_controller.dart';
import '../controllers/public_pet_found_controller.dart';
import '../../domain/pet_found_entity.dart';

class PetFoundListScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const PetFoundListScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<PetFoundListScreen> createState() => _PetFoundListScreenState();
}

class _PetFoundListScreenState extends ConsumerState<PetFoundListScreen> {
  late int _tab = widget.initialTab;
  final _searchController = TextEditingController();
  String _query = '';
  PetType? _typeFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (_tab == 0) {
      ref.read(publicPetFoundControllerProvider.notifier).refreshAlerts();
    } else {
      ref.read(petFoundControllerProvider.notifier).refreshAlerts();
    }
  }

  List<PetFoundAlertEntity> _applyFilters(List<PetFoundAlertEntity> alerts) {
    final q = _query.trim().toLowerCase();
    return alerts.where((a) {
      if (_typeFilter != null && a.petType != _typeFilter) return false;
      if (q.isEmpty) return true;
      return (a.breed ?? '').toLowerCase().contains(q) ||
          a.foundLocation.toLowerCase().contains(q) ||
          a.description.toLowerCase().contains(q) ||
          (a.apparentAge ?? '').toLowerCase().contains(q);
    }).toList();
  }

  String _petTitle(PetFoundAlertEntity alert) {
    if (alert.breed != null && alert.breed!.isNotEmpty) {
      return alert.breed!;
    }
    return switch (alert.petType) {
      PetType.dog => 'Cachorro Encontrado',
      PetType.cat => 'Gato Encontrado',
      PetType.other => 'Pet Encontrado',
    };
  }

  String _formatLocationShort(String rawLocation) {
    final trimmed = rawLocation.trim();
    if (!trimmed.contains('Cidade/UF:') && !trimmed.contains(' | ')) {
      return trimmed;
    }
    String street = '';
    String district = '';
    String cityUf = '';
    for (final part in trimmed.split(' | ')) {
      final item = part.trim();
      if (item.startsWith('Rua:')) street = item.substring(4).trim();
      if (item.startsWith('Bairro:')) district = item.substring(7).trim();
      if (item.startsWith('Cidade/UF:')) cityUf = item.substring(10).trim();
    }
    final parts = [
      if (street.isNotEmpty) street,
      if (district.isNotEmpty) district,
      if (cityUf.isNotEmpty) cityUf,
    ];
    return parts.isNotEmpty ? parts.join(', ') : trimmed;
  }

  Future<void> _confirmDelete(PetFoundAlertEntity alert) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Excluir Registro', style: AppTextStyles.heading2()),
        content: Text(
          'Deseja realmente excluir permanentemente o registro deste pet?',
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
      await ref.read(petFoundControllerProvider.notifier).deleteAlert(alert.id);
    }
  }

  Future<void> _confirmResolve(PetFoundAlertEntity alert) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Dono Encontrado', style: AppTextStyles.heading2()),
        content: Text(
          'Deseja marcar este registro como resolvido? Ele sairá da lista pública.',
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
            child: const Text('Sim, resolvido'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(petFoundControllerProvider.notifier)
          .resolveAlert(alert.id);
    }
  }

  void _showMyAlertOptions(PetFoundAlertEntity alert) {
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
                title: const Text('Ver detalhes do registro'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(
                    '${AppRoutes.publicProfile(alert.userId)}?foundId=${alert.id}',
                    extra: alert,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar registro'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(AppRoutes.petFoundEdit(alert.id));
                },
              ),
              if (!isResolved)
                ListTile(
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                  ),
                  title: const Text('Marcar como dono encontrado'),
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
                  'Excluir registro',
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
    ref.listen<AsyncValue<List<PetFoundAlertEntity>>>(
      petFoundControllerProvider,
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
    final source = _tab == 0
        ? ref
              .watch(publicPetFoundControllerProvider)
              .whenData(
                (alerts) =>
                    alerts.where((a) => a.userId != (user?.id ?? '')).toList(),
              )
        : ref.watch(petFoundControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Voltar',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        title: const Text('Pets encontrados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.push(AppRoutes.petFoundMap),
            tooltip: 'Ver no Mapa',
          ),
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
                hintText: 'Buscar por raça, cidade ou bairro',
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
              labels: const ['Feed público', 'Meus registros'],
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
                          icon: Icons.pets_outlined,
                          title: 'Nenhum pet encontrado no momento',
                          message:
                              'Quando alguém registrar um pet encontrado, ele aparecerá aqui.',
                        )
                      : EmptyState(
                          icon: Icons.add_a_photo_outlined,
                          title: 'Você ainda não registrou pets encontrados',
                          message:
                              'Encontrou um pet na rua? Registre uma foto e localização para ajudar o tutor a encontrá-lo.',
                          actionLabel: 'Registrar pet encontrado',
                          onAction: () =>
                              context.push(AppRoutes.petFoundCreate),
                        );
                }
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Nenhum pet com esses filtros',
                    message: 'Tente outra busca ou remova o filtro de espécie.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
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
                      return _FoundPetGridCard(
                        alert: alert,
                        title: _petTitle(alert),
                        location: _formatLocationShort(alert.foundLocation),
                        onTap: () {
                          if (_tab == 1) {
                            _showMyAlertOptions(alert);
                          } else {
                            context.push(
                              '${AppRoutes.publicProfile(alert.userId)}?foundId=${alert.id}',
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
                title: err is AppException
                    ? err.message
                    : 'Falha ao carregar registros.',
                message: 'Verifique sua conexão e tente novamente.',
                actionLabel: 'Tentar novamente',
                onAction: _refresh,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.petFoundCreate),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Novo Registro', style: AppTextStyles.button()),
      ),
    );
  }
}

class _FoundPetGridCard extends StatelessWidget {
  final PetFoundAlertEntity alert;
  final String title;
  final String location;
  final VoidCallback onTap;

  const _FoundPetGridCard({
    required this.alert,
    required this.title,
    required this.location,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isResolved = alert.status == AlertStatus.resolved;
    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PetImage(url: alert.imageUrl),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isResolved
                            ? AppColors.textSecondary
                            : AppColors.success,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isResolved ? 'Resolvido' : 'Encontrado',
                        style: AppTextStyles.label(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.heading3(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    switch (alert.petType) {
                      PetType.dog => 'Cachorro',
                      PetType.cat => 'Gato',
                      PetType.other => 'Outro',
                    },
                    style: AppTextStyles.bodySmall(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          location,
                          style: AppTextStyles.bodySmall(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
