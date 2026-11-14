import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
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
            content: Text('Número $phone copiado para a área de transferência!'),
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Voltar',
          onPressed: () => context.pop(),
        ),
        title: const Text('Denunciar Maus-Tratos'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        children: [
          // Banner de alerta superior
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFBEBEA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF2B8B5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFC75A47),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Maus-tratos é crime!',
                        style: AppTextStyles.heading3(color: const Color(0xFF8C1D18)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lei Federal nº 9.605/98 (com alteração da Lei Sansão nº 14.064/20). Pena de até 5 anos de reclusão para agressão contra cães e gatos.',
                        style: AppTextStyles.bodySmall(
                          color: const Color(0xFF8C1D18).withAlpha(225),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Escolha o canal conforme a urgência:',
            style: AppTextStyles.sectionHeader(),
          ),
          const SizedBox(height: 14),

          // 1. Emergência - Flagrante (190)
          _ReportCard(
            badge: 'EMERGÊNCIA / FLAGRANTE',
            badgeColor: const Color(0xFFC75A47),
            title: 'Polícia Militar (Ligue 190)',
            description:
                'Em caso de flagrante delito de agressão ou perigo iminente. Uma viatura é enviada ao local imediatamente.',
            actionLabel: 'Ligar para 190',
            actionIcon: Icons.phone_in_talk_rounded,
            actionColor: const Color(0xFFC75A47),
            onAction: () => _makeCall(context, '190'),
          ),
          const SizedBox(height: 14),

          // 2. Disque-Denúncia Anônimo (181)
          _ReportCard(
            badge: 'ANÔNIMO • 24 HORAS',
            badgeColor: const Color(0xFF3B6E53),
            title: 'Disque-Denúncia (Ligue 181)',
            description:
                'Para casos contínuos, sem flagrante urgente. Permite denúncia 100% anônima na maioria dos estados brasileiros.',
            actionLabel: 'Ligar para 181',
            actionIcon: Icons.phone_rounded,
            actionColor: const Color(0xFF3B6E53),
            onAction: () => _makeCall(context, '181'),
          ),
          const SizedBox(height: 14),

          // 3. Delegacia Eletrônica DEPA (Online)
          _ReportCard(
            badge: 'REGISTRO ONLINE (SP)',
            badgeColor: const Color(0xFF2C5E8A),
            title: 'DEPA - Delegacia Eletrônica',
            description:
                'Delegacia Eletrônica de Proteção Animal de São Paulo. Registre boletins de ocorrência pela internet com envio de fotos e vídeos.',
            actionLabel: 'Acessar DEPA Online',
            actionIcon: Icons.open_in_browser_rounded,
            actionColor: const Color(0xFF2C5E8A),
            onAction: () => _openUrl(
              context,
              'https://www.webdenuncia.sp.gov.br/depa/momento',
            ),
          ),
          const SizedBox(height: 14),

          // 4. Animais Silvestres - IBAMA
          _ReportCard(
            badge: 'ANIMAIS SILVESTRES',
            badgeColor: const Color(0xFF8A641B),
            title: 'Linha Verde IBAMA (0800 61 8080)',
            description:
                'Tráfico, cativeiro irregular, caça ilegal e crimes contra a fauna silvestre em qualquer região do Brasil.',
            actionLabel: 'Ligar 0800 61 8080',
            actionIcon: Icons.phone_forwarded_rounded,
            actionColor: const Color(0xFF8A641B),
            onAction: () => _makeCall(context, '0800618080'),
          ),
          const SizedBox(height: 14),

          // 5. Prefeituras e Órgãos Locais (156)
          _ReportCard(
            badge: 'FISCALIZAÇÃO MUNICIPAL',
            badgeColor: const Color(0xFF5A626A),
            title: 'Prefeituras e Zoonoses (Ligue 156)',
            description:
                'Muitos municípios disponibilizam o canal 156 ou Centros de Controle de Zoonoses (CCZ) para averiguação de bem-estar animal.',
            actionLabel: 'Ligar para 156',
            actionIcon: Icons.call_rounded,
            actionColor: const Color(0xFF5A626A),
            onAction: () => _makeCall(context, '156'),
          ),
          const SizedBox(height: 24),

          // Informações de utilidade pública
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
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
                      'Dicas para uma denúncia eficaz:',
                      style: AppTextStyles.heading3(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '• Anote o endereço exato com referências.\n'
                  '• Se seguro, registre fotos ou vídeos da situação.\n'
                  '• Descreva a frequência e os detalhes dos maus-tratos.\n'
                  '• Mantenha o número do protocolo da denúncia.',
                  style: AppTextStyles.body(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String badge;
  final Color badgeColor;
  final String title;
  final String description;
  final String actionLabel;
  final IconData actionIcon;
  final Color actionColor;
  final VoidCallback onAction;

  const _ReportCard({
    required this.badge,
    required this.badgeColor,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.actionIcon,
    required this.actionColor,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              badge,
              style: AppTextStyles.label(color: badgeColor).copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(title, style: AppTextStyles.heading2()),
          const SizedBox(height: 6),
          Text(
            description,
            style: AppTextStyles.body(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: actionColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: onAction,
              icon: Icon(actionIcon, size: 18),
              label: Text(
                actionLabel,
                style: AppTextStyles.button(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
