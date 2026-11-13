import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/pet_match_candidate_entity.dart';

/// Badge visual para indicar o score e o nível de similaridade de uma correspondência.
class SimilarityBadge extends StatelessWidget {
  final double score;
  final MatchMethod method;

  const SimilarityBadge({
    super.key,
    required this.score,
    this.method = MatchMethod.visual,
  });

  @override
  Widget build(BuildContext context) {
    final (Color color, Color bgColor) = score >= 0.92
        ? (AppColors.success, AppColors.successSoft)
        : score >= 0.88
        ? (AppColors.primary, AppColors.primarySoft)
        : (AppColors.textSecondary, AppColors.surfaceLight);

    final percentage = (score * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            method == MatchMethod.visual
                ? Icons.auto_awesome_rounded
                : Icons.tune_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$percentage% similaridade',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
