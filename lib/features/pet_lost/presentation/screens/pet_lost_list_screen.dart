import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_button_styles.dart';
import '../../../../core/theme/widgets/app_input_decoration.dart';
import '../../../../core/validation/sanitizers.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../controllers/pet_lost_controller.dart';
import '../controllers/public_pet_lost_controller.dart';
import '../../domain/pet_lost_entity.dart';

class PetLostListScreen extends ConsumerStatefulWidget {
  const PetLostListScreen({super.key});

  @override
  ConsumerState<PetLostListScreen> createState() => _PetLostListScreenState();
}

class _PetLostListScreenState extends ConsumerState<PetLostListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

    return Scaffold(
      backgroundColor: AppColors.scaffoldLight,
      appBar: AppBar(
        title: Text(
          'Pets Perdidos',
          style: AppTextStyles.heading2(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.push(AppRoutes.petLostMap),
            tooltip: 'Ver no Mapa',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_tabController.index == 0) {
                ref
                    .read(publicPetLostControllerProvider.notifier)
                    .refreshAlerts();
              } else {
                ref.read(petLostControllerProvider.notifier).refreshAlerts();
              }
            },
            tooltip: 'Atualizar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelColor: AppColors.accent,
          unselectedLabelColor: Colors.white70,
          labelStyle: AppTextStyles.label(),
          unselectedLabelStyle: AppTextStyles.bodySmall(),
          tabs: const [
            Tab(text: 'Feed Público', icon: Icon(Icons.public, size: 20)),
            Tab(
              text: 'Meus Alertas',
              icon: Icon(Icons.person_outline, size: 20),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [PublicFeedTab(), MyAlertsTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.petLostCreate),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.accent,
        elevation: 4,
        icon: const Icon(Icons.add),
        label: Text('Novo Alerta', style: AppTextStyles.button()),
      ),
    );
  }
}

class PublicFeedTab extends ConsumerStatefulWidget {
  const PublicFeedTab({super.key});

  @override
  ConsumerState<PublicFeedTab> createState() => _PublicFeedTabState();
}

class _PublicFeedTabState extends ConsumerState<PublicFeedTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  PetType? _selectedTypeFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilter(PetLostAlertEntity alert, String currentUserId) {
    if (alert.userId == currentUserId) return false;

    if (_selectedTypeFilter != null && alert.petType != _selectedTypeFilter) {
      return false;
    }

    if (_searchQuery.isEmpty) return true;

    final q = _searchQuery.toLowerCase();
    final name = alert.petName.toLowerCase();
    final breed = (alert.breed ?? '').toLowerCase();
    final location = alert.lastLocation.toLowerCase();
    final desc = alert.description.toLowerCase();

    return name.contains(q) ||
        breed.contains(q) ||
        location.contains(q) ||
        desc.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final alertsState = ref.watch(publicPetLostControllerProvider);
    final user = ref.watch(currentUserProvider);
    final currentUserId = user?.id ?? '';

    final filteredAlerts = alertsState.whenData(
      (alerts) => alerts
          .where((alert) => _matchesFilter(alert, currentUserId))
          .toList(),
    );

    final hasActiveFilters =
        _searchQuery.isNotEmpty || _selectedTypeFilter != null;

    return Column(
      children: [
        // --- Barra de Busca e Filtros Rápidos ---
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: const BoxDecoration(
            color: AppColors.surfaceLight,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
                decoration: AppInputDecoration.defaultDecoration(
                  labelText: 'Buscar por nome, raça, cidade ou bairro...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: 'Limpar busca',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(label: 'Todos', type: null),
                    const SizedBox(width: 8),
                    _buildFilterChip(label: 'Cachorros', type: PetType.dog),
                    const SizedBox(width: 8),
                    _buildFilterChip(label: 'Gatos', type: PetType.cat),
                    const SizedBox(width: 8),
                    _buildFilterChip(label: 'Outros', type: PetType.other),
                  ],
                ),
              ),
            ],
          ),
        ),

        // --- Lista de Resultados ---
        Expanded(
          child: _AlertListBuilder(
            alertsState: filteredAlerts,
            emptyMessage: hasActiveFilters
                ? 'Nenhum pet encontrado com os filtros informados.\nTente buscar por outro nome ou cidade.'
                : 'Nenhum pet perdido no momento.\nTudo tranquilo por aqui!',
            currentUserId: user?.id,
            onRefresh: () => ref
                .read(publicPetLostControllerProvider.notifier)
                .refreshAlerts(),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({required String label, required PetType? type}) {
    final isSelected = _selectedTypeFilter == type;
    return ChoiceChip(
      label: Text(
        label,
        style: AppTextStyles.label(
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.scaffoldLight,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
      onSelected: (_) {
        setState(() {
          _selectedTypeFilter = type;
        });
      },
    );
  }
}

class MyAlertsTab extends ConsumerWidget {
  const MyAlertsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsState = ref.watch(petLostControllerProvider);
    final user = ref.watch(currentUserProvider);

    return _AlertListBuilder(
      alertsState: alertsState,
      emptyMessage: 'Você não possui nenhum alerta de pet perdido cadastrado.',
      currentUserId: user?.id,
      onRefresh: () =>
          ref.read(petLostControllerProvider.notifier).refreshAlerts(),
    );
  }
}

class _AlertListBuilder extends ConsumerWidget {
  final AsyncValue<List<PetLostAlertEntity>> alertsState;
  final String emptyMessage;
  final String? currentUserId;
  final VoidCallback onRefresh;

  const _AlertListBuilder({
    required this.alertsState,
    required this.emptyMessage,
    required this.currentUserId,
    required this.onRefresh,
  });

  String _formatPhone(String rawPhone) {
    var digits = AppSanitizers.digitsOnly(rawPhone);
    if (digits.startsWith('55') &&
        (digits.length == 12 || digits.length == 13)) {
      digits = digits.substring(2);
    }
    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
    }
    if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    }
    return rawPhone;
  }

  String _formatLocationForDisplay(String rawLocation) {
    final trimmed = rawLocation.trim();
    if (!trimmed.contains('Cidade/UF:') && !trimmed.contains(' | ')) {
      return trimmed;
    }

    String street = '';
    String district = '';
    String cityUf = '';
    String ref = '';

    for (final part in trimmed.split(' | ')) {
      final item = part.trim();
      if (item.startsWith('Rua:')) {
        street = item.substring(4).trim();
      } else if (item.startsWith('Bairro:')) {
        district = item.substring(7).trim();
      } else if (item.startsWith('Cidade/UF:')) {
        cityUf = item.substring(10).trim();
      } else if (item.startsWith('Ref:')) {
        ref = item.substring(4).trim();
      }
    }

    final mainParts = <String>[
      if (street.isNotEmpty) street,
      if (district.isNotEmpty) district,
      if (cityUf.isNotEmpty) cityUf,
    ];

    final base = mainParts.join(', ');
    if (ref.isNotEmpty) {
      return base.isNotEmpty ? '$base (Ref: $ref)' : ref;
    }
    return base.isNotEmpty ? base : trimmed;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    PetLostAlertEntity alert,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Excluir Alerta', style: AppTextStyles.heading2()),
        content: Text(
          'Deseja realmente excluir permanentemente o alerta do pet "${alert.petName}"?',
          style: AppTextStyles.body(),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancelar',
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
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

  Future<void> _confirmResolve(
    BuildContext context,
    WidgetRef ref,
    PetLostAlertEntity alert,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Pet Encontrado', style: AppTextStyles.heading2()),
        content: Text(
          'Deseja marcar o alerta de "${alert.petName}" como resolvido? Ele sairá da lista pública.',
          style: AppTextStyles.body(),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancelar',
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return alertsState.when(
      data: (alerts) {
        if (alerts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pets_outlined,
                      size: 64,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    emptyMessage,
                    style: AppTextStyles.heading3(color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final isOwner = alert.userId == currentUserId;
              final isResolved = alert.status == AlertStatus.resolved;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (alert.imageUrl != null && alert.imageUrl!.isNotEmpty)
                      Image.network(
                        alert.imageUrl!,
                        height: 190,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 140,
                          color: AppColors.scaffoldLight,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  alert.petName,
                                  style: AppTextStyles.heading2(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Wrap(
                                spacing: 6,
                                children: [
                                  if (isResolved)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withAlpha(30),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'Resolvido',
                                        style: AppTextStyles.label(
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: alert.petType == PetType.dog
                                          ? Colors.blue.withAlpha(35)
                                          : alert.petType == PetType.cat
                                          ? Colors.orange.withAlpha(35)
                                          : Colors.purple.withAlpha(35),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      alert.petType == PetType.dog
                                          ? 'Cachorro'
                                          : alert.petType == PetType.cat
                                          ? 'Gato'
                                          : 'Outro',
                                      style: AppTextStyles.label(
                                        color: alert.petType == PetType.dog
                                            ? Colors.blue.shade800
                                            : alert.petType == PetType.cat
                                            ? Colors.orange.shade800
                                            : Colors.purple.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Em "Meus Alertas", exibe raça/idade/descrição/telefone próprio
                          if (isOwner) ...[
                            if ((alert.breed != null &&
                                    alert.breed!.isNotEmpty) ||
                                (alert.age != null &&
                                    alert.age!.isNotEmpty)) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (alert.breed != null &&
                                      alert.breed!.isNotEmpty)
                                    Text(
                                      'Raça: ${alert.breed}',
                                      style: AppTextStyles.bodySmall(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  if (alert.breed != null &&
                                      alert.breed!.isNotEmpty &&
                                      alert.age != null &&
                                      alert.age!.isNotEmpty)
                                    const Text(
                                      ' • ',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  if (alert.age != null &&
                                      alert.age!.isNotEmpty)
                                    Text(
                                      'Idade: ${alert.age}',
                                      style: AppTextStyles.bodySmall(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            if (alert.description.trim().isNotEmpty &&
                                alert.description.trim() !=
                                    'Sem descrição adicional.') ...[
                              const SizedBox(height: 10),
                              Text(
                                alert.description,
                                style: AppTextStyles.body(
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],

                          const SizedBox(height: 12),
                          const Divider(color: AppColors.border, height: 1),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Local: ${_formatLocationForDisplay(alert.lastLocation)}',
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Visto em: ${_formatDate(alert.lostDate)}',
                                style: AppTextStyles.bodySmall(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),

                          if (isOwner) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 16,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Contato: ${_formatPhone(alert.contact)}',
                                  style: AppTextStyles.body(
                                    color: AppColors.textPrimary,
                                  ).copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 16),
                          if (isOwner)
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'Editar',
                                    style: AppTextStyles.label(),
                                  ),
                                  onPressed: () => context.push(
                                    AppRoutes.petLostEdit(alert.id),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: BorderSide(
                                      color: AppColors.error.withAlpha(100),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'Excluir',
                                    style: AppTextStyles.label(
                                      color: AppColors.error,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _confirmDelete(context, ref, alert),
                                ),
                                if (!isResolved)
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.warning,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      size: 16,
                                    ),
                                    label: Text(
                                      'Marcar Encontrado',
                                      style: AppTextStyles.label(
                                        color: Colors.white,
                                      ),
                                    ),
                                    onPressed: () =>
                                        _confirmResolve(context, ref, alert),
                                  ),
                              ],
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  style: AppButtonStyles.primary(),
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Ver Detalhes'),
                                  onPressed: () => context.push(
                                    '${AppRoutes.publicProfile(alert.userId)}?lostId=${alert.id}',
                                    extra: alert,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (err, _) {
        final errMsg = err is AppException
            ? err.message
            : 'Falha ao carregar alertas.';
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 56,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  errMsg,
                  style: AppTextStyles.heading3(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: AppButtonStyles.primary(),
                  onPressed: onRefresh,
                  child: const Text('Tentar Novamente'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
