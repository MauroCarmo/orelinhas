import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/analysis_status.dart';
import '../../domain/models/bounding_box_entity.dart';
import '../../domain/models/pet_image_analysis_entity.dart';
import 'bounding_box_selector_dialog.dart';

/// Widget para gerenciar a exibição e análise de múltiplas imagens (3 a 5 fotos)
/// de um pet, com badges de status discretos e não-bloqueantes.
class PetMultiImageAnalyzerWidget extends ConsumerWidget {
  final List<String> imageUrls;
  final List<PetImageAnalysisEntity> imageAnalyses;
  final Function(String imageUrl, BoundingBoxEntity selectedBox)? onAnimalSelected;
  final VoidCallback? onAddImagePressed;
  final Function(int index)? onRemoveImagePressed;
  final bool isReadOnly;

  const PetMultiImageAnalyzerWidget({
    super.key,
    required this.imageUrls,
    this.imageAnalyses = const [],
    this.onAnimalSelected,
    this.onAddImagePressed,
    this.onRemoveImagePressed,
    this.isReadOnly = false,
  });

  PetImageAnalysisEntity? _getAnalysisFor(String url) {
    try {
      return imageAnalyses.firstWhere((a) => a.imageUrl == url);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Fotos do Pet (${imageUrls.length}/5)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            if (!isReadOnly && imageUrls.length < 5)
              TextButton.icon(
                icon: const Icon(Icons.add_photo_alternate, size: 18),
                label: const Text('Adicionar Foto'),
                onPressed: onAddImagePressed,
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Envie de 3 a 5 fotos de ângulos diferentes para facilitar o reconhecimento visual.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        if (imageUrls.isEmpty)
          Container(
            height: 110,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 36, color: Colors.grey.shade500),
                  const SizedBox(height: 6),
                  Text(
                    'Nenhuma foto adicionada ainda',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final url = imageUrls[index];
                final analysis = _getAnalysisFor(url);
                return _buildImageCard(context, url, analysis, index);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildImageCard(
    BuildContext context,
    String url,
    PetImageAnalysisEntity? analysis,
    int index,
  ) {
    final status = analysis?.status ?? AnalysisStatus.pending;

    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Imagem principal
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  child: Image.network(
                    url,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
                if (!isReadOnly && onRemoveImagePressed != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => onRemoveImagePressed!(index),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                if (analysis != null && analysis.hasMultipleAnimals)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () async {
                        final chosen = await BoundingBoxSelectorDialog.show(
                          context,
                          imageUrl: url,
                          detectedAnimals: analysis.detectedAnimals,
                          initialSelection: analysis.selectedAnimal,
                        );
                        if (chosen != null && onAnimalSelected != null) {
                          onAnimalSelected!(url, chosen);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade800,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.crop, size: 10, color: Colors.white),
                            SizedBox(width: 2),
                            Text(
                              'Focar pet',
                              style: TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Status badge discreto
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: _buildStatusBadge(status),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(AnalysisStatus status) {
    Color bg;
    Color fg;
    IconData icon;
    String text;

    switch (status) {
      case AnalysisStatus.processed:
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        icon = Icons.check_circle;
        text = 'Analisada';
        break;
      case AnalysisStatus.processing:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        icon = Icons.hourglass_top;
        text = 'Analisando...';
        break;
      case AnalysisStatus.notDetected:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        icon = Icons.info_outline;
        text = 'Não detectado';
        break;
      case AnalysisStatus.error:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        icon = Icons.warning_amber;
        text = 'Sem análise';
        break;
      case AnalysisStatus.pending:
        bg = Colors.grey.shade50;
        fg = Colors.grey.shade600;
        icon = Icons.schedule;
        text = 'Pendente';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
