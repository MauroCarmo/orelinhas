import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/orelinhas_logo.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/screens/register_screen.dart';

/// Etapas do painel de acesso no PC.
enum _AuthPanel { login, register, registered }

/// Tela de boas-vindas para telas largas (PC): foto em destaque à esquerda e
/// login e cadastro à direita, sobre fundo branco. Apenas visual — usa os mesmos formulários das
/// telas de login e cadastro do celular.
class WelcomeDesktop extends StatefulWidget {
  const WelcomeDesktop({super.key});

  @override
  State<WelcomeDesktop> createState() => _WelcomeDesktopState();
}

class _WelcomeDesktopState extends State<WelcomeDesktop> {
  /// Proporções da arte original (720x1280) e da parte útil dela (a parte de
  /// baixo é só fundo desfocado).
  static const double _artWidth = 720;
  static const double _artHeight = 1280;
  static const double _artVisibleFraction = 1010 / 1280;

  _AuthPanel _panel = _AuthPanel.login;

  void _show(_AuthPanel panel) => setState(() => _panel = panel);

  static const double _margin = 22;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // A foto ocupa a altura toda (com margem); a largura acompanha a
          // proporção da arte, sem passar de 52% da tela.
          final photoHeight = constraints.maxHeight - 2 * _margin;
          final photoWidth =
              (photoHeight * _artWidth / (_artHeight * _artVisibleFraction))
                  .clamp(380.0, constraints.maxWidth * 0.52);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(_margin),
                child: SizedBox(width: photoWidth, child: const _PhotoPanel()),
              ),
              Expanded(child: _buildAuthSide()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAuthSide() {
    return Stack(
      children: [
        // Patinhas verdes decorativas
        const _Paw(right: -40, top: -30, size: 210, angle: 0.35, alpha: 22),
        const _Paw(right: 90, top: 190, size: 46, angle: -0.25, alpha: 40),
        const _Paw(left: 30, bottom: -40, size: 160, angle: -0.3, alpha: 18),
        const _Paw(right: 60, bottom: 70, size: 70, angle: 0.2, alpha: 30),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: OrelinhasLogo(markSize: 30, fontSize: 24),
                    ),
                    const SizedBox(height: 32),
                    if (_panel != _AuthPanel.registered) ...[
                      _PanelTabs(
                        isLogin: _panel == _AuthPanel.login,
                        onLogin: () => _show(_AuthPanel.login),
                        onRegister: () => _show(_AuthPanel.register),
                      ),
                      const SizedBox(height: 30),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: KeyedSubtree(
                        key: ValueKey(_panel),
                        child: switch (_panel) {
                          _AuthPanel.login => _buildLogin(),
                          _AuthPanel.register => _buildRegister(),
                          _AuthPanel.registered => _buildRegistered(),
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _title(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.heading1().copyWith(fontSize: 30, height: 1.15),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: AppTextStyles.body(
            color: AppColors.textSecondary,
          ).copyWith(fontSize: 15),
        ),
        const SizedBox(height: 26),
      ],
    );
  }

  Widget _buildLogin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          'Que bom te ver de novo',
          'Entre para acompanhar seus alertas e ajudar pets perto de você.',
        ),
        LoginForm(
          googleFirst: true,
          onCreateAccount: () => _show(_AuthPanel.register),
        ),
      ],
    );
  }

  Widget _buildRegister() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('Crie sua conta', RegisterForm.subtitle),
        RegisterForm(
          wide: true,
          onRegistered: () => _show(_AuthPanel.registered),
          onLogin: () => _show(_AuthPanel.login),
        ),
      ],
    );
  }

  Widget _buildRegistered() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_unread_outlined,
            size: 46,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Confirme seu e-mail',
          style: AppTextStyles.heading1(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          RegisterForm.confirmationMessage,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _show(_AuthPanel.login),
            child: const Text('Ir para o login'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Foto do Orelinhas em destaque: cartão arredondado com uma moldura verde
/// deslocada atrás e a chamada do app sobre a parte de baixo da imagem.
class _PhotoPanel extends StatelessWidget {
  const _PhotoPanel();

  static const double _radius = 34;
  static const double _offset = 14;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Moldura verde deslocada (detalhe)
        const Positioned(
          left: _offset,
          top: _offset,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.all(Radius.circular(_radius)),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          right: _offset,
          bottom: _offset,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_radius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Semantics(
                    label:
                        'Orelinhas. Mais que um app, uma ponte para o reencontro.',
                    image: true,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.topCenter,
                          heightFactor:
                              _WelcomeDesktopState._artVisibleFraction,
                          child: Image.asset(
                            'assets/images/welcome.webp',
                            width: _WelcomeDesktopState._artWidth,
                            height: _WelcomeDesktopState._artHeight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Chamada sobre a foto
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00143F30), Color(0xE6143F30)],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 70, 32, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Encontre, registre e ajude pets a voltarem para casa.',
                              style: AppTextStyles.heading1(
                                color: Colors.white,
                              ).copyWith(fontSize: 22, height: 1.25),
                            ),
                            const SizedBox(height: 14),
                            const Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _FeatureChip(
                                  icon: Icons.search_rounded,
                                  label: 'Pets perdidos',
                                ),
                                _FeatureChip(
                                  icon: Icons.pets_rounded,
                                  label: 'Pets encontrados',
                                ),
                                _FeatureChip(
                                  icon: Icons.favorite_border_rounded,
                                  label: 'Adoção',
                                ),
                              ],
                            ),
                          ],
                        ),
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
  }
}

/// Patinha verde decorativa no fundo branco.
class _Paw extends StatelessWidget {
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double size;
  final double angle;
  final int alpha;

  const _Paw({
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.size,
    required this.angle,
    required this.alpha,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: ExcludeSemantics(
        child: Transform.rotate(
          angle: angle,
          child: OrelinhasLogoMark(
            size: size,
            color: AppColors.primary.withAlpha(alpha),
            heartColor: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Abas "Entrar / Criar conta" com sublinhado verde.
class _PanelTabs extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  const _PanelTabs({
    required this.isLogin,
    required this.onLogin,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 2)),
      ),
      child: Row(
        children: [
          _tab('Entrar', isLogin, onLogin),
          const SizedBox(width: 28),
          _tab('Criar conta', !isLogin, onRegister),
        ],
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          transform: Matrix4.translationValues(0, 2, 0),
          child: Text(
            label,
            style: AppTextStyles.heading2(
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ).copyWith(fontSize: 17),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta com os principais recursos do app (sobre a foto).
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.label(color: Colors.white)),
        ],
      ),
    );
  }
}
