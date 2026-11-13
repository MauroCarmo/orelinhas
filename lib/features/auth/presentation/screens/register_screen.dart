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
import '../widgets/auth_layout.dart';

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
  bool _obscurePassword = true;

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
    final password =
        _passwordController.text; // Senhas não sofrem normalização destrutiva

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
      final errorMessage = error is AppException
          ? error.message
          : 'Ocorreu um erro inesperado.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: AppColors.error),
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
      return AuthConfirmation(
        icon: Icons.mark_email_unread_outlined,
        title: 'Confirme seu e-mail',
        message:
            'Enviamos um link de confirmação para o seu e-mail. Abra o link para ativar sua conta e depois entre no app.',
        actionLabel: 'Ir para o login',
        onAction: () => context.go('/login'),
      );
    }

    return AuthLayout(
      title: 'Crie sua conta',
      subtitle:
          'Leva menos de um minuto. Seus dados ajudam quem encontrar um pet a falar com você.',
      showLogo: false,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Nome completo'),
              TextFormField(
                controller: _nameController,
                decoration: AppInputDecoration.defaultDecoration(
                  labelText: '',
                  hintText: 'Como você se chama?',
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                    size: 20,
                  ),
                ),
                textCapitalization: TextCapitalization.words,
                validator: AppValidators.combine([
                  AppValidators.required('Nome Completo'),
                  AppValidators.maxLength(100, 'Nome Completo'),
                ]),
              ),
              const SizedBox(height: 18),

              const FieldLabel('E-mail'),
              TextFormField(
                controller: _emailController,
                decoration: AppInputDecoration.defaultDecoration(
                  labelText: '',
                  hintText: 'seuemail@exemplo.com',
                  prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: AppValidators.combine([
                  AppValidators.required('E-mail'),
                  AppValidators.maxLength(80, 'E-mail'),
                  AppValidators.email(),
                ]),
              ),
              const SizedBox(height: 18),

              const FieldLabel('Telefone'),
              TextFormField(
                controller: _phoneController,
                decoration: AppInputDecoration.defaultDecoration(
                  labelText: '',
                  hintText: '(11) 99999-9999',
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [PhoneInputFormatter()],
                validator: AppValidators.combine([
                  AppValidators.required('Telefone'),
                  AppValidators.phone(),
                ]),
              ),
              const SizedBox(height: 18),

              const FieldLabel('Cidade / Estado'),
              TextFormField(
                controller: _locationController,
                decoration: AppInputDecoration.defaultDecoration(
                  labelText: '',
                  hintText: 'São Paulo - SP',
                  prefixIcon: const Icon(Icons.place_outlined, size: 20),
                ),
                validator: AppValidators.combine([
                  AppValidators.required('Cidade / Estado'),
                  AppValidators.maxLength(150, 'Cidade / Estado'),
                ]),
              ),
              const SizedBox(height: 18),

              const FieldLabel('Senha'),
              TextFormField(
                controller: _passwordController,
                decoration: AppInputDecoration.defaultDecoration(
                  labelText: '',
                  hintText: 'Mínimo de 8 caracteres',
                  helperText:
                      'Use maiúscula, minúscula, número e um símbolo (@\$!%*?&.)',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Mostrar senha'
                        : 'Ocultar senha',
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
                    ? const ButtonSpinner()
                    : const Text('Criar conta'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Já tem conta?',
                    style: AppTextStyles.body(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Entrar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
