import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart' show PetType, AlertStatus;
import '../controllers/pet_found_controller.dart';
import '../controllers/public_pet_found_controller.dart';
import '../../domain/pet_found_entity.dart';

class PetFoundListScreen extends ConsumerStatefulWidget {
  const PetFoundListScreen({super.key});

  @override
  ConsumerState<PetFoundListScreen> createState() => _PetFoundListScreenState();
}

class _PetFoundListScreenState extends ConsumerState<PetFoundListScreen>
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
                backgroundColor: Colors.red,
              ),
            );
          },
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pets Encontrados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () => context.push(AppRoutes.petFoundMap),
            tooltip: 'Ver no Mapa',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_tabController.index == 0) {
                ref
                    .read(publicPetFoundControllerProvider.notifier)
                    .refreshAlerts();
              } else {
                ref.read(petFoundControllerProvider.notifier).refreshAlerts();
              }
            },
            tooltip: 'Atualizar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Feed Público', icon: Icon(Icons.public)),
            Tab(text: 'Meus Registros', icon: Icon(Icons.person)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [PublicFeedTab(), MyAlertsTab()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.petFoundCreate),
        backgroundColor: Colors.green,
        tooltip: 'Cadastrar Pet Encontrado',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class PublicFeedTab extends ConsumerWidget {
  const PublicFeedTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsState = ref.watch(publicPetFoundControllerProvider);
    final user = ref.watch(currentUserProvider);

    final filteredAlerts = alertsState.whenData(
      (alerts) =>
          alerts.where((alert) => alert.userId != (user?.id ?? '')).toList(),
    );

    return _AlertListBuilder(
      alertsState: filteredAlerts,
      emptyMessage: 'Nenhum pet encontrado registrado no momento.',
      currentUserId: user?.id,
      onRefresh: () =>
          ref.read(publicPetFoundControllerProvider.notifier).refreshAlerts(),
    );
  }
}

class MyAlertsTab extends ConsumerWidget {
  const MyAlertsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsState = ref.watch(petFoundControllerProvider);
    final user = ref.watch(currentUserProvider);

    return _AlertListBuilder(
      alertsState: alertsState,
      emptyMessage: 'Você não possui nenhum pet encontrado cadastrado.',
      currentUserId: user?.id,
      onRefresh: () =>
          ref.read(petFoundControllerProvider.notifier).refreshAlerts(),
    );
  }
}

class _AlertListBuilder extends ConsumerWidget {
  final AsyncValue<List<PetFoundAlertEntity>> alertsState;
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
    if (rawPhone.length >= 10) {
      final ddd = rawPhone.substring(0, 2);
      if (rawPhone.length == 11) {
        return '($ddd) ${rawPhone.substring(2, 7)}-${rawPhone.substring(7)}';
      } else {
        return '($ddd) ${rawPhone.substring(2, 6)}-${rawPhone.substring(6)}';
      }
    }
    return rawPhone;
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
    PetFoundAlertEntity alert,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Registro'),
        content: Text(
          'Deseja realmente excluir permanentemente o registro deste pet?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(petFoundControllerProvider.notifier).deleteAlert(alert.id);
    }
  }

  Future<void> _confirmResolve(
    BuildContext context,
    WidgetRef ref,
    PetFoundAlertEntity alert,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dono Encontrado'),
        content: const Text(
          'Deseja marcar este registro como resolvido? Ele sairá da lista pública.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Sim, resolvido',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(petFoundControllerProvider.notifier).resolveAlert(alert.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return alertsState.when(
      data: (alerts) {
        if (alerts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.pets_outlined,
                    size: 72,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    emptyMessage,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: alerts.length,
          itemBuilder: (context, index) {
            final alert = alerts[index];
            final isOwner = alert.userId == currentUserId;
            final isResolved = alert.status == AlertStatus.resolved;

            final petTitle = alert.breed != null && alert.breed!.isNotEmpty
                ? alert.breed!
                : (alert.petType == PetType.dog
                    ? 'Cachorro Encontrado'
                    : alert.petType == PetType.cat
                        ? 'Gato Encontrado'
                        : 'Pet Encontrado');

            return Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (alert.imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: Image.network(
                        alert.imageUrl,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 180,
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.broken_image,
                            size: 64,
                            color: Colors.grey,
                          ),
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
                          children: [
                            Expanded(
                              child: Text(
                                petTitle,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              children: [
                                if (isResolved)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Resolvido',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
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
                                        ? Colors.blue[100]
                                        : alert.petType == PetType.cat
                                            ? Colors.orange[100]
                                            : Colors.green[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    alert.petType == PetType.dog
                                        ? 'Cachorro'
                                        : alert.petType == PetType.cat
                                            ? 'Gato'
                                            : 'Outro',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: alert.petType == PetType.dog
                                          ? Colors.blue[900]
                                          : alert.petType == PetType.cat
                                              ? Colors.orange[900]
                                              : Colors.green[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (alert.apparentAge != null && alert.apparentAge!.isNotEmpty)
                          Text(
                            'Idade Aparente: ${alert.apparentAge}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 4),
                        Text(
                          alert.description,
                          style: const TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Último local visto: ${alert.foundLocation}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_month,
                              size: 16,
                              color: Colors.blueGrey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Encontrado em: ${_formatDate(alert.foundDate)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (alert.contact != null && alert.contact!.isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                               Icons.phone,
                               size: 16,
                               color: Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                               'Contato: ${_formatPhone(alert.contact!)}',
                               style: const TextStyle(
                                 fontSize: 13,
                                 fontWeight: FontWeight.bold,
                                 color: Colors.black87,
                               ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        if (isOwner)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text('Editar'),
                                onPressed: () => context.push(
                                  AppRoutes.petFoundEdit(alert.id),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Excluir',
                                  style: TextStyle(color: Colors.red),
                                ),
                                onPressed: () =>
                                    _confirmDelete(context, ref, alert),
                              ),
                              if (!isResolved) ...[
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.check_circle,
                                    size: 18,
                                    color: Colors.green,
                                  ),
                                  label: const Text(
                                    'Dono Encontrado',
                                    style: TextStyle(color: Colors.green),
                                  ),
                                  onPressed: () =>
                                      _confirmResolve(context, ref, alert),
                                ),
                              ],
                            ],
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                icon: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Ver Perfil',
                                  style: TextStyle(color: Colors.white),
                                ),
                                onPressed: () => context.push(
                                  AppRoutes.publicProfile(alert.userId),
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
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) {
        final errMsg = err is AppException
            ? err.message
            : 'Falha ao carregar registros.';
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                errMsg,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRefresh,
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        );
      },
    );
  }
}
