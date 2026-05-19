import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/validation/sanitizers.dart';
import '../../../../core/formatters/phone_input_formatter.dart';
import '../../../../core/formatters/cep_input_formatter.dart';
import '../../../../core/domain/address/address_entity.dart';
import '../../../../core/services/viacep_service.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';
import '../../domain/profile_entity.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  
  // Controllers do Endereço Estruturado
  late TextEditingController _cepController;
  late TextEditingController _streetController;
  late TextEditingController _numberController;
  late TextEditingController _districtController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _complementController;

  bool _controllersInitialized = false;
  String _lastCheckedCep = '';
  bool _isLoadingCep = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _cepController = TextEditingController();
    _streetController = TextEditingController();
    _numberController = TextEditingController();
    _districtController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _complementController = TextEditingController();

    _cepController.addListener(_onCepChanged);
  }

  @override
  void dispose() {
    _cepController.removeListener(_onCepChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _cepController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _complementController.dispose();
    super.dispose();
  }

  void _onCepChanged() {
    final cleanCep = AppSanitizers.digitsOnly(_cepController.text);
    if (cleanCep.length == 8 && cleanCep != _lastCheckedCep) {
      _lastCheckedCep = cleanCep;
      _fetchAddress(cleanCep);
    }
  }

  Future<void> _fetchAddress(String cep) async {
    setState(() {
      _isLoadingCep = true;
    });

    try {
      final viacep = ref.read(viaCepServiceProvider);
      final addressData = await viacep.fetchAddress(cep);

      if (mounted) {
        setState(() {
          _streetController.text = addressData['street'] ?? '';
          _districtController.text = addressData['district'] ?? '';
          _cityController.text = addressData['city'] ?? '';
          _stateController.text = addressData['state'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e is AppException ? e.message : 'Falha ao buscar o CEP.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCep = false;
        });
      }
    }
  }

  void _initializeControllers(ProfileEntity profile) {
    if (!_controllersInitialized) {
      _nameController.text = profile.name;
      
      // Formata o telefone se necessário
      final rawPhone = profile.phone;
      if (rawPhone.length >= 10) {
        final ddd = rawPhone.substring(0, 2);
        if (rawPhone.length == 11) {
          _phoneController.text = '($ddd) ${rawPhone.substring(2, 7)}-${rawPhone.substring(7)}';
        } else {
          _phoneController.text = '($ddd) ${rawPhone.substring(2, 6)}-${rawPhone.substring(6)}';
        }
      } else {
        _phoneController.text = rawPhone;
      }

      // Formata o CEP se necessário
      final rawCep = profile.address.cep;
      if (rawCep.length == 8) {
        _cepController.text = '${rawCep.substring(0, 5)}-${rawCep.substring(5)}';
        _lastCheckedCep = rawCep;
      } else {
        _cepController.text = rawCep;
      }

      _streetController.text = profile.address.street;
      _numberController.text = profile.address.number;
      _districtController.text = profile.address.district;
      _cityController.text = profile.address.city;
      _stateController.text = profile.address.state;
      _complementController.text = profile.address.complement;
      
      _controllersInitialized = true;
    }
  }

  Future<void> _saveChanges(ProfileEntity currentProfile) async {
    if (_formKey.currentState!.validate()) {
      // Sanitização técnica agressiva (apenas números e caracteres limpos)
      final name = AppSanitizers.sanitizeText(_nameController.text);
      final phone = AppSanitizers.digitsOnly(_phoneController.text);
      final cep = AppSanitizers.digitsOnly(_cepController.text);
      
      // Sanitização não destrutiva para entradas livres humanas
      final street = AppSanitizers.sanitizeText(_streetController.text);
      final number = AppSanitizers.sanitizeText(_numberController.text);
      final district = AppSanitizers.sanitizeText(_districtController.text);
      final city = AppSanitizers.sanitizeText(_cityController.text);
      final state = AppSanitizers.trim(_stateController.text).toUpperCase();
      final complement = AppSanitizers.sanitizeText(_complementController.text);

      // Derived location format ("Cidade - UF") para retrocompatibilidade
      final location = '$city - $state';

      final updatedProfile = currentProfile.copyWith(
        name: name,
        phone: phone,
        location: location,
        address: AddressEntity(
          cep: cep,
          street: street,
          number: number,
          district: district,
          city: city,
          state: state,
          complement: complement,
        ),
      );

      // Validação no nível de domínio (Defesa em Profundidade)
      final validationError = updatedProfile.validate();
      if (validationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validationError), backgroundColor: Colors.red),
        );
        return;
      }

      await ref.read(profileControllerProvider.notifier).updateProfile(updatedProfile);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Conta'),
        content: const Text(
          'Deseja realmente excluir permanentemente sua conta? '
          'Esta ação é irreversível e todos os seus dados serão apagados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(profileControllerProvider.notifier).deleteAccount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);

    // Escuta erros e sucessos do controller do perfil
    ref.listen<AsyncValue<ProfileEntity?>>(profileControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          final errorMessage = error is AppException ? error.message : 'Ocorreu um erro inesperado.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        },
        data: (profile) {
          if (previous != null && !next.isLoading && !next.hasError) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Perfil atualizado com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Conta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
            tooltip: 'Sair da Conta',
          ),
        ],
      ),
      body: profileState.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Nenhum dado de perfil encontrado.'));
          }

          _initializeControllers(profile);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.account_circle, size: 100, color: Colors.blueGrey),
                  const SizedBox(height: 16),
                  
                  // Campo Email (Apenas Leitura)
                  TextFormField(
                    initialValue: profile.email,
                    decoration: const InputDecoration(
                      labelText: 'E-mail (Não pode ser alterado)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    readOnly: true,
                    enabled: false,
                  ),
                  const SizedBox(height: 16),

                  // Campo Nome
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

                  // Campo Telefone
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Telefone (com DDD) *',
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

                  // Campos de Endereço Estruturado
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Endereço Residencial',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                  ),

                  // Linha CEP e Estado (UF)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _cepController,
                          decoration: InputDecoration(
                            labelText: 'CEP *',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.map),
                            helperText: 'Ex: 01001-000',
                            suffixIcon: _isLoadingCep
                                ? const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : null,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            CepInputFormatter(),
                          ],
                          validator: AppValidators.combine([
                            AppValidators.required('CEP'),
                            AppValidators.cep(),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _stateController,
                          decoration: const InputDecoration(
                            labelText: 'Estado (UF) *',
                            border: OutlineInputBorder(),
                            helperText: 'Ex: SP',
                          ),
                          textCapitalization: TextCapitalization.characters,
                          validator: AppValidators.combine([
                            AppValidators.required('Estado (UF)'),
                            AppValidators.minLength(2, 'Estado (UF)'),
                            AppValidators.maxLength(2, 'Estado (UF)'),
                          ]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Campo Cidade
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Cidade *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                    validator: AppValidators.combine([
                      AppValidators.required('Cidade'),
                      AppValidators.maxLength(100, 'Cidade'),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Campo Bairro
                  TextFormField(
                    controller: _districtController,
                    decoration: const InputDecoration(
                      labelText: 'Bairro *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.layers),
                    ),
                    validator: AppValidators.combine([
                      AppValidators.required('Bairro'),
                      AppValidators.maxLength(100, 'Bairro'),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Linha Rua e Número
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _streetController,
                          decoration: const InputDecoration(
                            labelText: 'Rua / Logradouro *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.home),
                          ),
                          validator: AppValidators.combine([
                            AppValidators.required('Rua / Logradouro'),
                            AppValidators.maxLength(150, 'Rua / Logradouro'),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _numberController,
                          decoration: const InputDecoration(
                            labelText: 'Nº *',
                            border: OutlineInputBorder(),
                          ),
                          validator: AppValidators.combine([
                            AppValidators.required('Número'),
                            AppValidators.maxLength(20, 'Número'),
                          ]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Campo Complemento
                  TextFormField(
                    controller: _complementController,
                    decoration: const InputDecoration(
                      labelText: 'Complemento (Opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.info_outline),
                      helperText: 'Ex: Bloco B, Apt 104',
                    ),
                    validator: AppValidators.combine([
                      AppValidators.maxLength(150, 'Complemento'),
                    ]),
                  ),
                  const SizedBox(height: 32),

                  // Botão Salvar Alterações
                  if (profileState.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                      ),
                      onPressed: _isLoadingCep ? null : () => _saveChanges(profile),
                      child: const Text(
                        'Salvar Alterações',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  
                  const SizedBox(height: 48),
                  
                  // Botão de Excluir Conta
                  const Divider(color: Colors.redAccent),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text(
                      'Excluir Conta Permanentemente',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _confirmDeleteAccount,
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          final errMsg = err is AppException ? err.message : 'Falha ao carregar perfil.';
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(errMsg, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(profileControllerProvider),
                  child: const Text('Tentar Novamente'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
