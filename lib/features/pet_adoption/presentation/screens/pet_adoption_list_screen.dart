import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_button_styles.dart';
import '../../../../core/theme/widgets/app_input_decoration.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart' show PetType;
import '../../../pet_lost/presentation/widgets/pet_widgets.dart';
import '../controllers/pet_adoption_controller.dart';
import '../controllers/public_pet_adoption_controller.dart';
import '../../domain/pet_adoption_entity.dart';

class PetAdoptionListScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const PetAdoptionListScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<PetAdoptionListScreen> createState() =>
      _PetAdoptionListScreenState();
}

class _PetAdoptionListScreenState extends ConsumerState<PetAdoptionListScreen> {
  late int _tab = widget.initialTab;
  final _searchController = TextEditingController();
  String _query = '';
  PetType? _speciesFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (_tab == 0) {
      ref.read(publicPetAdoptionControllerProvider.notifier).refreshAdoptions();
    } else {
      ref.read(petAdoptionControllerProvider.notifier).refreshAdoptions();
    }
  }

  List<PetAdoptionAlertEntity> _applyFilters(
    List<PetAdoptionAlertEntity> adoptions,
  ) {
    final q = _query.trim().toLowerCase();
    return adoptions.where((a) {
      if (_speciesFilter != null && a.species != _speciesFilter) return false;
      if (q.isEmpty) return true;
      return a.name.toLowerCase().contains(q) ||
          a.region.toLowerCase().contains(q) ||
          a.characteristics.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _confirmDelete(PetAdoptionAlertEntity adoption) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Excluir Anúncio', style: AppTextStyles.heading2()),
        content: Text(
          'Deseja realmente excluir permanentemente o anúncio de "${adoption.name}"?',
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
      await ref
          .read(petAdoptionControllerProvider.notifier)
          .deleteAdoption(adoption.id);
    }
  }

  Future<void> _confirmAdopted(PetAdoptionAlertEntity adoption) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Marcar como Adotado', style: AppTextStyles.heading2()),
        content: Text(
          'Deseja marcar "${adoption.name}" como Adotado? O anúncio sairá do feed público.',
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
            child: const Text('Sim, foi adotado'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(petAdoptionControllerProvider.notifier)
          .markAsAdopted(adoption.id);
    }
  }

  void _showMyAdoptionOptions(PetAdoptionAlertEntity adoption) {
    final isAdopted = adoption.status == AdoptionStatus.adopted;
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
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar anúncio'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(AppRoutes.petAdoptionEdit(adoption.id));
                },
              ),
              if (!isAdopted)
                ListTile(
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                  ),
                  title: const Text('Marcar como adotado'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmAdopted(adoption);
                  },
                ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Excluir anúncio',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(adoption);
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
    ref.listen<AsyncValue<List<PetAdoptionAlertEntity>>>(
      petAdoptionControllerProvider,
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
              .watch(publicPetAdoptionControllerProvider)
              .whenData(
                (adoptions) => adoptions
                    .where((a) => a.userId != (user?.id ?? ''))
                    .toList(),
              )
        : ref.watch(petAdoptionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Voltar',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        title: const Text('Adoção de pets'),
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
                hintText: 'Buscar por nome, região ou característica',
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
              labels: const ['Para adoção', 'Meus anúncios'],
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
                  selected: _speciesFilter == null,
                  onTap: () => setState(() => _speciesFilter = null),
                ),
                for (final type in PetType.values)
                  _FilterChip(
                    label: switch (type) {
                      PetType.dog => 'Cachorros',
                      PetType.cat => 'Gatos',
                      PetType.other => 'Outros',
                    },
                    selected: _speciesFilter == type,
                    onTap: () => setState(() => _speciesFilter = type),
                  ),
              ],
            ),
          ),
          Expanded(
            child: source.when(
              data: (adoptions) {
                final filtered = _applyFilters(adoptions);
                if (adoptions.isEmpty) {
                  return _tab == 0
                      ? const EmptyState(
                          icon: Icons.favorite_border_rounded,
                          title: 'Nenhum pet para adoção no momento',
                          message:
                              'Volte mais tarde ou cadastre um pet que precisa de um lar.',
                        )
                      : EmptyState(
                          icon: Icons.pets_outlined,
                          title: 'Você ainda não anunciou pets para adoção',
                          message:
                              'Ajude um animalzinho a encontrar uma família responsável.',
                          actionLabel: 'Anunciar pet para adoção',
                          onAction: () =>
                              context.push(AppRoutes.petAdoptionCreate),
                        );
                }
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Nenhum pet com esses filtros',
                    message:
                        'Tente outra região ou remova o filtro de espécie.',
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
                          childAspectRatio: 0.72,
                        ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final adoption = filtered[index];
                      return _AdoptionGridCard(
                        adoption: adoption,
                        onTap: () {
                          if (_tab == 1) {
                            _showMyAdoptionOptions(adoption);
                          } else {
                            context.push(
                              AppRoutes.publicProfile(adoption.userId),
                              extra: adoption,
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
                    : 'Falha ao carregar adoções.',
                message: 'Verifique sua conexão e tente novamente.',
                actionLabel: 'Tentar novamente',
                onAction: _refresh,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.petAdoptionCreate),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Anunciar Adoção',
          style: AppTextStyles.button(color: Colors.white),
        ),
      ),
    );
  }
}

class _AdoptionGridCard extends StatelessWidget {
  final PetAdoptionAlertEntity adoption;
  final VoidCallback onTap;

  const _AdoptionGridCard({required this.adoption, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isAdopted = adoption.status == AdoptionStatus.adopted;
    final speciesLabel = switch (adoption.species) {
      PetType.dog => 'Cachorro',
      PetType.cat => 'Gato',
      PetType.other => 'Outro',
    };

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
                  PetImage(url: adoption.imageUrl),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isAdopted
                            ? AppColors.textSecondary
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isAdopted ? 'Adotado' : 'Adoção',
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
                    adoption.name,
                    style: AppTextStyles.heading3(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$speciesLabel • ${adoption.isVaccinated ? 'Vacinado' : 'Sem vacina inf.'}',
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
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          adoption.region,
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
