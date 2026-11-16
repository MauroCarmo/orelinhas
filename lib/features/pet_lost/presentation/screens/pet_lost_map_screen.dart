import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/alerts_map_layout.dart';
import '../controllers/public_pet_lost_controller.dart';
import '../widgets/pet_widgets.dart';

/// Mapa de pets perdidos (layout comum em [AlertsMapLayout]).
class PetLostMapScreen extends ConsumerWidget {
  const PetLostMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsState = ref.watch(publicPetLostControllerProvider);

    final items = alertsState.value
        ?.where((a) => a.latitude != null && a.longitude != null)
        .map(
          (alert) => MapPetItem(
            id: alert.id,
            title: alert.petName,
            subtitle: PetFormat.subtitle(alert),
            location: alert.lastLocation,
            imageUrl: alert.imageUrl,
            point: LatLng(alert.latitude!, alert.longitude!),
            badge: PetStatusBadge(status: alert.status),
            onOpen: () => context.push(
              '${AppRoutes.publicProfile(alert.userId)}?lostId=${alert.id}',
              extra: alert,
            ),
          ),
        )
        .toList();

    final error = alertsState.hasError
        ? (alertsState.error is AppException
              ? (alertsState.error as AppException).message
              : 'Erro ao carregar alertas.')
        : null;

    return AlertsMapLayout(
      kind: AlertsMapKind.lost,
      items: items,
      errorMessage: error,
      emptyText: 'Nenhum alerta com localização no mapa por enquanto.',
      onRefresh: () =>
          ref.read(publicPetLostControllerProvider.notifier).refreshAlerts(),
    );
  }
}
