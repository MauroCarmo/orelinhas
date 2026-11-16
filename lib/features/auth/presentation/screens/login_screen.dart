import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/validation/sanitizers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_button_styles.dart';
import '../../../../core/theme/widgets/app_input_decoration.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_layout.dart';

/// Tela de login (usada no celular e quando a rota /login é aberta direto).
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthLayout(
      title: 'Que bom te ver de novo',
      subtitle:
          'Entre para acompanhar seus alertas e ajudar pets perto de você.',
      children: [LoginForm()],
    );
  }
}

/// Campos e ações do login. Reaproveitado na tela de boas-vindas do PC.
class LoginForm extends ConsumerStatefulWidget {
  /// Quando informado, "Criar conta" chama este callback em vez de navegar
  /// para a rota de cadastro (usado no painel do PC).
  final VoidCallback? onCreateAccount;

  /// Mostra "Entrar com Google" antes dos campos de e-mail e senha.
  final bool googleFirst;

  const LoginForm({super.key, this.onCreateAccount, this.googleFirst = false});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    final email = AppSanitizers.normalizeEmail(_emailController.text);
    final password =
        _passwordController.text; // Senhas não sofrem normalização destrutiva

    final authCtrl = ref.read(authControllerProvider.notifier);
    await authCtrl.signIn(email, password);

    if (!mounted) return;

    // Mostra erro caso exista
    final state = ref.read(authControllerProvider);
    if (state.hasError) {
      final error = state.error;
      final errorMessage = error is AppException
          ? error.message
          : 'Ocorreu um erro inesperado.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: AppColors.error),
      );
    }
  }

  void _loginWithGoogle() {
    ref.read(authControllerProvider.notifier).signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    Widget divider(String text) => Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text, style: AppTextStyles.bodySmall()),
        ),
        const Expanded(child: Divider()),
      ],
    );

    final emailFields = <Widget>[
      const FieldLabel('E-mail'),
      TextField(
        controller: _emailController,
        decoration: AppInputDecoration.defaultDecoration(
          labelText: '',
          hintText: 'seuemail@exemplo.com',
          prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
        ),
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 18),
      const FieldLabel('Senha'),
      TextField(
        controller: _passwordController,
        decoration: AppInputDecoration.defaultDecoration(
          labelText: '',
          hintText: 'Sua senha',
          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
          suffixIcon: IconButton(
            tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        obscureText: _obscurePassword,
        autofillHints: const [AutofillHints.password],
        onSubmitted: (_) => isLoading ? null : _login(),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => context.push('/forgot-password'),
          child: const Text('Esqueci minha senha'),
        ),
      ),
      const SizedBox(height: 12),
      ElevatedButton(
        style: AppButtonStyles.primary(),
        onPressed: isLoading ? null : _login,
        child: isLoading ? const ButtonSpinner() : const Text('Entrar'),
      ),
    ];

    final googleButton = OutlinedButton.icon(
      style: AppButtonStyles.outlined(foregroundColor: AppColors.textPrimary),
      onPressed: isLoading ? null : _loginWithGoogle,
      icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
      label: const Text('Entrar com Google'),
    );

    final signUpLink = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Ainda não tem conta?',
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        TextButton(
          onPressed: widget.onCreateAccount ?? () => context.push('/register'),
          child: const Text('Criar conta'),
        ),
      ],
    );

    // Variante do PC: Google primeiro, depois e-mail e senha.
    if (widget.googleFirst) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          googleButton,
          const SizedBox(height: 22),
          divider('ou entre com seu e-mail'),
          const SizedBox(height: 22),
          ...emailFields,
          const SizedBox(height: 20),
          signUpLink,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...emailFields,
        const SizedBox(height: 22),
        divider('ou'),
        const SizedBox(height: 22),
        googleButton,
        const SizedBox(height: 28),
        signUpLink,
      ],
    );
  }
}
