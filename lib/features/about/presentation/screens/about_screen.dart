import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/orelinhas_logo.dart';

/// Página institucional "Sobre o Orelinhas".
///
/// Visual próprio, diferente da tela de início: cabeçalho verde centralizado,
/// história do Orelha com foto, valores em colunas e recursos em lista.
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
        title: isDesktop ? null : const Text('Sobre o Orelinhas'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 40 : 20,
          isDesktop ? 4 : 8,
          isDesktop ? 40 : 20,
          36,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Hero(),
                SizedBox(height: 36),
                _Story(),
                SizedBox(height: 40),
                _Values(),
                SizedBox(height: 40),
                _Features(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Título de seção com um pequeno rótulo em cima.
class _SectionHeading extends StatelessWidget {
  final String kicker;
  final String title;
  final bool center;

  const _SectionHeading({
    required this.kicker,
    required this.title,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          kicker.toUpperCase(),
          style: AppTextStyles.label(
            color: AppColors.primary,
          ).copyWith(fontSize: 11.5, letterSpacing: 1),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: AppTextStyles.heading1().copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

/// Cabeçalho verde-escuro, centralizado, com patinhas decorativas.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Stack(
            children: [
              Positioned(
                left: -30,
                bottom: -40,
                child: _paw(wide ? 170 : 120, -0.3),
              ),
              Positioned(
                right: -20,
                top: -30,
                child: _paw(wide ? 150 : 100, 0.35),
              ),
              if (wide)
                Positioned(right: 120, bottom: 24, child: _paw(46, 0.2)),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 60 : 22,
                  vertical: wide ? 52 : 34,
                ),
                child: Column(
                  children: [
                    OrelinhasLogo(
                      markSize: wide ? 46 : 36,
                      fontSize: wide ? 38 : 30,
                      color: Colors.white,
                      heartColor: AppColors.primaryDark,
                    ),
                    SizedBox(height: wide ? 20 : 16),
                    Text(
                      'Mais que um app, uma ponte para o reencontro.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.heading1(color: Colors.white)
                          .copyWith(
                            fontSize: wide ? 26 : 20,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(
                        'Uma plataforma de proteção e bem-estar animal que '
                        'aproxima tutores, protetores e quem encontrou um animal.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(
                          color: Colors.white.withAlpha(215),
                        ).copyWith(fontSize: wide ? 15.5 : 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _paw(double size, double angle) => ExcludeSemantics(
    child: Transform.rotate(
      angle: angle,
      child: OrelinhasLogoMark(
        size: size,
        color: Colors.white.withAlpha(18),
        heartColor: AppColors.primaryDark,
      ),
    ),
  );
}

/// Foto do Orelha, inteira, com legenda.
class _OrelhaPhoto extends StatelessWidget {
  const _OrelhaPhoto();

  /// Proporção da foto (768x568).
  static const double aspect = 768 / 568;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: aspect,
            child: Image.asset(
              'assets/images/orelha.webp',
              fit: BoxFit.cover,
              semanticLabel:
                  'Orelha, cão comunitário da Praia Brava, em Florianópolis',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Orelha, cão comunitário da Praia Brava, Florianópolis (SC)',
          style: AppTextStyles.bodySmall().copyWith(fontSize: 12.5),
        ),
      ],
    );
  }
}

/// Nossa história: texto com citação e a foto ao lado (PC) ou embaixo.
class _Story extends StatelessWidget {
  const _Story();

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _SectionHeading(
          kicker: 'Nossa história',
          title: 'Tudo começou com o Orelha',
        ),
        const SizedBox(height: 14),
        Text(
          'Inspirado no cão comunitário Orelha, o Orelinhas nasceu para reunir '
          'num só lugar a busca por animais perdidos e encontrados, a adoção '
          'responsável e a proteção animal.',
          style: AppTextStyles.body(
            color: AppColors.textSecondary,
          ).copyWith(fontSize: 15, height: 1.6),
        ),
        const SizedBox(height: 18),
        // Citação com a missão
        Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.primary, width: 3),
            ),
          ),
          child: Text(
            'Nossa missão: usar a tecnologia para ajudar animais a voltarem '
            'para casa, de forma acessível e acolhedora.',
            style: AppTextStyles.heading3(
              color: AppColors.primaryDark,
            ).copyWith(fontSize: 16, height: 1.45, fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 11, child: text),
              const SizedBox(width: 40),
              const Expanded(flex: 10, child: _OrelhaPhoto()),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [text, const SizedBox(height: 20), const _OrelhaPhoto()],
        );
      },
    );
  }
}

/// Nossos valores em três colunas com ícone redondo.
class _Values extends StatelessWidget {
  const _Values();

  static const _items = [
    (
      Icons.volunteer_activism_outlined,
      'Proteção animal',
      'Bem-estar e cuidado com os animais que convivem conosco.',
    ),
    (
      Icons.verified_outlined,
      'Informação confiável',
      'Conteúdo acessível e organizado para quem quer ajudar.',
    ),
    (
      Icons.diversity_3_outlined,
      'Impacto social',
      'Tecnologia a serviço da comunidade e da responsabilidade coletiva.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final cards = [
          for (final (icon, title, text) in _items)
            Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 30),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading3().copyWith(fontSize: 16.5),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(color: AppColors.textSecondary),
                ),
              ],
            ),
        ];

        return Column(
          children: [
            const _SectionHeading(
              kicker: 'No que acreditamos',
              title: 'Nossos valores',
              center: true,
            ),
            const SizedBox(height: 24),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 32),
                    Expanded(child: cards[i]),
                  ],
                ],
              )
            else
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 24),
                cards[i],
              ],
          ],
        );
      },
    );
  }
}

/// Recursos do app em lista com ícones (2 colunas no PC).
class _Features extends StatelessWidget {
  const _Features();

  static const _items = [
    (
      Icons.campaign_outlined,
      'Alertas de pets perdidos, com fotos e características.',
    ),
    (Icons.check_circle_outline, 'Registro de animais encontrados.'),
    (Icons.favorite_border_rounded, 'Divulgação de animais para adoção.'),
    (
      Icons.auto_awesome_outlined,
      'Busca de semelhanças entre perdidos e encontrados com inteligência '
          'artificial.',
    ),
    (Icons.shield_outlined, 'Canal rápido para denunciar maus-tratos.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 640 ? 2 : 1;
          const spacing = 28.0;
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeading(
                kicker: 'O app',
                title: 'O que você encontra aqui',
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: spacing,
                runSpacing: 18,
                children: [
                  for (final (icon, text) in _items)
                    SizedBox(
                      width: width,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, color: AppColors.primary, size: 24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                text,
                                style: AppTextStyles.body().copyWith(
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
