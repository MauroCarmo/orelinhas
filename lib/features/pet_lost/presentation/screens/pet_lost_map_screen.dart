import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_button_styles.dart';
import '../controllers/public_pet_lost_controller.dart';

class PetLostMapScreen extends ConsumerWidget {
  const PetLostMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsState = ref.watch(publicPetLostControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldLight,
      appBar: AppBar(
        title: Text(
          'Mapa de Pets Perdidos',
          style: AppTextStyles.heading2(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
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
          final markers = alerts
              .where((a) => a.latitude != null && a.longitude != null)
              .map(
                (alert) => Marker(
                  point: LatLng(alert.latitude!, alert.longitude!),
                  width: 44,
                  height: 44,
                  child: Tooltip(
                    message: alert.petName,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.pets, color: AppColors.error, size: 24),
                    ),
                  ),
                ),
              )
              .toList();

          return FlutterMap(
            options: MapOptions(
              initialCenter: markers.isNotEmpty
                  ? markers.first.point
                  : const LatLng(-23.5505, -46.6333),
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
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) {
          final msg = err is AppException
              ? err.message
              : 'Erro ao carregar alertas.';
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(msg, style: AppTextStyles.body(color: AppColors.error)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: AppButtonStyles.primary(),
                    onPressed: () => ref
                        .read(publicPetLostControllerProvider.notifier)
                        .refreshAlerts(),
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
