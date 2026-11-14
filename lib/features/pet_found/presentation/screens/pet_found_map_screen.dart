import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart' show PetType;
import '../../../pet_lost/presentation/widgets/pet_widgets.dart';
import '../controllers/public_pet_found_controller.dart';
import '../../domain/pet_found_entity.dart';

class PetFoundMapScreen extends ConsumerStatefulWidget {
  const PetFoundMapScreen({super.key});

  @override
  ConsumerState<PetFoundMapScreen> createState() => _PetFoundMapScreenState();
}

class _PetFoundMapScreenState extends ConsumerState<PetFoundMapScreen> {
  PetFoundAlertEntity? _selected;

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
  Widget build(BuildContext context) {
    final alertsState = ref.watch(publicPetFoundControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Voltar',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.petFound),
        ),
        title: const Text('Pets encontrados no mapa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref
                .read(publicPetFoundControllerProvider.notifier)
                .refreshAlerts(),
            tooltip: 'Atualizar',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: alertsState.when(
        data: (alerts) {
          final located = alerts
              .where((a) => a.latitude != null && a.longitude != null)
              .toList();

          final markers = located
              .map(
                (alert) => Marker(
                  point: LatLng(alert.latitude!, alert.longitude!),
                  width: 56,
                  height: 66,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () => setState(() => _selected = alert),
                    child: Tooltip(
                      message: _petTitle(alert),
                      child: _FoundPetPin(
                        alert: alert,
                        selected: _selected?.id == alert.id,
                      ),
                    ),
                  ),
                ),
              )
              .toList();

          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: markers.isNotEmpty
                          ? markers.first.point
                          : const LatLng(-23.5505, -46.6333),
                      initialZoom: 13.0,
                      onTap: (_, _) => setState(() => _selected = null),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.orelinhas',
                      ),
                      MarkerLayer(markers: markers),
                    ],
                  ),
                ),
              ),
              if (located.isEmpty)
                const Positioned(
                  left: 28,
                  right: 28,
                  top: 16,
                  child: _MapNotice(
                    text:
                        'Nenhum pet encontrado com localização no mapa ainda.',
                  ),
                ),
              if (_selected != null)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 16,
                  child: _SelectedFoundPetCard(
                    alert: _selected!,
                    title: _petTitle(_selected!),
                    onClose: () => setState(() => _selected = null),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          final msg = err is AppException
              ? err.message
              : 'Erro ao carregar registros.';
          return EmptyState(
            icon: Icons.map_outlined,
            color: AppColors.error,
            title: msg,
            actionLabel: 'Tentar novamente',
            onAction: () => ref
                .read(publicPetFoundControllerProvider.notifier)
                .refreshAlerts(),
          );
        },
      ),
    );
  }
}

class _FoundPetPin extends StatelessWidget {
  final PetFoundAlertEntity alert;
  final bool selected;

  const _FoundPetPin({required this.alert, required this.selected});

  @override
  Widget build(BuildContext context) {
    final ring = selected ? AppColors.success : Colors.white;
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: ring,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(45),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(child: PetImage(url: alert.imageUrl)),
        ),
        CustomPaint(size: const Size(14, 9), painter: _PinTipPainter(ring)),
      ],
    );
  }
}

class _PinTipPainter extends CustomPainter {
  final Color color;
  _PinTipPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinTipPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SelectedFoundPetCard extends StatelessWidget {
  final PetFoundAlertEntity alert;
  final String title;
  final VoidCallback onClose;

  const _SelectedFoundPetCard({
    required this.alert,
    required this.title,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLight,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox.square(
                    dimension: 64,
                    child: PetImage(url: alert.imageUrl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
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
                      Text(switch (alert.petType) {
                        PetType.dog => 'Cachorro',
                        PetType.cat => 'Gato',
                        PetType.other => 'Outro',
                      }, style: AppTextStyles.bodySmall()),
                      Text(
                        alert.foundLocation,
                        style: AppTextStyles.bodySmall(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46)),
                onPressed: () => context.push(
                  '${AppRoutes.publicProfile(alert.userId)}?foundId=${alert.id}',
                  extra: alert,
                ),
                child: const Text('Ver detalhes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapNotice extends StatelessWidget {
  final String text;
  const _MapNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLight,
      elevation: 3,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.bodySmall(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
