import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';

class ReportAbuseScreen extends StatelessWidget {
  const ReportAbuseScreen({super.key});

  Future<void> _makeCall(BuildContext context, String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        Clipboard.setData(ClipboardData(text: clean));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Número $phone copiado para a área de transferência!',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o link.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    final channels = <_Channel>[
      (
        badge: 'Anônimo · 24 horas',
        icon: Icons.phone_rounded,
        title: 'Disque-Denúncia',
        number: '181',
        description:
            'Para casos contínuos, sem flagrante urgente. Permite denúncia 100% anônima na maioria dos estados brasileiros.',
        actionLabel: 'Ligar para 181',
        actionIcon: Icons.phone_rounded,
        background: AppColors.accent,
        foreground: AppColors.primaryDark,
        onAction: () => _makeCall(context, '181'),
      ),
      (
        badge: 'Registro online (SP)',
        icon: Icons.computer_rounded,
        title: 'DEPA - Delegacia Eletrônica',
        number: null,
        description:
            'Delegacia Eletrônica de Proteção Animal de São Paulo. Registre boletins de ocorrência pela internet com envio de fotos e vídeos.',
        actionLabel: 'Acessar DEPA Online',
        actionIcon: Icons.open_in_new_rounded,
        background: _ReportColors.sky,
        foreground: _ReportColors.skyText,
        onAction: () =>
            _openUrl(context, 'https://www.webdenuncia.sp.gov.br/depa/momento'),
      ),
      (
        badge: 'Animais silvestres',
        icon: Icons.forest_outlined,
        title: 'Linha Verde IBAMA',
        number: '0800 61 8080',
        description:
            'Tráfico, cativeiro irregular, caça ilegal e crimes contra a fauna silvestre em qualquer região do Brasil.',
        actionLabel: 'Ligar 0800 61 8080',
        actionIcon: Icons.phone_forwarded_rounded,
        background: _ReportColors.sun,
        foreground: _ReportColors.sunText,
        onAction: () => _makeCall(context, '0800618080'),
      ),
      (
        badge: 'Fiscalização municipal',
        icon: Icons.account_balance_outlined,
        title: 'Prefeituras e Zoonoses',
        number: '156',
        description:
            'Muitos municípios disponibilizam o canal 156 ou Centros de Controle de Zoonoses (CCZ) para averiguação de bem-estar animal.',
        actionLabel: 'Ligar para 156',
        actionIcon: Icons.call_rounded,
        background: _ReportColors.grey,
        foreground: _ReportColors.greyText,
        onAction: () => _makeCall(context, '156'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Voltar',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        // No PC o título aparece grande no conteúdo
        title: isDesktop ? null : const Text('Denunciar maus-tratos'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 40 : 20,
          isDesktop ? 4 : 8,
          isDesktop ? 40 : 20,
          36,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isDesktop) ...[
                    Text(
                      'Denunciar maus-tratos',
                      style: AppTextStyles.heading1().copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Escolha o canal conforme a urgência. Sua denúncia pode salvar uma vida.',
                      style: AppTextStyles.body(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 22),
                  ],
                  const _LawStrip(),
                  SizedBox(height: isDesktop ? 18 : 14),
                  _EmergencyCard(onCall: () => _makeCall(context, '190')),
                  const SizedBox(height: 26),
                  Text(
                    isDesktop
                        ? 'Outros canais'
                        : 'Sem flagrante? Escolha um destes canais',
                    style: AppTextStyles.sectionHeader().copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  _ChannelGrid(channels: channels),
                  const SizedBox(height: 26),
                  const _Tips(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cores dos cartões de canal (mesma família da tela de início).
class _ReportColors {
  static const red = Color(0xFFC75A47);
  static const redDark = Color(0xFF9E3B2C);
  static const redSoft = Color(0xFFFDF1EE);
  static const redText = Color(0xFF8E3526);
  static const sun = Color(0xFFF4E7C9);
  static const sunText = Color(0xFF6B4A12);
  static const sky = Color(0xFFE3EEF3);
  static const skyText = Color(0xFF24506A);
  static const grey = Color(0xFFECEEEC);
  static const greyText = Color(0xFF454D49);
}

/// Aviso de que maus-tratos é crime, numa faixa discreta.
class _LawStrip extends StatelessWidget {
  const _LawStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(
        color: _ReportColors.redSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel_rounded, color: _ReportColors.red, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Maus-tratos é crime. ',
                    style: AppTextStyles.label(
                      color: _ReportColors.redText,
                    ).copyWith(fontSize: 14),
                  ),
                  const TextSpan(
                    text:
                        'Lei Federal nº 9.605/98 (com alteração da Lei Sansão nº 14.064/20). Pena de até 5 anos de reclusão para agressão contra cães e gatos.',
                  ),
                ],
              ),
              style: AppTextStyles.bodySmall(
                color: _ReportColors.redText,
              ).copyWith(fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cartão em destaque para emergência (190).
class _EmergencyCard extends StatelessWidget {
  final VoidCallback onCall;

  const _EmergencyCard({required this.onCall});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;

        final texts = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'EMERGÊNCIA · FLAGRANTE',
                style: AppTextStyles.label(
                  color: Colors.white,
                ).copyWith(fontSize: 11, letterSpacing: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Está acontecendo agora?',
              style: AppTextStyles.heading1(
                color: Colors.white,
              ).copyWith(fontSize: wide ? 26 : 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Em caso de flagrante de agressão ou perigo iminente, ligue para a Polícia Militar. Uma viatura é enviada ao local.',
              style: AppTextStyles.body(
                color: Colors.white.withAlpha(225),
              ).copyWith(fontSize: wide ? 15 : 13.5),
            ),
          ],
        );

        final button = ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _ReportColors.redDark,
            minimumSize: Size(wide ? 0 : double.infinity, 52),
            padding: const EdgeInsets.symmetric(horizontal: 26),
            shape: const StadiumBorder(),
            elevation: 0,
          ),
          onPressed: onCall,
          icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
          label: Text(
            'Ligar 190',
            style: AppTextStyles.button(
              color: _ReportColors.redDark,
            ).copyWith(fontSize: 16),
          ),
        );

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _ReportColors.red,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            children: [
              // Ícone grande decorativo
              Positioned(
                right: wide ? 200 : -16,
                top: -18,
                child: ExcludeSemantics(
                  child: Icon(
                    Icons.local_police_outlined,
                    size: 130,
                    color: Colors.white.withAlpha(28),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(wide ? 28 : 20),
                child: wide
                    ? Row(
                        children: [
                          Expanded(child: texts),
                          const SizedBox(width: 24),
                          button,
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [texts, const SizedBox(height: 18), button],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

typedef _Channel = ({
  String badge,
  IconData icon,
  String title,
  String? number,
  String description,
  String actionLabel,
  IconData actionIcon,
  Color background,
  Color foreground,
  VoidCallback onAction,
});

/// Canais em grade: 2 colunas no PC, 1 no celular.
class _ChannelGrid extends StatelessWidget {
  final List<_Channel> channels;

  const _ChannelGrid({required this.channels});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 2 : 1;
        const gap = 14.0;
        final rows = <Widget>[];
        for (var i = 0; i < channels.length; i += columns) {
          final rowItems = channels.skip(i).take(columns).toList();
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < columns; j++) ...[
                    if (j > 0) const SizedBox(width: gap),
                    Expanded(
                      child: j < rowItems.length
                          ? _ChannelCard(channel: rowItems[j])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
          if (i + columns < channels.length) {
            rows.add(const SizedBox(height: gap));
          }
        }
        return Column(children: rows);
      },
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final _Channel channel;

  const _ChannelCard({required this.channel});

  @override
  Widget build(BuildContext context) {
    final c = channel;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(c.icon, color: c.foreground, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.badge.toUpperCase(),
                      style: AppTextStyles.label(
                        color: c.foreground,
                      ).copyWith(fontSize: 10.5, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.title,
                      style: AppTextStyles.heading2().copyWith(fontSize: 17),
                    ),
                  ],
                ),
              ),
              if (c.number != null)
                Text(
                  c.number!,
                  style: AppTextStyles.heading2(
                    color: c.foreground,
                  ).copyWith(fontSize: 17),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            c.description,
            style: AppTextStyles.body(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.background,
              foregroundColor: c.foreground,
              minimumSize: const Size(double.infinity, 46),
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            onPressed: c.onAction,
            icon: Icon(c.actionIcon, size: 18),
            label: Text(
              c.actionLabel,
              style: AppTextStyles.button(color: c.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dicas para uma denúncia eficaz, em passos com ícone.
class _Tips extends StatelessWidget {
  const _Tips();

  @override
  Widget build(BuildContext context) {
    const tips = [
      (Icons.place_outlined, 'Anote o endereço exato com referências.'),
      (
        Icons.photo_camera_outlined,
        'Se for seguro, registre fotos ou vídeos da situação.',
      ),
      (
        Icons.edit_note_rounded,
        'Descreva a frequência e os detalhes dos maus-tratos.',
      ),
      (
        Icons.confirmation_number_outlined,
        'Guarde o número do protocolo da denúncia.',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final items = [
            for (final (icon, text) in tips)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 19, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        text,
                        style: AppTextStyles.body(
                          color: AppColors.textPrimary,
                        ).copyWith(fontSize: 13.5),
                      ),
                    ),
                  ),
                ],
              ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.tips_and_updates_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Dicas para uma denúncia eficaz',
                    style: AppTextStyles.heading3().copyWith(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(width: 18),
                      Expanded(child: items[i]),
                    ],
                  ],
                )
              else
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  items[i],
                ],
            ],
          );
        },
      ),
    );
  }
}
