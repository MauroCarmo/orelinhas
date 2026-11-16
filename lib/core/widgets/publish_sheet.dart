import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../routing/app_routes.dart';
import '../theme/app_theme.dart';

/// Abre a escolha do tipo de anúncio ("Publicar anúncio").
///
/// No celular aparece como folha deslizante de baixo para cima; no PC, como
/// uma janela no centro da tela.
Future<void> showPublishSheet(BuildContext context) {
  final isWide = MediaQuery.sizeOf(context).width >= 900;

  if (isWide) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.scaffoldLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: _PublishOptions(
              onSelected: (route) {
                Navigator.of(dialogContext).pop();
                context.push(route);
              },
              showClose: true,
            ),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.scaffoldLight,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: _PublishOptions(
          onSelected: (route) {
            Navigator.of(sheetContext).pop();
            context.push(route);
          },
        ),
      ),
    ),
  );
}

class _PublishOptions extends StatelessWidget {
  final ValueChanged<String> onSelected;
  final bool showClose;

  const _PublishOptions({required this.onSelected, this.showClose = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Publicar anúncio', style: AppTextStyles.heading2()),
            ),
            if (showClose)
              IconButton(
                tooltip: 'Fechar',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Escolha o tipo de anúncio. Leva menos de 2 minutos.',
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        _PublishOption(
          icon: Icons.campaign_outlined,
          color: AppColors.error,
          title: 'Perdi meu pet',
          subtitle: 'Publicar um alerta de desaparecimento',
          onTap: () => onSelected(AppRoutes.petLostCreate),
        ),
        const SizedBox(height: 10),
        _PublishOption(
          icon: Icons.volunteer_activism_outlined,
          color: AppColors.primary,
          title: 'Encontrei um pet',
          subtitle: 'Ajudar o animal a voltar para casa',
          onTap: () => onSelected(AppRoutes.petFoundCreate),
        ),
        const SizedBox(height: 10),
        _PublishOption(
          icon: Icons.favorite_border_rounded,
          color: AppColors.warning,
          title: 'Quero doar para adoção',
          subtitle: 'Encontrar um novo lar responsável',
          onTap: () => onSelected(AppRoutes.petAdoptionCreate),
        ),
      ],
    );
  }
}

class _PublishOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PublishOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.heading3()),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.bodySmall()),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
