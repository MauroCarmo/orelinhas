import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/validation/sanitizers.dart';
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
      appBar: AppBar(title: const Text('Entrar')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder()),
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading ? null : _login,
              child: isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Entrar'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: isLoading ? null : _loginWithGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 32),
              label: const Text('Entrar com Google'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.push('/register'),
              child: const Text('Não tem uma conta? Registre-se'),
            )
          ],
        ),
      ),
    );
  }
}
