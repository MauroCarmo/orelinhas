import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/orelinhas_logo.dart';
import '../../../welcome/presentation/widgets/welcome_desktop.dart';

/// Estrutura visual comum às telas de autenticação.
///
/// No celular: tela simples com botão de voltar. No PC: mesma composição da
/// tela de boas-vindas (foto à esquerda e conteúdo à direita, fundo branco com
/// patinhas).
class AuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showLogo;

  /// Ícone de destaque acima do título (opcional).
  final IconData? icon;

  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showLogo = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    void goBack() =>
        context.canPop() ? context.pop() : context.go(AppRoutes.welcome);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLogo || isDesktop) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: OrelinhasLogo(markSize: 30, fontSize: 24),
          ),
          SizedBox(height: isDesktop ? 36 : 28),
        ],
        if (icon != null) ...[
          Align(alignment: Alignment.centerLeft, child: _IconBadge(icon!)),
          const SizedBox(height: 20),
        ],
        Text(
          title,
          style: isDesktop
              ? AppTextStyles.heading1().copyWith(fontSize: 30, height: 1.15)
              : AppTextStyles.heading1(),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 28),
        ...children,
      ],
    );

    if (isDesktop) {
      return _AuthSplit(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: goBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                label: const Text('Voltar'),
              ),
            ),
            const SizedBox(height: 20),
            content,
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Voltar',
          onPressed: goBack,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Mensagem de confirmação (e-mail enviado, cadastro concluído etc.).
class AuthConfirmation extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const AuthConfirmation({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final align = isDesktop
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center;
    final textAlign = isDesktop ? TextAlign.start : TextAlign.center;

    final content = Column(
      crossAxisAlignment: align,
      children: [
        if (isDesktop) ...[
          const OrelinhasLogo(markSize: 30, fontSize: 24),
          const SizedBox(height: 36),
        ],
        _IconBadge(icon, large: !isDesktop),
        const SizedBox(height: 24),
        Text(
          title,
          style: isDesktop
              ? AppTextStyles.heading1().copyWith(fontSize: 30, height: 1.15)
              : AppTextStyles.heading1(),
          textAlign: textAlign,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: textAlign,
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
        ),
      ],
    );

    if (isDesktop) return _AuthSplit(child: content);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Composição do PC: foto do Orelinhas à esquerda e o conteúdo à direita.
class _AuthSplit extends StatelessWidget {
  final Widget child;

  const _AuthSplit({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(
            child: Stack(
              children: [
                DecorPaw(left: 28, top: 90, size: 54, angle: -0.35, alpha: 32),
                DecorPaw(
                  left: -30,
                  bottom: 120,
                  size: 130,
                  angle: 0.25,
                  alpha: 18,
                ),
                Padding(
                  padding: EdgeInsets.all(22),
                  child: WelcomePhotoPanel(),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                const DecorPaw(
                  right: -40,
                  top: -30,
                  size: 210,
                  angle: 0.35,
                  alpha: 22,
                ),
                const DecorPaw(
                  right: 90,
                  top: 190,
                  size: 46,
                  angle: -0.25,
                  alpha: 40,
                ),
                const DecorPaw(
                  left: 30,
                  bottom: -40,
                  size: 160,
                  angle: -0.3,
                  alpha: 18,
                ),
                const DecorPaw(
                  right: 60,
                  bottom: 70,
                  size: 70,
                  angle: 0.2,
                  alpha: 30,
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 56,
                      vertical: 40,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ícone em círculo verde-claro, usado no topo das telas de acesso.
class _IconBadge extends StatelessWidget {
  final IconData icon;
  final bool large;

  const _IconBadge(this.icon, {this.large = false});

  @override
  Widget build(BuildContext context) {
    final size = large ? 104.0 : 72.0;
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: size * 0.48, color: AppColors.primary),
    );
  }
}

/// Indicador de carregamento para dentro de botões.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 22,
      width: 22,
      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
    );
  }
}
