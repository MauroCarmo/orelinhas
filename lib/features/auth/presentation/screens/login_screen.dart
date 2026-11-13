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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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

    return AuthLayout(
      title: 'Que bom te ver de novo',
      subtitle:
          'Entre para acompanhar seus alertas e ajudar pets perto de você.',
      children: [
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
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('ou', style: AppTextStyles.bodySmall()),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          style: AppButtonStyles.outlined(
            foregroundColor: AppColors.textPrimary,
          ),
          onPressed: isLoading ? null : _loginWithGoogle,
          icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
          label: const Text('Entrar com Google'),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Ainda não tem conta?',
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: () => context.push('/register'),
              child: const Text('Criar conta'),
            ),
          ],
        ),
      ],
    );
  }
}
