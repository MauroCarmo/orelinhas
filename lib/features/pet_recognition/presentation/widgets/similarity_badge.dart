import 'package:flutter/material.dart';
import '../../domain/models/pet_match_candidate_entity.dart';

/// Badge visual elegante para indicar o score e o nível de similaridade de uma correspondência.
class SimilarityBadge extends StatelessWidget {
  final double score;
  final MatchMethod method;

  const SimilarityBadge({
    super.key,
    required this.score,
    this.method = MatchMethod.visual,
  });

  Color _getColor(BuildContext context) {
    if (score >= 0.82) {
      return Colors.green.shade700;
    } else if (score >= 0.70) {
      return Colors.orange.shade800;
    } else {
      return Colors.blueGrey.shade700;
    }
  }

  Color _getBackgroundColor(BuildContext context) {
    if (score >= 0.82) {
      return Colors.green.shade50;
    } else if (score >= 0.70) {
      return Colors.orange.shade50;
    } else {
      return Colors.blueGrey.shade50;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);
    final bgColor = _getBackgroundColor(context);
    final percentage = (score * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            method == MatchMethod.visual ? Icons.auto_awesome : Icons.tune,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$percentage% similaridade',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
