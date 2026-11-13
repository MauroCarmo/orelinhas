import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/pet_lost_entity.dart';

/// Rótulos e ícones de exibição para o tipo do pet.
extension PetTypeDisplay on PetType {
  String get label => switch (this) {
    PetType.dog => 'Cachorro',
    PetType.cat => 'Gato',
    PetType.other => 'Outro',
  };

  IconData get icon => switch (this) {
    PetType.dog => Icons.pets_rounded,
    PetType.cat => Icons.cruelty_free_outlined,
    PetType.other => Icons.flutter_dash,
  };
}

/// Formatação compartilhada dos dados de um alerta.
class PetFormat {
  PetFormat._();

  static String date(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static String phone(String rawPhone) {
    if (rawPhone.length >= 10) {
      final ddd = rawPhone.substring(0, 2);
      if (rawPhone.length == 11) {
        return '($ddd) ${rawPhone.substring(2, 7)}-${rawPhone.substring(7)}';
      }
      return '($ddd) ${rawPhone.substring(2, 6)}-${rawPhone.substring(6)}';
    }
    return rawPhone;
  }

  /// Linha curta: "Cachorro • Golden Retriever".
  static String subtitle(PetLostAlertEntity alert) {
    final parts = <String>[alert.petType.label];
    if (alert.breed != null && alert.breed!.trim().isNotEmpty) {
      parts.add(alert.breed!.trim());
    } else if (alert.age != null && alert.age!.trim().isNotEmpty) {
      parts.add(alert.age!.trim());
    }
    return parts.join(' • ');
  }
}

/// Selo "Perdido" (vermelho) ou "Encontrado" (verde).
class PetStatusBadge extends StatelessWidget {
  final AlertStatus status;
  final bool solid;

  const PetStatusBadge({super.key, required this.status, this.solid = true});

  @override
  Widget build(BuildContext context) {
    final resolved = status == AlertStatus.resolved;
    final color = resolved ? AppColors.success : AppColors.error;
    final soft = resolved ? AppColors.successSoft : AppColors.errorSoft;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? color : soft,
        borderRadius: BorderRadius.circular(20),
        border: solid ? null : Border.all(color: color.withAlpha(70)),
      ),
      child: Text(
        resolved ? 'Encontrado' : 'Perdido',
        style: AppTextStyles.bodySmall(
          color: solid ? Colors.white : color,
        ).copyWith(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Foto do pet com placeholder amigável quando não houver imagem.
class PetImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;

  const PetImage({super.key, required this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppColors.primarySoft,
      alignment: Alignment.center,
      child: const Icon(Icons.pets_rounded, size: 40, color: AppColors.primary),
    );

    if (url == null || url!.isEmpty) return placeholder;

    return Image.network(
      url!,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => placeholder,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : Container(color: AppColors.primarySoft),
    );
  }
}

/// Card de pet em grade (foto, selo, nome, tipo e local).
class PetGridCard extends StatelessWidget {
  final PetLostAlertEntity alert;
  final VoidCallback onTap;

  const PetGridCard({super.key, required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'pet-${alert.id}',
                    child: PetImage(url: alert.imageUrl),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: PetStatusBadge(status: alert.status),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.petName,
                    style: AppTextStyles.heading3(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    PetFormat.subtitle(alert),
                    style: AppTextStyles.bodySmall(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          alert.lastLocation,
                          style: AppTextStyles.bodySmall().copyWith(
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado vazio ou de erro com ícone, mensagem e ação opcional.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color color;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: color.withAlpha(28),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: AppTextStyles.heading3(),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                style: AppTextStyles.body(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
