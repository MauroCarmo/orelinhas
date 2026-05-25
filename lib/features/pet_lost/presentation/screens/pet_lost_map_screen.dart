import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../controllers/public_pet_lost_controller.dart';
import '../../domain/pet_lost_entity.dart';

class PetLostMapScreen extends ConsumerWidget {
  const PetLostMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsState = ref.watch(publicPetLostControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Pets Perdidos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref
                .read(publicPetLostControllerProvider.notifier)
                .refreshAlerts(),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: alertsState.when(
        data: (alerts) {
          // Filtra apenas alertas com coordenadas válidas
          final markers = alerts
              .where((a) => a.latitude != null && a.longitude != null)
              .map(
                (alert) => Marker(
                  point: LatLng(alert.latitude!, alert.longitude!),
                  width: 40,
                  height: 40,
                  child: Tooltip(
                    message: alert.petName,
                    child: Icon(Icons.pets, color: Colors.red, size: 30),
                  ),
                ),
              )
              .toList();

          return FlutterMap(
            options: MapOptions(
              initialCenter: markers.isNotEmpty
                  ? markers.first.point
                  : const LatLng(-23.5505, -46.6333), // São Paulo como fallback
              initialZoom: 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              MarkerLayer(markers: markers),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          final msg = err is AppException
              ? err.message
              : 'Erro ao carregar alertas.';
          return Center(child: Text(msg));
        },
      ),
    );
  }
}
