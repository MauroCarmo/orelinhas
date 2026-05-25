import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/validation/sanitizers.dart';
import '../../../../core/formatters/phone_input_formatter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_button_styles.dart';
import '../../../../core/theme/widgets/app_input_decoration.dart';
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
                const Icon(Icons.mark_email_unread, size: 80, color: AppColors.primary),
                const SizedBox(height: 24),
                Text(
                  'Por favor, verifique seu e-mail!',
                  style: AppTextStyles.heading1(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nós enviamos um link de confirmação. Clique nele para ativar sua conta antes de fazer o login.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: AppButtonStyles.primary(),
                    onPressed: () => context.go('/login'),
                    child: const Text('Voltar para o Login'),
                  ),
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
        padding: const EdgeInsets.fromLTRB(25, 30, 25, 90),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Novo Cadastro', style: AppTextStyles.heading2()),
              const SizedBox(height: 8),
              Text(
                'Preencha seus dados para fazer parte do ecossistema Orelinhas.',
                style: AppTextStyles.body(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 25),

              // Nome Completo
              Text(
                'Nome Completo *',
                style: AppTextStyles.label(),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: AppInputDecoration.defaultDecoration(
                  labelText: '',
                  prefixIcon: const Icon(Icons.person, size: 20),
                ).copyWith(floatingLabelBehavior: FloatingLabelBehavior.never),
                validator: AppValidators.combine([
                  AppValidators.required('Nome Completo'),
                  AppValidators.maxLength(100, 'Nome Completo'),
                ]),
              ),
              const SizedBox(height: 16),

              // E-mail
              Text(
                'E-mail *',
                style: AppTextStyles.label(),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                decoration: AppInputDecoration.defaultDecoration(
                  labelText: '',
                  prefixIcon: const Icon(Icons.email, size: 20),
                ).copyWith(floatingLabelBehavior: FloatingLabelBehavior.never),
                keyboardType: TextInputType.emailAddress,
                validator: AppValidators.combine([
                  AppValidators.required('E-mail'),
                  AppValidators.maxLength(80, 'E-mail'),
                  AppValidators.email(),
                ]),
              ),
              const SizedBox(height: 16),

              // Telefone
              Text(
                'Telefone *',
                style: AppTextStyles.label(),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                decoration: AppInputDecoration.defaultDecoration(
                  labelText: '',
                  helperText: 'Ex: (11) 99999-9999',
                  prefixIcon: const Icon(Icons.phone, size: 20),
                ).copyWith(floatingLabelBehavior: FloatingLabelBehavior.never),
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
              Text(
                'Cidade / Estado *',
                style: AppTextStyles.label(),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _locationController,
                decoration: AppInputDecoration.defaultDecoration(
                  labelText: '',
                  helperText: 'Ex: São Paulo - SP',
                  prefixIcon: const Icon(Icons.location_on, size: 20),
                ).copyWith(floatingLabelBehavior: FloatingLabelBehavior.never),
                validator: AppValidators.combine([
                  AppValidators.required('Cidade / Estado'),
                  AppValidators.maxLength(150, 'Cidade / Estado'),
                ]),
              ),
              const SizedBox(height: 16),

              // Senha
              Text(
                'Senha (mín. 8 caracteres) *',
                style: AppTextStyles.label(),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                decoration: AppInputDecoration.defaultDecoration(
                  labelText: '',
                  helperText: 'Maiúscula, minúscula, número e caractere especial (@\$!%*?&.)',
                  prefixIcon: const Icon(Icons.lock, size: 20),
                ).copyWith(floatingLabelBehavior: FloatingLabelBehavior.never),
                obscureText: true,
                validator: AppValidators.combine([
                  AppValidators.required('Senha'),
                  AppValidators.passwordComplexity(),
                ]),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                style: AppButtonStyles.primary(),
                onPressed: isLoading ? null : _register,
                child: isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                    : const Text('Registrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
