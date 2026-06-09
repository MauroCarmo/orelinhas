import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart' show PetType;
import '../controllers/pet_adoption_controller.dart';
import '../controllers/public_pet_adoption_controller.dart';
import '../../domain/pet_adoption_entity.dart';

class PetAdoptionListScreen extends ConsumerStatefulWidget {
  const PetAdoptionListScreen({super.key});

  @override
  ConsumerState<PetAdoptionListScreen> createState() => _PetAdoptionListScreenState();
}

class _PetAdoptionListScreenState extends ConsumerState<PetAdoptionListScreen>
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
                backgroundColor: Colors.red,
              ),
            );
          },
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adoção de Pets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_tabController.index == 0) {
                ref.read(publicPetAdoptionControllerProvider.notifier).refreshAdoptions();
              } else {
                ref.read(petAdoptionControllerProvider.notifier).refreshAdoptions();
              }
            },
            tooltip: 'Atualizar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pets para Adoção', icon: Icon(Icons.favorite)),
            Tab(text: 'Meus Anúncios', icon: Icon(Icons.folder_shared)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          PublicAdoptionsTab(),
          MyAdoptionsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.petAdoptionCreate),
        backgroundColor: Colors.green,
        tooltip: 'Anunciar Pet para Adoção',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class PublicAdoptionsTab extends ConsumerStatefulWidget {
  const PublicAdoptionsTab({super.key});

  @override
  ConsumerState<PublicAdoptionsTab> createState() => _PublicAdoptionsTabState();
}

class _PublicAdoptionsTabState extends ConsumerState<PublicAdoptionsTab> {
  final _searchRegionController = TextEditingController();
  PetType? _selectedSpeciesFilter;

  @override
  void dispose() {
    _searchRegionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adoptionsState = ref.watch(publicPetAdoptionControllerProvider);
    final user = ref.watch(currentUserProvider);

    return Column(
      children: [
        // Filtros
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchRegionController,
                      decoration: const InputDecoration(
                        hintText: 'Filtrar por Região...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<PetType?>(
                    value: _selectedSpeciesFilter,
                    hint: const Text('Espécie'),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Todas'),
                      ),
                      DropdownMenuItem(
                        value: PetType.dog,
                        child: Text('Cachorro'),
                      ),
                      DropdownMenuItem(
                        value: PetType.cat,
                        child: Text('Gato'),
                      ),
                      DropdownMenuItem(
                        value: PetType.other,
                        child: Text('Outro'),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedSpeciesFilter = val;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        // Listagem
        Expanded(
          child: adoptionsState.when(
            data: (adoptions) {
              // Filtrar anúncios do próprio usuário (feed público deve mostrar dos outros)
              var list = adoptions.where((a) => a.userId != (user?.id ?? '')).toList();

              // Filtro por Região
              final searchRegion = _searchRegionController.text.toLowerCase().trim();
              if (searchRegion.isNotEmpty) {
                list = list.where((a) => a.region.toLowerCase().contains(searchRegion)).toList();
              }

              // Filtro por Espécie
              if (_selectedSpeciesFilter != null) {
                list = list.where((a) => a.species == _selectedSpeciesFilter).toList();
              }

              return _AdoptionListBuilder(
                adoptions: list,
                emptyMessage: 'Nenhum pet disponível para adoção no momento.',
                isMyList: false,
                onRefresh: () => ref.read(publicPetAdoptionControllerProvider.notifier).refreshAdoptions(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) {
              final errMsg = err is AppException ? err.message : 'Falha ao carregar adoções.';
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(errMsg, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.read(publicPetAdoptionControllerProvider.notifier).refreshAdoptions(),
                      child: const Text('Tentar Novamente'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class MyAdoptionsTab extends ConsumerWidget {
  const MyAdoptionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adoptionsState = ref.watch(petAdoptionControllerProvider);

    return adoptionsState.when(
      data: (adoptions) {
        return _AdoptionListBuilder(
          adoptions: adoptions,
          emptyMessage: 'Você não cadastrou nenhum pet para adoção ainda.',
          isMyList: true,
          onRefresh: () => ref.read(petAdoptionControllerProvider.notifier).refreshAdoptions(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) {
        final errMsg = err is AppException ? err.message : 'Falha ao carregar seus anúncios.';
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(errMsg, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(petAdoptionControllerProvider.notifier).refreshAdoptions(),
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdoptionListBuilder extends ConsumerWidget {
  final List<PetAdoptionAlertEntity> adoptions;
  final String emptyMessage;
  final bool isMyList;
  final VoidCallback onRefresh;

  const _AdoptionListBuilder({
    required this.adoptions,
    required this.emptyMessage,
    required this.isMyList,
    required this.onRefresh,
  });

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, PetAdoptionAlertEntity adoption) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Anúncio'),
        content: const Text('Deseja realmente excluir permanentemente este anúncio de adoção?'),
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
      await ref.read(petAdoptionControllerProvider.notifier).deleteAdoption(adoption.id);
    }
  }

  Future<void> _confirmAdopted(BuildContext context, WidgetRef ref, PetAdoptionAlertEntity adoption) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marcar como Adotado'),
        content: const Text(
          'Deseja marcar este pet como Adotado? O anúncio sairá do feed público, mas permanecerá registrado para métricas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Marcar como Adotado', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(petAdoptionControllerProvider.notifier).markAsAdopted(adoption.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (adoptions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite_border, size: 72, color: Colors.blueGrey),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: adoptions.length,
      itemBuilder: (context, index) {
        final adoption = adoptions[index];
        final isAdopted = adoption.status == AdoptionStatus.adopted;

        final speciesLabel = adoption.species == PetType.dog
            ? 'Cachorro'
            : adoption.species == PetType.cat
                ? 'Gato'
                : 'Outro';

        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (adoption.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                    adoption.imageUrl,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, size: 64, color: Colors.grey),
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
                            adoption.name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            if (isAdopted)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Adotado 🎉',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: adoption.species == PetType.dog
                                    ? Colors.blue[100]
                                    : adoption.species == PetType.cat
                                        ? Colors.orange[100]
                                        : Colors.green[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                speciesLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: adoption.species == PetType.dog
                                      ? Colors.blue[900]
                                      : adoption.species == PetType.cat
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
                    Row(
                      children: [
                        const Icon(Icons.health_and_safety, size: 16, color: Colors.teal),
                        const SizedBox(width: 4),
                        Text(
                          adoption.isVaccinated ? 'Vacinado' : 'Não Vacinado / Informação não disponível',
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 4),
                    Text(
                      adoption.characteristics,
                      style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Região: ${adoption.region}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isMyList)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Editar'),
                            onPressed: () => context.push(AppRoutes.petAdoptionEdit(adoption.id)),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                            label: const Text('Excluir', style: TextStyle(color: Colors.red)),
                            onPressed: () => _confirmDelete(context, ref, adoption),
                          ),
                          if (!isAdopted) ...[
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              icon: const Icon(Icons.check_circle, size: 18, color: Colors.white),
                              label: const Text('Adotado!', style: TextStyle(color: Colors.white)),
                              onPressed: () => _confirmAdopted(context, ref, adoption),
                            ),
                          ],
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            icon: const Icon(Icons.person, color: Colors.white, size: 18),
                            label: const Text('Ver Anunciante', style: TextStyle(color: Colors.white)),
                            onPressed: () => context.push(AppRoutes.publicProfile(adoption.userId)),
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
  }
}
