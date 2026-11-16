import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_button_styles.dart';
import '../../../../core/widgets/explore_layout.dart';
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

    return ExploreLayout(
      section: ExploreSection.found,
      searchController: _searchController,
      query: _query,
      searchHint: 'Buscar por raça, cidade ou bairro',
      onQueryChanged: (v) => setState(() => _query = v),
      tab: _tab,
      tabLabels: const ['Feed público', 'Meus registros'],
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
      mapRoute: AppRoutes.petFoundMap,
      onRefresh: _refresh,
      bodyBuilder: (hPad) => _buildGrid(source, hPad),
    );
  }

  Widget _buildGrid(AsyncValue<List<PetFoundAlertEntity>> source, double hPad) {
    return source.when(
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
                  onAction: () => context.push(AppRoutes.petFoundCreate),
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
            padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
            gridDelegate: ExploreLayout.gridDelegate,
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
