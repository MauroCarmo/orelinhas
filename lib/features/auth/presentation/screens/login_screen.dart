import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/validation/sanitizers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_button_styles.dart';
import '../../../../core/theme/widgets/app_input_decoration.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    final email = AppSanitizers.normalizeEmail(_emailController.text);
    final password = _passwordController.text; // Senhas não sofrem normalização destrutiva

    final authCtrl = ref.read(authControllerProvider.notifier);
    await authCtrl.signIn(email, password);
    
    if (!mounted) return;
    
    // Mostra erro caso exista
    final state = ref.read(authControllerProvider);
    if (state.hasError) {
      final error = state.error;
      final errorMessage = error is AppException ? error.message : 'Ocorreu um erro inesperado.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Text('Orelinhas', style: AppTextStyles.heading2(color: AppColors.primary)),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(25, 40, 25, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bem-vindo ao Orelinhas', style: AppTextStyles.heading1()),
            const SizedBox(height: 8),
            Text(
              'Autentique sua conta para sincronizar dados e monitorar alertas biométricos.',
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 35),
            
            // Email Input
            Text(
              'E-mail ou Usuário',
              style: AppTextStyles.label(),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _emailController,
              decoration: AppInputDecoration.defaultDecoration(
                labelText: '',
                hintText: 'beatriz.oliveira@email.com',
                prefixIcon: const Icon(Icons.email, size: 20),
              ).copyWith(floatingLabelBehavior: FloatingLabelBehavior.never),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            
            // Password Input
            Text(
              'Senha de Acesso',
              style: AppTextStyles.label(),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              decoration: AppInputDecoration.defaultDecoration(
                labelText: '',
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock, size: 20),
              ).copyWith(floatingLabelBehavior: FloatingLabelBehavior.never),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/forgot-password'),
                child: const Text('Esqueceu a senha?'),
              ),
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: AppButtonStyles.primary(),
                onPressed: isLoading ? null : _login,
                child: isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                    : const Text('Acessar Ecossistema'),
              ),
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: AppButtonStyles.outlined(),
                onPressed: isLoading ? null : _loginWithGoogle,
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Entrar com Google'),
              ),
            ),
            const SizedBox(height: 24),
            
            Center(
              child: TextButton(
                onPressed: () => context.push('/register'),
                child: const Text('Não tem uma conta? Registre-se'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
