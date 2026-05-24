import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../controllers/pet_lost_controller.dart';
import '../../domain/pet_lost_entity.dart';

class PetLostListScreen extends ConsumerWidget {
  const PetLostListScreen({super.key});

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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, PetLostAlertEntity alert) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Alerta'),
        content: Text('Deseja realmente excluir permanentemente o alerta do pet "${alert.petName}"?'),
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
      await ref.read(petLostControllerProvider.notifier).deleteAlert(alert.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsState = ref.watch(petLostControllerProvider);

    // Escuta erros e sucessos do controller de forma global na tela
    ref.listen<AsyncValue<List<PetLostAlertEntity>>>(petLostControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          final errorMessage = error is AppException ? error.message : 'Ocorreu um erro inesperado.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Alertas de Pets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(petLostControllerProvider.notifier).refreshAlerts(),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: alertsState.when(
        data: (alerts) {
          if (alerts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.pets_outlined, size: 72, color: Colors.blueGrey),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhum alerta de pet perdido cadastrado.',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Caso tenha perdido seu pet, crie um novo alerta clicando no botão abaixo.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Novo Alerta', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () => context.push(AppRoutes.petLostCreate),
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
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (alert.imageUrl != null && alert.imageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.network(
                          alert.imageUrl!,
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 180,
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
                                  alert.petName,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                          const SizedBox(height: 8),
                          if (alert.breed != null && alert.breed!.isNotEmpty)
                            Text(
                              'Raça: ${alert.breed}',
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          if (alert.age != null && alert.age!.isNotEmpty)
                            Text(
                              'Idade: ${alert.age}',
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 4),
                          Text(
                            alert.description,
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
                                  'Último local: ${alert.lastLocation}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.calendar_month, size: 16, color: Colors.blueGrey),
                              const SizedBox(width: 4),
                              Text(
                                'Desaparecido em: ${_formatDate(alert.lostDate)}',
                                style: const TextStyle(fontSize: 13, color: Colors.black54),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 16, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                'Contato: ${_formatPhone(alert.contact)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text('Editar'),
                                onPressed: () => context.push(AppRoutes.petLostEdit(alert.id)),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                label: const Text('Excluir', style: TextStyle(color: Colors.red)),
                                onPressed: () => _confirmDelete(context, ref, alert),
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
          final errMsg = err is AppException ? err.message : 'Falha ao carregar alertas.';
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(errMsg, style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.refresh(petLostControllerProvider),
                  child: const Text('Tentar Novamente'),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: alertsState.maybeWhen(
        data: (alerts) => alerts.isNotEmpty
            ? FloatingActionButton(
                onPressed: () => context.push(AppRoutes.petLostCreate),
                backgroundColor: Colors.blue,
                tooltip: 'Novo Alerta',
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,
        orElse: () => null,
      ),
    );
  }
}
