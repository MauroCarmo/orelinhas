import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/orelinhas_logo.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/screens/register_screen.dart';

/// Etapas do painel de acesso no PC.
enum _AuthPanel { login, register, registered }

/// Tela de boas-vindas para telas largas (PC): arte à esquerda e painel com
/// login e cadastro à direita. Apenas visual — usa os mesmos formulários das
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // A arte ocupa a altura toda; a largura acompanha a proporção da
          // imagem, sem passar de metade da tela.
          final artPanelWidth =
              (constraints.maxHeight *
                      _artWidth /
                      (_artHeight * _artVisibleFraction))
                  .clamp(380.0, constraints.maxWidth * 0.5);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: artPanelWidth, child: const _ArtPanel()),
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
        // Patinhas decorativas bem suaves no fundo verde
        Positioned(
          right: -60,
          top: -40,
          child: Transform.rotate(
            angle: 0.35,
            child: OrelinhasLogoMark(
              size: 260,
              color: Colors.white.withAlpha(10),
              heartColor: AppColors.primaryDark,
            ),
          ),
        ),
        Positioned(
          left: 40,
          bottom: -50,
          child: Transform.rotate(
            angle: -0.3,
            child: OrelinhasLogoMark(
              size: 180,
              color: Colors.white.withAlpha(8),
              heartColor: AppColors.primaryDark,
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Encontre, registre e ajude pets a voltarem para casa.',
                    style: AppTextStyles.heading1(
                      color: Colors.white,
                    ).copyWith(fontSize: 28, height: 1.25),
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
                  const SizedBox(height: 28),
                  _buildCard(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
      decoration: BoxDecoration(
        color: AppColors.scaffoldLight,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
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
      ),
    );
  }

  Widget _buildLogin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelTabs(
          isLogin: true,
          onLogin: () {},
          onRegister: () => _show(_AuthPanel.register),
        ),
        const SizedBox(height: 26),
        Text('Que bom te ver de novo', style: AppTextStyles.heading1()),
        const SizedBox(height: 6),
        Text(
          'Entre para acompanhar seus alertas e ajudar pets perto de você.',
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        LoginForm(onCreateAccount: () => _show(_AuthPanel.register)),
      ],
    );
  }

  Widget _buildRegister() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelTabs(
          isLogin: false,
          onLogin: () => _show(_AuthPanel.login),
          onRegister: () {},
        ),
        const SizedBox(height: 26),
        Text('Crie sua conta', style: AppTextStyles.heading1()),
        const SizedBox(height: 6),
        Text(
          RegisterForm.subtitle,
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
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

/// Arte do Orelinhas (logo, frase e o cachorro com o gato), recortada para
/// preencher a altura da tela e esmaecendo no verde do painel ao lado.
class _ArtPanel extends StatelessWidget {
  const _ArtPanel();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          label: 'Orelinhas. Mais que um app, uma ponte para o reencontro.',
          image: true,
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _WelcomeDesktopState._artVisibleFraction,
                  child: Image.asset(
                    'assets/images/welcome.webp',
                    width: _WelcomeDesktopState._artWidth,
                    height: _WelcomeDesktopState._artHeight,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Esmaece a borda direita no verde do painel
        const Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: 90,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0x00143F30), AppColors.primaryDark],
              ),
            ),
          ),
        ),
        // Esmaece a parte de baixo
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 120,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00143F30), Color(0xCC143F30)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Seletor "Entrar / Criar conta" no topo do cartão.
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _tab('Entrar', isLogin, onLogin),
          _tab('Criar conta', !isLogin, onRegister),
        ],
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? AppColors.primary : Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: selected ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.button(
                  color: selected ? Colors.white : AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta com os principais recursos do app.
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withAlpha(220)),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.label(color: Colors.white.withAlpha(230)),
          ),
        ],
      ),
    );
  }
}
