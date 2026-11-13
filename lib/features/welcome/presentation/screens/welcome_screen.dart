import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/orelinhas_logo.dart';

/// Tela de entrada do app, exibida antes do login.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  /// Altura útil da arte (a parte de baixo da imagem original é coberta
  /// pelo painel de ações).
  static const double _artVisibleFraction = 1010 / 1280;
  static const double _artAspect = 720 / 1280;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              // A arte ocupa a tela até perto das ações; em telas altas ela
              // é ampliada (cortando um pouco das laterais) para não sobrar vão.
              final artHeight = (constraints.maxHeight - 170).clamp(
                width / _artAspect * _artVisibleFraction,
                double.infinity,
              );

              return Stack(
                children: [
                  // Arte: logo, frase e o cachorro com o gato
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: artHeight,
                    child: Semantics(
                      label:
                          'Orelinhas. Mais que um app, uma ponte para o reencontro.',
                      image: true,
                      child: ClipRect(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          // Recorta a parte de baixo da arte original
                          child: ClipRect(
                            child: Align(
                              alignment: Alignment.topCenter,
                              heightFactor: _artVisibleFraction,
                              child: Image.asset(
                                'assets/images/welcome.webp',
                                width: 720,
                                height: 1280,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Transição suave da foto para o painel verde
                  Positioned(
                    left: 0,
                    right: 0,
                    top: artHeight * 0.72,
                    height: artHeight * 0.28 + 2,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x00143F30),
                            Color(0xB3143F30),
                            AppColors.primaryDark,
                          ],
                          stops: [0, 0.6, 1],
                        ),
                      ),
                    ),
                  ),
                  // Ações
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      // Garante contraste mesmo quando a foto chega até aqui
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00143F30), AppColors.primaryDark],
                          stops: [0, 0.35],
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          28,
                          56,
                          28,
                          24 + bottomInset,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Encontre, registre e ajude pets a voltarem para casa.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body(
                                color: Colors.white.withAlpha(225),
                              ).copyWith(fontSize: 15),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primary,
                                  minimumSize: const Size(0, 58),
                                ),
                                onPressed: () =>
                                    context.push(AppRoutes.register),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    OrelinhasLogoMark(size: 22),
                                    SizedBox(width: 10),
                                    Text(
                                      'Começar',
                                      style: TextStyle(fontSize: 17),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: () => context.push(AppRoutes.login),
                              child: const Text(
                                'Já tenho uma conta',
                                style: TextStyle(
                                  fontSize: 15,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
