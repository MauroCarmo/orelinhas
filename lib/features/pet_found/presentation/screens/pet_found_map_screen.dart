import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/alerts_map_layout.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart' show PetType;
import '../controllers/public_pet_found_controller.dart';
import '../../domain/pet_found_entity.dart';

/// Mapa de pets encontrados (layout comum em [AlertsMapLayout]).
class PetFoundMapScreen extends ConsumerWidget {
  const PetFoundMapScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsState = ref.watch(publicPetFoundControllerProvider);

    final items = alertsState.value
        ?.where((a) => a.latitude != null && a.longitude != null)
        .map(
          (alert) => MapPetItem(
            id: alert.id,
            title: _petTitle(alert),
            subtitle: switch (alert.petType) {
              PetType.dog => 'Cachorro',
              PetType.cat => 'Gato',
              PetType.other => 'Outro',
            },
            location: alert.foundLocation,
            imageUrl: alert.imageUrl,
            point: LatLng(alert.latitude!, alert.longitude!),
            onOpen: () => context.push(
              '${AppRoutes.publicProfile(alert.userId)}?foundId=${alert.id}',
              extra: alert,
            ),
          ),
        )
        .toList();

    final error = alertsState.hasError
        ? (alertsState.error is AppException
              ? (alertsState.error as AppException).message
              : 'Erro ao carregar registros.')
        : null;

    return AlertsMapLayout(
      kind: AlertsMapKind.found,
      items: items,
      errorMessage: error,
      emptyText: 'Nenhum pet encontrado com localização no mapa ainda.',
      onRefresh: () =>
          ref.read(publicPetFoundControllerProvider.notifier).refreshAlerts(),
    );
  }
}
