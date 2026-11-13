import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/validation/sanitizers.dart';
import '../../../../core/formatters/phone_input_formatter.dart';
import '../../../../core/formatters/cep_input_formatter.dart';
import '../../../../core/domain/address/address_entity.dart';
import '../../../../core/services/viacep_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_button_styles.dart';
import '../../../../core/theme/widgets/app_input_decoration.dart';
import '../../../../core/routing/app_routes.dart';
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

  // Avatar
  Uint8List? _selectedImageBytes;
  String? _selectedImageFileName;
  String? _existingAvatarUrl;
  final ImagePicker _picker = ImagePicker();

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
        final errorMessage = e is AppException
            ? e.message
            : 'Falha ao buscar o CEP.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
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
      _existingAvatarUrl = profile.avatarUrl;

      // Formata o telefone se necessário
      final rawPhone = profile.phone;
      if (rawPhone.length >= 10) {
        final ddd = rawPhone.substring(0, 2);
        if (rawPhone.length == 11) {
          _phoneController.text =
              '($ddd) ${rawPhone.substring(2, 7)}-${rawPhone.substring(7)}';
        } else {
          _phoneController.text =
              '($ddd) ${rawPhone.substring(2, 6)}-${rawPhone.substring(6)}';
        }
      } else {
        _phoneController.text = rawPhone;
      }

      // Formata o CEP se necessário
      final rawCep = profile.address.cep;
      if (rawCep.length == 8) {
        _cepController.text =
            '${rawCep.substring(0, 5)}-${rawCep.substring(5)}';
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

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageFileName = image.name;
          _existingAvatarUrl = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao selecionar imagem.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<String?> _uploadAvatarIfNeeded() async {
    if (_selectedImageBytes == null &&
        _existingAvatarUrl != null &&
        _existingAvatarUrl!.isNotEmpty) {
      return _existingAvatarUrl;
    }

    if (_selectedImageBytes == null) {
      return null;
    }

    final user = ref.read(currentUserProvider);
    final storageService = ref.read(storageServiceProvider);

    try {
      final url = await storageService.uploadImage(
        bytes: _selectedImageBytes!,
        fileName: _selectedImageFileName ?? 'avatar.jpg',
        bucket: 'avatars',
        folder: user?.id,
      );
      return url;
    } on ValidationException catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
      return null;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Falha ao enviar imagem.'),
          backgroundColor: AppColors.error,
        ),
      );
      return null;
    }
  }

  Future<void> _saveChanges(ProfileEntity currentProfile) async {
    if (_formKey.currentState!.validate()) {
      final avatarUrl = await _uploadAvatarIfNeeded();
      if (!mounted) return;
      if (_selectedImageBytes != null && avatarUrl == null) {
        return;
      }

      final name = AppSanitizers.sanitizeText(_nameController.text);
      final phone = AppSanitizers.digitsOnly(_phoneController.text);
      final cep = AppSanitizers.digitsOnly(_cepController.text);

      final street = AppSanitizers.sanitizeText(_streetController.text);
      final number = AppSanitizers.sanitizeText(_numberController.text);
      final district = AppSanitizers.sanitizeText(_districtController.text);
      final city = AppSanitizers.sanitizeText(_cityController.text);
      final state = AppSanitizers.trim(_stateController.text).toUpperCase();
      final complement = AppSanitizers.sanitizeText(_complementController.text);

      final location = '$city - $state';

      final updatedProfile = currentProfile.copyWith(
        name: name,
        phone: phone,
        location: location,
        avatarUrl: avatarUrl ?? currentProfile.avatarUrl,
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

      final validationError = updatedProfile.validate();
      if (validationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validationError),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      await ref
          .read(profileControllerProvider.notifier)
          .updateProfile(updatedProfile);
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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

    ref.listen<AsyncValue<ProfileEntity?>>(profileControllerProvider, (
      previous,
      next,
    ) {
      next.whenOrNull(
        error: (error, _) {
          final errorMessage = error is AppException
              ? error.message
              : 'Ocorreu um erro inesperado.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AppColors.error,
            ),
          );
        },
        data: (profile) {
          if (previous != null && !next.isLoading && !next.hasError) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Perfil atualizado com sucesso!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Voltar',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        title: const Text('Minha Conta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
            tooltip: 'Sair da conta',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: profileState.when(
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: Text('Nenhum dado de perfil encontrado.'),
            );
          }

          _initializeControllers(profile);

          final hasAvatar =
              _selectedImageBytes != null ||
              (_existingAvatarUrl != null && _existingAvatarUrl!.isNotEmpty);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho com avatar
                  _SectionCard(
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 34,
                                backgroundColor: AppColors.primarySoft,
                                backgroundImage: _selectedImageBytes != null
                                    ? MemoryImage(_selectedImageBytes!)
                                    : (hasAvatar
                                              ? NetworkImage(
                                                  _existingAvatarUrl!,
                                                )
                                              : null)
                                          as ImageProvider?,
                                child: hasAvatar
                                    ? null
                                    : const Icon(
                                        Icons.person_rounded,
                                        size: 36,
                                        color: AppColors.primary,
                                      ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.photo_camera_outlined,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.name.isEmpty
                                    ? 'Seu nome'
                                    : profile.name,
                                style: AppTextStyles.heading2(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profile.email,
                                style: AppTextStyles.bodySmall(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: _pickImage,
                                child: Text(
                                  'Alterar foto',
                                  style: AppTextStyles.label(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Atalhos
                  _SectionCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _MenuTile(
                          icon: Icons.article_outlined,
                          title: 'Meus alertas de pets perdidos',
                          onTap: () => context.go(AppRoutes.myAlerts),
                        ),
                        const Divider(height: 1, indent: 56),
                        _MenuTile(
                          icon: Icons.campaign_outlined,
                          title: 'Registrar pet perdido',
                          onTap: () => context.push(AppRoutes.petLostCreate),
                        ),
                        const Divider(height: 1, indent: 56),
                        _MenuTile(
                          icon: Icons.check_circle_outline,
                          title: 'Pets encontrados',
                          onTap: () => context.push(AppRoutes.petFound),
                        ),
                        const Divider(height: 1, indent: 56),
                        _MenuTile(
                          icon: Icons.favorite_border_rounded,
                          title: 'Adoção de pets',
                          onTap: () => context.push(AppRoutes.petAdoption),
                        ),
                        const Divider(height: 1, indent: 56),
                        _MenuTile(
                          icon: Icons.logout_rounded,
                          title: 'Sair da conta',
                          onTap: () => ref
                              .read(authControllerProvider.notifier)
                              .signOut(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),

                  Text('Dados pessoais', style: AppTextStyles.sectionHeader()),
                  const SizedBox(height: 12),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const FieldLabel('E-mail'),
                        TextFormField(
                          initialValue: profile.email,
                          decoration: AppInputDecoration.defaultDecoration(
                            labelText: '',
                            helperText: 'O e-mail não pode ser alterado.',
                            prefixIcon: const Icon(
                              Icons.mail_outline_rounded,
                              size: 20,
                            ),
                          ),
                          readOnly: true,
                          enabled: false,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        const FieldLabel('Nome completo'),
                        TextFormField(
                          controller: _nameController,
                          decoration: AppInputDecoration.defaultDecoration(
                            labelText: '',
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                              size: 20,
                            ),
                          ),
                          validator: AppValidators.combine([
                            AppValidators.required('Nome Completo'),
                            AppValidators.maxLength(100, 'Nome Completo'),
                          ]),
                        ),
                        const SizedBox(height: 16),

                        const FieldLabel('Telefone (com DDD)'),
                        TextFormField(
                          controller: _phoneController,
                          decoration: AppInputDecoration.defaultDecoration(
                            labelText: '',
                            hintText: '(11) 99999-9999',
                            prefixIcon: const Icon(
                              Icons.phone_outlined,
                              size: 20,
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [PhoneInputFormatter()],
                          validator: AppValidators.combine([
                            AppValidators.required('Telefone'),
                            AppValidators.phone(),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),

                  Text('Endereço', style: AppTextStyles.sectionHeader()),
                  const SizedBox(height: 12),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const FieldLabel('CEP'),
                                  TextFormField(
                                    controller: _cepController,
                                    decoration:
                                        AppInputDecoration.defaultDecoration(
                                          labelText: '',
                                          hintText: '01001-000',
                                          suffixIcon: _isLoadingCep
                                              ? const Padding(
                                                  padding: EdgeInsets.all(14.0),
                                                  child: SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [CepInputFormatter()],
                                    validator: AppValidators.combine([
                                      AppValidators.required('CEP'),
                                      AppValidators.cep(),
                                    ]),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const FieldLabel('UF'),
                                  TextFormField(
                                    controller: _stateController,
                                    decoration:
                                        AppInputDecoration.defaultDecoration(
                                          labelText: '',
                                          hintText: 'SP',
                                        ),
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    validator: AppValidators.combine([
                                      AppValidators.required('Estado (UF)'),
                                      AppValidators.minLength(2, 'Estado (UF)'),
                                      AppValidators.maxLength(2, 'Estado (UF)'),
                                    ]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        const FieldLabel('Cidade'),
                        TextFormField(
                          controller: _cityController,
                          decoration: AppInputDecoration.defaultDecoration(
                            labelText: '',
                          ),
                          validator: AppValidators.combine([
                            AppValidators.required('Cidade'),
                            AppValidators.maxLength(100, 'Cidade'),
                          ]),
                        ),
                        const SizedBox(height: 16),

                        const FieldLabel('Bairro'),
                        TextFormField(
                          controller: _districtController,
                          decoration: AppInputDecoration.defaultDecoration(
                            labelText: '',
                          ),
                          validator: AppValidators.combine([
                            AppValidators.required('Bairro'),
                            AppValidators.maxLength(100, 'Bairro'),
                          ]),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const FieldLabel('Rua'),
                                  TextFormField(
                                    controller: _streetController,
                                    decoration:
                                        AppInputDecoration.defaultDecoration(
                                          labelText: '',
                                        ),
                                    validator: AppValidators.combine([
                                      AppValidators.required(
                                        'Rua / Logradouro',
                                      ),
                                      AppValidators.maxLength(
                                        150,
                                        'Rua / Logradouro',
                                      ),
                                    ]),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const FieldLabel('Nº'),
                                  TextFormField(
                                    controller: _numberController,
                                    decoration:
                                        AppInputDecoration.defaultDecoration(
                                          labelText: '',
                                        ),
                                    validator: AppValidators.combine([
                                      AppValidators.required('Número'),
                                      AppValidators.maxLength(20, 'Número'),
                                    ]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        const FieldLabel('Complemento (opcional)'),
                        TextFormField(
                          controller: _complementController,
                          decoration: AppInputDecoration.defaultDecoration(
                            labelText: '',
                            hintText: 'Ex.: Bloco B, Apto 104',
                          ),
                          validator: AppValidators.combine([
                            AppValidators.maxLength(150, 'Complemento'),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (profileState.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      style: AppButtonStyles.primary(),
                      onPressed: _isLoadingCep
                          ? null
                          : () => _saveChanges(profile),
                      child: const Text('Salvar alterações'),
                    ),

                  const SizedBox(height: 32),

                  Text(
                    'Excluir a conta remove permanentemente seus dados e todos os seus alertas.',
                    style: AppTextStyles.bodySmall(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Excluir minha conta'),
                    onPressed: _confirmDeleteAccount,
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          final errMsg = err is AppException
              ? err.message
              : 'Falha ao carregar perfil.';
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    errMsg,
                    style: AppTextStyles.body(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.refresh(profileControllerProvider),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(title),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondary,
      ),
      onTap: onTap,
    );
  }
}
