import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/validation/sanitizers.dart';
import '../../../../core/formatters/phone_input_formatter.dart';
import '../controllers/auth_controller.dart';

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

    // Sanitização e endurecimento de segurança na entrada
    final name = AppSanitizers.sanitizeText(_nameController.text);
    final email = AppSanitizers.normalizeEmail(_emailController.text);
    final phone = AppSanitizers.digitsOnly(_phoneController.text);
    final location = AppSanitizers.sanitizeText(_locationController.text);
    final password = _passwordController.text; // Senhas não sofrem normalização destrutiva

    final authCtrl = ref.read(authControllerProvider.notifier);
    await authCtrl.signUp(
      email: email,
      password: password,
      name: name,
      phone: phone,
      location: location,
    );
    
    if (!mounted) return;
    
    final state = ref.read(authControllerProvider);
    if (state.hasError) {
      final error = state.error;
      final errorMessage = error is AppException ? error.message : 'Ocorreu um erro inesperado.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } else {
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
                validator: AppValidators.combine([
                  AppValidators.required('Nome Completo'),
                  AppValidators.maxLength(100, 'Nome Completo'),
                ]),
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
                validator: AppValidators.combine([
                  AppValidators.required('E-mail'),
                  AppValidators.maxLength(80, 'E-mail'),
                  AppValidators.email(),
                ]),
              ),
              const SizedBox(height: 16),

              // Telefone
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefone *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                  helperText: 'Ex: (11) 99999-9999',
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  PhoneInputFormatter(),
                ],
                validator: AppValidators.combine([
                  AppValidators.required('Telefone'),
                  AppValidators.phone(),
                ]),
              ),
              const SizedBox(height: 16),

              // Localização
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Cidade / Estado *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                  helperText: 'Ex: São Paulo - SP',
                ),
                validator: AppValidators.combine([
                  AppValidators.required('Cidade / Estado'),
                  AppValidators.maxLength(150, 'Cidade / Estado'),
                ]),
              ),
              const SizedBox(height: 16),

              // Senha
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Senha (mín. 8 caracteres) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                  helperText: 'Maiúscula, minúscula, número e caractere especial (@\$!%*?&.)',
                ),
                obscureText: true,
                validator: AppValidators.combine([
                  AppValidators.required('Senha'),
                  AppValidators.passwordComplexity(),
                ]),
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
