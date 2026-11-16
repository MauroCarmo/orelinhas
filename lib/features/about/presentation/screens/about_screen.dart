import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/orelinhas_logo.dart';

/// Página institucional "Sobre o Orelinhas".
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Voltar',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.profile),
        ),
        title: const Text('Sobre o Orelinhas'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= 860;

          const history = _InfoCard(
            icon: Icons.menu_book_rounded,
            iconColor: Color(0xFFC75A47),
            iconBackground: Color(0xFFFDECEC),
            title: 'Nossa história',
            children: [
              _Paragraph(
                'O Orelinhas nasceu da necessidade de reunir, em um só lugar, '
                'informações sobre proteção animal, cuidados, adoção '
                'responsável e a busca por animais perdidos e encontrados.',
              ),
              SizedBox(height: 10),
              _Paragraph(
                'Nossa inspiração vem do caso do cão comunitário Orelha, que '
                'despertou a atenção da sociedade para a importância da '
                'proteção animal e da responsabilidade coletiva.',
              ),
            ],
          );

          const mission = _InfoCard(
            icon: Icons.flag_rounded,
            iconColor: AppColors.primary,
            iconBackground: AppColors.primarySoft,
            title: 'Nossa missão',
            children: [
              _Paragraph(
                'Usar a tecnologia para facilitar a comunicação e ajudar '
                'animais a reencontrarem seus tutores, de forma acessível, '
                'organizada e acolhedora.',
              ),
              SizedBox(height: 10),
              _Check('Incentivar a proteção e o bem-estar animal.'),
              _Check('Facilitar o acesso a informações confiáveis.'),
              _Check('Incentivar a adoção responsável.'),
              _Check('Ajudar a identificar e reencontrar animais perdidos.'),
              _Check('Prevenir e conscientizar sobre os maus-tratos.'),
              _Check('Gerar impacto social por meio da tecnologia.'),
            ],
          );

          const features = _InfoCard(
            icon: Icons.pets_rounded,
            iconColor: AppColors.primary,
            iconBackground: AppColors.primarySoft,
            title: 'O que você encontra aqui',
            children: [
              _Check('Alertas de pets perdidos, com fotos e características.'),
              _Check('Registro de animais encontrados.'),
              _Check('Divulgação de animais para adoção.'),
              _Check(
                'Busca de semelhanças entre perdidos e encontrados com '
                'inteligência artificial.',
              ),
              _Check('Canal rápido para denunciar maus-tratos.'),
            ],
          );

          const ods = _InfoCard(
            icon: Icons.public_rounded,
            iconColor: Color(0xFFD9822B),
            iconBackground: Color(0xFFFDF0DF),
            title: 'Objetivos de Desenvolvimento Sustentável',
            children: [
              _OdsItem(
                number: '15',
                title: 'Vida Terrestre',
                description:
                    'Proteção e bem-estar dos animais que convivem conosco.',
              ),
              SizedBox(height: 12),
              _OdsItem(
                number: '4',
                title: 'Educação de Qualidade',
                description:
                    'Informação acessível sobre cuidados, adoção responsável '
                    'e prevenção de maus-tratos.',
              ),
            ],
          );

          const gap = SizedBox(height: 16, width: 16);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Header(),
                    gap,
                    if (twoColumns) ...[
                      const IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: history),
                            gap,
                            Expanded(child: mission),
                          ],
                        ),
                      ),
                      gap,
                      const IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: features),
                            gap,
                            Expanded(child: ods),
                          ],
                        ),
                      ),
                    ] else ...[
                      history,
                      gap,
                      mission,
                      gap,
                      features,
                      gap,
                      ods,
                    ],
                    gap,
                    const _WhoWeAre(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OrelinhasLogo(
            markSize: 40,
            fontSize: 32,
            color: Colors.white,
            heartColor: AppColors.primaryDark,
          ),
          const SizedBox(height: 18),
          Text(
            'Mais que um app, uma ponte para o reencontro.',
            style: AppTextStyles.heading2(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Uma plataforma de proteção e bem-estar animal que aproxima '
            'tutores, protetores e quem encontrou um animal.',
            style: AppTextStyles.body(color: Colors.white.withAlpha(225)),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final List<Widget> children;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: AppTextStyles.heading2())),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  final String text;

  const _Paragraph(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.body(
        color: AppColors.textSecondary,
      ).copyWith(height: 1.55),
    );
  }
}

class _Check extends StatelessWidget {
  final String text;

  const _Check(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTextStyles.body())),
        ],
      ),
    );
  }
}

class _OdsItem extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _OdsItem({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFD9822B);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFDF0DF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'ODS\n$number',
            textAlign: TextAlign.center,
            style: AppTextStyles.label(
              color: orange,
            ).copyWith(fontWeight: FontWeight.w900, height: 1.1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.heading3()),
              const SizedBox(height: 2),
              Text(description, style: AppTextStyles.bodySmall()),
            ],
          ),
        ),
      ],
    );
  }
}

class _WhoWeAre extends StatelessWidget {
  const _WhoWeAre();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.groups_rounded,
                color: AppColors.primaryDark,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text('Quem somos', style: AppTextStyles.heading2()),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Somos um grupo de estudantes que desenvolveu o Orelinhas como '
            'Trabalho de Conclusão de Curso, acreditando que a tecnologia pode '
            'gerar impacto social real e ajudar cada vez mais animais a '
            'voltarem para casa.',
            style: AppTextStyles.body().copyWith(height: 1.55),
          ),
        ],
      ),
    );
  }
}
