import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../features/pet_lost/presentation/widgets/pet_widgets.dart';
import '../routing/app_routes.dart';
import '../theme/app_theme.dart';

/// Qual mapa está aberto.
enum AlertsMapKind { lost, found }

/// Pet exibido no mapa (independe se é perdido ou encontrado).
class MapPetItem {
  final String id;
  final String title;
  final String subtitle;
  final String location;
  final String? imageUrl;
  final LatLng point;
  final Widget? badge;
  final VoidCallback onOpen;

  const MapPetItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.location,
    required this.imageUrl,
    required this.point,
    required this.onOpen,
    this.badge,
  });
}

/// Estrutura visual comum aos mapas de perdidos e encontrados.
///
/// PC: título, alternância Perdidos/Encontrados, lista de pets ao lado do
/// mapa (clicar centraliza o pet) e cartão do pet selecionado.
/// Celular: mapa em tela cheia com a alternância em cima.
class AlertsMapLayout extends StatefulWidget {
  final AlertsMapKind kind;

  /// null enquanto carrega.
  final List<MapPetItem>? items;
  final String? errorMessage;
  final VoidCallback onRefresh;
  final String emptyText;

  const AlertsMapLayout({
    super.key,
    required this.kind,
    required this.items,
    required this.onRefresh,
    required this.emptyText,
    this.errorMessage,
  });

  @override
  State<AlertsMapLayout> createState() => _AlertsMapLayoutState();
}

class _AlertsMapLayoutState extends State<AlertsMapLayout> {
  final _mapController = MapController();
  String? _selectedId;

  static const _defaultCenter = LatLng(-23.5505, -46.6333);

  MapPetItem? get _selected {
    final items = widget.items ?? const [];
    for (final i in items) {
      if (i.id == _selectedId) return i;
    }
    return null;
  }

  void _select(MapPetItem item, {bool move = false}) {
    setState(() => _selectedId = item.id);
    if (move) _mapController.move(item.point, 15);
  }

  String get _listRoute => widget.kind == AlertsMapKind.lost
      ? AppRoutes.petLost
      : AppRoutes.petFound;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final items = widget.items;

    Widget body;
    if (widget.errorMessage != null) {
      body = EmptyState(
        icon: Icons.map_outlined,
        color: AppColors.error,
        title: widget.errorMessage!,
        actionLabel: 'Tentar novamente',
        onAction: widget.onRefresh,
      );
    } else if (items == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = isDesktop ? _desktopBody(items) : _mobileBody(items);
    }

    final refreshButton = IconButton(
      icon: const Icon(Icons.refresh_rounded),
      onPressed: widget.onRefresh,
      tooltip: 'Atualizar',
    );

    if (isDesktop) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.fromLTRB(40, 28, 40, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mapa de alertas',
                          style: AppTextStyles.heading1().copyWith(
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Veja onde os pets foram vistos pela última vez ou encontrados.',
                          style: AppTextStyles.body(
                            color: AppColors.textSecondary,
                          ).copyWith(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => context.go(_listRoute),
                    icon: const Icon(Icons.grid_view_rounded, size: 18),
                    label: const Text('Ver em lista'),
                  ),
                  const SizedBox(width: 4),
                  refreshButton,
                ],
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 420,
                  child: _KindToggle(current: widget.kind),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Mapa de alertas'),
        actions: [refreshButton, const SizedBox(width: 4)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _KindToggle(current: widget.kind),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _map(List<MapPetItem> items, {BorderRadius? radius}) {
    final selected = _selected;
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.circular(24),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: items.isNotEmpty ? items.first.point : _defaultCenter,
          initialZoom: 13.0,
          onTap: (_, _) => setState(() => _selectedId = null),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.orelinhas',
          ),
          MarkerLayer(
            markers: [
              for (final item in items)
                Marker(
                  point: item.point,
                  width: 56,
                  height: 66,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () => _select(item),
                    child: Tooltip(
                      message: item.title,
                      child: _PetPin(
                        imageUrl: item.imageUrl,
                        selected: selected?.id == item.id,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _desktopBody(List<MapPetItem> items) {
    final selected = _selected;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Lista de pets ao lado do mapa
        SizedBox(
          width: 340,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                  child: Text(
                    items.isEmpty
                        ? 'Nenhum pet no mapa'
                        : '${items.length} ${items.length == 1 ? 'pet' : 'pets'} no mapa',
                    style: AppTextStyles.heading3().copyWith(fontSize: 15),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(18),
                          child: Text(
                            widget.emptyText,
                            style: AppTextStyles.body(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 4),
                          itemBuilder: (context, i) => _ListTilePet(
                            item: items[i],
                            selected: items[i].id == selected?.id,
                            onTap: () => _select(items[i], move: true),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: _map(items)),
              if (selected != null)
                Positioned(
                  left: 16,
                  bottom: 16,
                  width: 380,
                  child: _SelectedCard(
                    item: selected,
                    onClose: () => setState(() => _selectedId = null),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mobileBody(List<MapPetItem> items) {
    final selected = _selected;
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _map(
              items,
              radius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
        ),
        if (items.isEmpty)
          Positioned(
            left: 28,
            right: 28,
            top: 16,
            child: _MapNotice(text: widget.emptyText),
          ),
        if (selected != null)
          Positioned(
            left: 24,
            right: 24,
            bottom: 16,
            child: _SelectedCard(
              item: selected,
              onClose: () => setState(() => _selectedId = null),
            ),
          ),
      ],
    );
  }
}

/// Alternância entre os mapas de Perdidos e Encontrados.
class _KindToggle extends StatelessWidget {
  final AlertsMapKind current;

  const _KindToggle({required this.current});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        AlertsMapKind.lost,
        Icons.campaign_outlined,
        'Perdidos',
        AppRoutes.petLostMap,
      ),
      (
        AlertsMapKind.found,
        Icons.check_circle_outline,
        'Encontrados',
        AppRoutes.petFoundMap,
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: items[i].$1 == current
                  ? AppColors.primaryDark
                  : AppColors.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: items[i].$1 == current
                      ? AppColors.primaryDark
                      : AppColors.border,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: items[i].$1 == current
                    ? null
                    : () => context.go(items[i].$4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[i].$2,
                        size: 18,
                        color: items[i].$1 == current
                            ? Colors.white
                            : AppColors.primaryDark,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        items[i].$3,
                        style: AppTextStyles.label(
                          color: items[i].$1 == current
                              ? Colors.white
                              : AppColors.primaryDark,
                        ).copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ListTilePet extends StatelessWidget {
  final MapPetItem item;
  final bool selected;
  final VoidCallback onTap;

  const _ListTilePet({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox.square(
                  dimension: 52,
                  child: PetImage(url: item.imageUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTextStyles.heading3().copyWith(fontSize: 14.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.location,
                      style: AppTextStyles.bodySmall(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.my_location_rounded,
                size: 18,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetPin extends StatelessWidget {
  final String? imageUrl;
  final bool selected;

  const _PetPin({required this.imageUrl, required this.selected});

  @override
  Widget build(BuildContext context) {
    final ring = selected ? AppColors.primary : Colors.white;
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
          child: ClipOval(child: PetImage(url: imageUrl)),
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

class _SelectedCard extends StatelessWidget {
  final MapPetItem item;
  final VoidCallback onClose;

  const _SelectedCard({required this.item, required this.onClose});

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
                    child: PetImage(url: item.imageUrl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.title,
                              style: AppTextStyles.heading3(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.badge != null) ...[
                            const SizedBox(width: 8),
                            item.badge!,
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(item.subtitle, style: AppTextStyles.bodySmall()),
                      Text(
                        item.location,
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
                onPressed: item.onOpen,
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
