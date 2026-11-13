import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_input_decoration.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_layout.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _resetPassword() async {
    final authCtrl = ref.read(authControllerProvider.notifier);
    await authCtrl.sendPasswordReset(_emailController.text.trim());

    final state = ref.read(authControllerProvider);
    if (state.hasError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    } else if (mounted) {
      setState(() {
        _emailSent = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    if (_emailSent) {
      return AuthConfirmation(
        icon: Icons.mark_email_read_outlined,
        title: 'Confira seu e-mail',
        message:
            'Se o e-mail estiver cadastrado, você receberá um link para criar uma nova senha.',
        actionLabel: 'Voltar para o login',
        onAction: () => context.go('/login'),
      );
    }

    return AuthLayout(
      title: 'Recuperar senha',
      subtitle:
          'Informe o e-mail da sua conta e enviaremos um link para você criar uma nova senha.',
      showLogo: false,
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
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: isLoading ? null : _resetPassword,
          child: isLoading ? const ButtonSpinner() : const Text('Enviar link'),
        ),
      ],
    );
  }
}
