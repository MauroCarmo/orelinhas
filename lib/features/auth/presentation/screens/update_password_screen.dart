import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_input_decoration.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_layout.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  ConsumerState<UpdatePasswordScreen> createState() =>
      _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends ConsumerState<UpdatePasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _updatePassword() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('As senhas não coincidem.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final authCtrl = ref.read(authControllerProvider.notifier);
    await authCtrl.updatePassword(_passwordController.text);

    final state = ref.read(authControllerProvider);
    if (state.hasError && mounted) {
      String errorMessage = state.error.toString();
      if (state.error is AuthException) {
        errorMessage = (state.error as AuthException).message;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: AppColors.error),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha atualizada com sucesso!')),
      );
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return AuthLayout(
      title: 'Crie uma nova senha',
      subtitle: 'Escolha uma senha que você não usa em outros sites.',
      showLogo: false,
      children: [
        const FieldLabel('Nova senha'),
        TextField(
          controller: _passwordController,
          decoration: AppInputDecoration.defaultDecoration(
            labelText: '',
            hintText: 'Mínimo de 6 caracteres',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 18),
        const FieldLabel('Confirmar nova senha'),
        TextField(
          controller: _confirmPasswordController,
          decoration: AppInputDecoration.defaultDecoration(
            labelText: '',
            hintText: 'Repita a nova senha',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: isLoading ? null : _updatePassword,
          child: isLoading
              ? const ButtonSpinner()
              : const Text('Salvar nova senha'),
        ),
      ],
    );
  }
}
