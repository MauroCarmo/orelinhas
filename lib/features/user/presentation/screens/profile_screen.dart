import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  late TextEditingController _locationController;
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _locationController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _initializeControllers(ProfileEntity profile) {
    if (!_controllersInitialized) {
      _nameController.text = profile.name;
      _phoneController.text = profile.phone;
      _locationController.text = profile.location;
      _controllersInitialized = true;
    }
  }

  Future<void> _saveChanges(ProfileEntity currentProfile) async {
    if (_formKey.currentState!.validate()) {
      final updatedProfile = currentProfile.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        location: _locationController.text.trim(),
      );

      // Validação rápida no domínio antes de chamar o controller
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro: ${error.toString().replaceAll('Exception: ', '')}'),
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
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Nome é obrigatório';
                      if (val.length > 100) return 'Máximo 100 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Campo Telefone
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Telefone (com DDD) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                      helperText: 'Ex: 11987654321',
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

                  // Campo Localização
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Cidade / Estado *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                      helperText: 'Ex: São Paulo - SP',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Localização é obrigatória';
                      if (val.length > 150) return 'Máximo 150 caracteres';
                      return null;
                    },
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
                      onPressed: () => _saveChanges(profile),
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
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Erro ao carregar perfil: $err', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(profileControllerProvider),
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
