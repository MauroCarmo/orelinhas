import 'package:flutter/material.dart';
import '../../domain/models/bounding_box_entity.dart';

/// Modal interativo que permite ao usuário selecionar qual animal na foto corresponde ao pet cadastrado,
/// caso o detector YOLOv8n tenha encontrado múltiplos animais.
class BoundingBoxSelectorDialog extends StatefulWidget {
  final String imageUrl;
  final List<BoundingBoxEntity> detectedAnimals;
  final BoundingBoxEntity? initialSelection;

  const BoundingBoxSelectorDialog({
    super.key,
    required this.imageUrl,
    required this.detectedAnimals,
    this.initialSelection,
  });

  static Future<BoundingBoxEntity?> show(
    BuildContext context, {
    required String imageUrl,
    required List<BoundingBoxEntity> detectedAnimals,
    BoundingBoxEntity? initialSelection,
  }) {
    return showDialog<BoundingBoxEntity>(
      context: context,
      builder: (context) => BoundingBoxSelectorDialog(
        imageUrl: imageUrl,
        detectedAnimals: detectedAnimals,
        initialSelection: initialSelection,
      ),
    );
  }

  @override
  State<BoundingBoxSelectorDialog> createState() =>
      _BoundingBoxSelectorDialogState();
}

class _BoundingBoxSelectorDialogState extends State<BoundingBoxSelectorDialog> {
  BoundingBoxEntity? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection ??
        (widget.detectedAnimals.isNotEmpty ? widget.detectedAnimals.first : null);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.pets, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Múltiplos animais detectados',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Identificamos mais de um animal nesta foto. Toque no animal correto para focar o reconhecimento visual:',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              // Imagem com caixas de detecção sobrepostas
              LayoutBuilder(
                builder: (context, constraints) {
                  final imgWidth = constraints.maxWidth;
                  final imgHeight = imgWidth * 0.75;

                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.imageUrl,
                          width: imgWidth,
                          height: imgHeight,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: imgWidth,
                            height: imgHeight,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.broken_image, size: 48),
                          ),
                        ),
                      ),
                      // Caixas delimitadoras do YOLO
                      ...widget.detectedAnimals.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final box = entry.value;
                        final isSelected = box == _selected;

                        final left = box.xMin * imgWidth;
                        final top = box.yMin * imgHeight;
                        final boxW = box.width * imgWidth;
                        final boxH = box.height * imgHeight;

                        return Positioned(
                          left: left,
                          top: top,
                          width: boxW,
                          height: boxH,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selected = box;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected ? Colors.green : Colors.yellow,
                                  width: isSelected ? 3 : 2,
                                ),
                                color: isSelected
                                    ? Colors.green.withOpacity(0.25)
                                    : Colors.yellow.withOpacity(0.15),
                              ),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  color: isSelected ? Colors.green : Colors.yellow.shade800,
                                  child: Text(
                                    'Animal #${idx + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              // Opções em lista
              ...widget.detectedAnimals.asMap().entries.map((entry) {
                final idx = entry.key;
                final box = entry.value;

                return RadioListTile<BoundingBoxEntity>(
                  value: box,
                  groupValue: _selected,
                  title: Text('Animal #${idx + 1} (${box.label})'),
                  subtitle: Text(
                    'Confiança: ${(box.confidence * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                  activeColor: Colors.green,
                  onChanged: (val) {
                    setState(() {
                      _selected = val;
                    });
                  },
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _selected != null
              ? () => Navigator.of(context).pop(_selected)
              : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Confirmar Seleção', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
