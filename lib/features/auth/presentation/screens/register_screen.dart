import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/auth_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  bool _registrationSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authCtrl = ref.read(authControllerProvider.notifier);
    await authCtrl.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      location: _locationController.text.trim(),
    );
    
    final state = ref.read(authControllerProvider);
    if (state.hasError && mounted) {
      String errorMessage = state.error.toString();
      if (state.error is AuthException) {
        errorMessage = (state.error as AuthException).message;
      } else {
        errorMessage = errorMessage.replaceAll('Exception: ', '');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } else if (mounted) {
      setState(() {
        _registrationSuccess = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    if (_registrationSuccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Registro Concluído')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mark_email_unread, size: 80, color: Colors.deepPurple),
                const SizedBox(height: 24),
                const Text(
                  'Por favor, verifique seu e-mail!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nós enviamos um link de confirmação. Clique nele para ativar sua conta antes de fazer o login.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Voltar para o Login'),
                )
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Criar Conta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nome Completo
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome Completo *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Nome é obrigatório';
                  if (val.length > 100) return 'Máximo 100 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // E-mail
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'E-mail é obrigatório';
                  if (val.length > 80) return 'Máximo 80 caracteres';
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(val.trim())) return 'E-mail inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Telefone
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefone *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                  helperText: 'Apenas números com DDD',
                ),
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Telefone é obrigatório';
                  final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
                  if (clean.length < 8 || clean.length > 15) {
                    return 'O telefone deve conter entre 8 e 15 números';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Localização
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Cidade / Estado *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Localização é obrigatória';
                  if (val.length > 150) return 'Máximo 150 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Senha
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Senha (mín. 6 caracteres) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                  helperText: 'Maiúscula, minúscula, número e caractere especial (@\$!%*?&.)',
                ),
                obscureText: true,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Senha é obrigatória';
                  if (val.length < 6) return 'Mínimo de 6 caracteres';
                  if (!RegExp(r'[A-Z]').hasMatch(val)) return 'Falta uma letra maiúscula';
                  if (!RegExp(r'[a-z]').hasMatch(val)) return 'Falta uma letra minúscula';
                  if (!RegExp(r'[0-9]').hasMatch(val)) return 'Falta pelo menos um número';
                  if (!RegExp(r'[@$!%*?&.]').hasMatch(val)) return 'Falta um caractere especial';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: isLoading ? null : _register,
                child: isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Registrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
