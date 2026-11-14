import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_button_styles.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../domain/pet_lost_entity.dart';
import '../controllers/pet_lost_controller.dart';
import '../controllers/public_pet_lost_controller.dart';
import '../widgets/pet_widgets.dart';

/// Detalhes de um alerta de pet perdido.
class PetLostDetailScreen extends ConsumerWidget {
  final String alertId;
  final PetLostAlertEntity? initialAlert;

  const PetLostDetailScreen({
    super.key,
    required this.alertId,
    this.initialAlert,
  });

  PetLostAlertEntity? _findAlert(WidgetRef ref) {
    final lists = [
      ref.watch(petLostControllerProvider).value,
      ref.watch(publicPetLostControllerProvider).value,
    ];
    for (final list in lists) {
      if (list == null) continue;
      for (final alert in list) {
        if (alert.id == alertId) return alert;
      }
    }
    return initialAlert;
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    PetLostAlertEntity alert,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir alerta'),
        content: Text(
          'O alerta de "${alert.petName}" será removido permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: AppButtonStyles.danger().copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(petLostControllerProvider.notifier).deleteAlert(alert.id);
      if (context.mounted) context.pop();
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
        title: const Text('Pet encontrado?'),
        content: Text(
          'Marque "${alert.petName}" como encontrado. O alerta sai do feed público.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: AppButtonStyles.success().copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
            ),
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
    final alert = _findAlert(ref);
    final user = ref.watch(currentUserProvider);

    if (alert == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Alerta não encontrado',
          message: 'Ele pode ter sido removido pelo tutor.',
        ),
      );
    }

    final isOwner = alert.userId == user?.id;
    final isResolved = alert.status == AlertStatus.resolved;
    final hasCoords = alert.latitude != null && alert.longitude != null;
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 320 + topInset,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'pet-${alert.id}',
                    child: PetImage(url: alert.imageUrl),
                  ),
                  Positioned(
                    top: topInset + 10,
                    left: 14,
                    child: _CircleButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      tooltip: 'Voltar',
                      onTap: () => context.pop(),
                    ),
                  ),
                  // Borda arredondada do painel sobre a foto
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: -1,
                    height: 28,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              width: double.infinity,
              child: Container(
                color: AppColors.surfaceLight,
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            alert.petName,
                            style: AppTextStyles.heading1(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: PetStatusBadge(
                            status: alert.status,
                            solid: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Desapareceu em ${PetFormat.date(alert.lostDate)}',
                      style: AppTextStyles.body(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Características',
                      style: AppTextStyles.sectionHeader(),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InfoTile(
                          icon: alert.petType.icon,
                          label: 'Espécie',
                          value: alert.petType.label,
                        ),
                        if (alert.breed != null &&
                            alert.breed!.trim().isNotEmpty)
                          _InfoTile(
                            icon: Icons.pets_rounded,
                            label: 'Raça',
                            value: alert.breed!.trim(),
                          ),
                        if (alert.age != null && alert.age!.trim().isNotEmpty)
                          _InfoTile(
                            icon: Icons.cake_outlined,
                            label: 'Idade',
                            value: alert.age!.trim(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Descrição', style: AppTextStyles.sectionHeader()),
                    const SizedBox(height: 8),
                    Text(
                      alert.description,
                      style: AppTextStyles.body(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    Text('Localização', style: AppTextStyles.sectionHeader()),
                    const SizedBox(height: 10),
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.scaffoldLight,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (hasCoords)
                            SizedBox(
                              height: 150,
                              child: IgnorePointer(
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: LatLng(
                                      alert.latitude!,
                                      alert.longitude!,
                                    ),
                                    initialZoom: 15,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:
                                          'com.example.orelinhas',
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: LatLng(
                                            alert.latitude!,
                                            alert.longitude!,
                                          ),
                                          width: 44,
                                          height: 44,
                                          child: const Icon(
                                            Icons.location_on_rounded,
                                            color: AppColors.error,
                                            size: 44,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.place_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    alert.lastLocation,
                                    style: AppTextStyles.body().copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          PetFormat.phone(alert.contact),
                          style: AppTextStyles.body().copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: isOwner
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isResolved)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('Marcar como encontrado'),
                          onPressed: () => _confirmResolve(context, ref, alert),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.edit_outlined, size: 19),
                            label: const Text('Editar'),
                            onPressed: () =>
                                context.push(AppRoutes.petLostEdit(alert.id)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: AppButtonStyles.outlined(
                              foregroundColor: AppColors.error,
                            ),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 19,
                            ),
                            label: const Text('Excluir'),
                            onPressed: () =>
                                _confirmDelete(context, ref, alert),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Entrar em contato'),
                    onPressed: () =>
                        context.push(AppRoutes.publicProfile(alert.userId)),
                  ),
                ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.scaffoldLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall().copyWith(fontSize: 11),
              ),
              Text(value, style: AppTextStyles.label()),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withAlpha(235),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 42,
            child: Icon(icon, size: 18, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
