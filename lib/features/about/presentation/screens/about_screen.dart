import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/orelinhas_logo.dart';

/// Cores suaves usadas nos blocos (mesma família da tela de início).
class _AboutColors {
  static const sun = Color(0xFFF4E7C9);
  static const sunText = Color(0xFF6B4A12);
  static const sky = Color(0xFFE3EEF3);
  static const skyText = Color(0xFF24506A);
  static const red = Color(0xFFC75A47);
  static const redSoft = Color(0xFFFDF1EE);
  static const redText = Color(0xFF8E3526);
}

/// Página institucional "Sobre o Orelinhas".
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Voltar',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.profile),
        ),
        // No PC o logo grande do topo já identifica a página
        title: isDesktop ? null : const Text('Sobre o Orelinhas'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= 860;
          const gap = SizedBox(height: 16, width: 16);

          const history = _InfoCard(
            icon: Icons.menu_book_rounded,
            iconColor: _AboutColors.red,
            iconBackground: _AboutColors.redSoft,
            title: 'Nossa história',
            children: [
              _Paragraph(
                'Inspirado no cão comunitário Orelha, o Orelinhas nasceu para '
                'reunir num só lugar a busca por animais perdidos e '
                'encontrados, a adoção responsável e a proteção animal.',
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
                'Usar a tecnologia para ajudar animais a voltarem para casa, '
                'de forma acessível e acolhedora.',
              ),
              SizedBox(height: 8),
              _Check('Proteção e bem-estar animal.'),
              _Check('Informação confiável e acessível.'),
              _Check('Impacto social por meio da tecnologia.'),
            ],
          );

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 40 : 20,
              isDesktop ? 4 : 8,
              isDesktop ? 40 : 20,
              32,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Header(),
                    const SizedBox(height: 18),
                    if (twoColumns)
                      const IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: history),
                            gap,
                            Expanded(child: mission),
                            gap,
                            Expanded(child: _WhoWeAre()),
                          ],
                        ),
                      )
                    else ...[
                      history,
                      gap,
                      mission,
                      gap,
                      const _WhoWeAre(),
                    ],
                    const SizedBox(height: 28),
                    const _SectionTitle('O que você encontra aqui'),
                    const SizedBox(height: 12),
                    const _FeatureTiles(),
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

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.sectionHeader().copyWith(fontSize: 18),
    );
  }
}

/// Recorte da arte do Orelinhas com o cachorro e o gato, inteiro.
class _DogAndCatPhoto extends StatelessWidget {
  const _DogAndCatPhoto();

  // Faixa da arte original (720x1280) que mostra só os dois animais.
  static const double _top = 500;
  static const double _bottom = 1010;
  static const double _height = 1280;
  static const double aspect = 720 / (_bottom - _top);

  @override
  Widget build(BuildContext context) {
    const visible = (_bottom - _top) / _height;
    const alignY = 2 * _top / (_height - (_bottom - _top)) - 1;
    return ExcludeSemantics(
      child: FittedBox(
        fit: BoxFit.cover,
        child: ClipRect(
          child: Align(
            alignment: const Alignment(0, alignY),
            heightFactor: visible,
            child: Image.asset(
              'assets/images/welcome.webp',
              width: 720,
              height: _height,
            ),
          ),
        ),
      ),
    );
  }
}

/// Topo: logo, frase e foto (ao lado no PC, em cima no celular).
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;

        final title = AppTextStyles.heading1(color: AppColors.primaryDark)
            .copyWith(
              fontSize: wide ? 28 : 22,
              fontWeight: FontWeight.w900,
              height: 1.2,
            );

        final text = Padding(
          padding: wide
              ? const EdgeInsets.fromLTRB(36, 30, 28, 30)
              : const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OrelinhasLogo(markSize: wide ? 34 : 28, fontSize: wide ? 28 : 23),
              SizedBox(height: wide ? 18 : 14),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Mais que um app, uma ponte para o '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'reencontro',
                          style: title.copyWith(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                style: title,
              ),
              const SizedBox(height: 10),
              Text(
                'Uma plataforma de proteção e bem-estar animal que aproxima '
                'tutores, protetores e quem encontrou um animal.',
                style: AppTextStyles.body(
                  color: AppColors.textSecondary,
                ).copyWith(fontSize: wide ? 15 : 13.5),
              ),
            ],
          ),
        );

        const photo = AspectRatio(
          aspectRatio: _DogAndCatPhoto.aspect,
          child: _DogAndCatPhoto(),
        );

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border),
          ),
          child: wide
              ? SizedBox(
                  height: 260,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: text),
                      photo,
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [photo, text],
                ),
        );
      },
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
      padding: const EdgeInsets.all(22),
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.heading2().copyWith(fontSize: 18),
                ),
              ),
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

typedef _Feature = ({
  IconData icon,
  String title,
  String desc,
  Color background,
  Color foreground,
});

/// Recursos do app em blocos coloridos (5 numa linha no PC, 2 no celular).
class _FeatureTiles extends StatelessWidget {
  const _FeatureTiles();

  static const List<_Feature> _features = [
    (
      icon: Icons.campaign_outlined,
      title: 'Pets perdidos',
      desc: 'Alertas com fotos e características',
      background: AppColors.primaryDark,
      foreground: Colors.white,
    ),
    (
      icon: Icons.check_circle_outline,
      title: 'Encontrados',
      desc: 'Registro de animais encontrados',
      background: AppColors.accent,
      foreground: AppColors.primaryDark,
    ),
    (
      icon: Icons.favorite_border_rounded,
      title: 'Adoção',
      desc: 'Divulgação de animais para adoção',
      background: _AboutColors.sun,
      foreground: _AboutColors.sunText,
    ),
    (
      icon: Icons.auto_awesome_outlined,
      title: 'IA de semelhança',
      desc: 'Compara perdidos e encontrados',
      background: _AboutColors.sky,
      foreground: _AboutColors.skyText,
    ),
    (
      icon: Icons.shield_outlined,
      title: 'Denúncia',
      desc: 'Canal rápido contra maus-tratos',
      background: _AboutColors.redSoft,
      foreground: _AboutColors.redText,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 860 ? 5 : 2;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < _features.length; i++)
              SizedBox(
                // No celular o último bloco ocupa a linha inteira
                width: columns == 2 && i == _features.length - 1
                    ? constraints.maxWidth
                    : width,
                height: columns == 5 ? 150 : 132,
                child: _FeatureTile(feature: _features[i]),
              ),
          ],
        );
      },
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final _Feature feature;

  const _FeatureTile({required this.feature});

  @override
  Widget build(BuildContext context) {
    final f = feature;
    final dark = f.background == AppColors.primaryDark;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: f.background,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: ExcludeSemantics(
              child: Icon(
                f.icon,
                size: 80,
                color: f.foreground.withAlpha(dark ? 45 : 55),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withAlpha(38)
                        : Colors.white.withAlpha(180),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(f.icon, size: 19, color: f.foreground),
                ),
                const Spacer(),
                Text(
                  f.title,
                  style: AppTextStyles.heading3(
                    color: f.foreground,
                  ).copyWith(fontSize: 15.5, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  f.desc,
                  style: AppTextStyles.bodySmall(
                    color: f.foreground.withAlpha(205),
                  ).copyWith(fontSize: 12.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Quem somos" em destaque verde-escuro com patinha decorativa.
class _WhoWeAre extends StatelessWidget {
  const _WhoWeAre();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            bottom: -30,
            child: ExcludeSemantics(
              child: OrelinhasLogoMark(
                size: 140,
                color: Colors.white.withAlpha(22),
                heartColor: AppColors.primaryDark,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Quem somos',
                      style: AppTextStyles.heading2(
                        color: Colors.white,
                      ).copyWith(fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Somos um grupo de estudantes que criou o Orelinhas como '
                  'Trabalho de Conclusão de Curso, para ajudar mais animais a '
                  'voltarem para casa.',
                  style: AppTextStyles.body(
                    color: Colors.white.withAlpha(225),
                  ).copyWith(height: 1.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
