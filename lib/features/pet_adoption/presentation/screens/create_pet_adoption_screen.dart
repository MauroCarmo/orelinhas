import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/formatters/phone_input_formatter.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_input_decoration.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../../user/data/profile_repository.dart';
import '../../../user/domain/profile_entity.dart';
import '../../../user/presentation/controllers/profile_controller.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart' show PetType;
import '../../../pet_lost/presentation/widgets/pet_widgets.dart';
import '../controllers/pet_adoption_controller.dart';
import '../../domain/pet_adoption_entity.dart';

class CreatePetAdoptionScreen extends ConsumerStatefulWidget {
  final String? alertId;

  const CreatePetAdoptionScreen({super.key, this.alertId});

  @override
  ConsumerState<CreatePetAdoptionScreen> createState() =>
      _CreatePetAdoptionScreenState();
}

class _CreatePetAdoptionScreenState
    extends ConsumerState<CreatePetAdoptionScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _characteristicsController;
  late TextEditingController _regionController;
  late TextEditingController _contactController;

  PetType _selectedSpecies = PetType.dog;
  bool _isVaccinated = false;
  bool _controllersInitialized = false;

  Uint8List? _selectedImageBytes;
  String? _selectedImageFileName;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _characteristicsController = TextEditingController();
    _regionController = TextEditingController();
    _contactController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _characteristicsController.dispose();
    _regionController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _initializeControllers(PetAdoptionAlertEntity adoption) {
    if (!_controllersInitialized) {
      _selectedSpecies = adoption.species;
      _nameController.text = adoption.name;
      _characteristicsController.text = adoption.characteristics;
      _regionController.text = adoption.region;
      _isVaccinated = adoption.isVaccinated;
      _existingImageUrl = adoption.imageUrl;
      final currentProfile = ref.read(profileControllerProvider).value;
      if (currentProfile != null && currentProfile.phone.isNotEmpty) {
        _contactController.text = currentProfile.phone;
      }
      _controllersInitialized = true;
    }
  }

  void _showErrorDialog(BuildContext context, List<String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Falta pouco'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: errors
                .map(
                  (err) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(child: Text(err)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageFileName = image.name;
          _existingImageUrl = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(context, ['Erro ao selecionar imagem.']);
    }
  }

  Future<String?> _uploadImageIfNeeded() async {
    if (_selectedImageBytes == null &&
        _existingImageUrl != null &&
        _existingImageUrl!.isNotEmpty) {
      return _existingImageUrl;
    }

    if (_selectedImageBytes == null) {
      return null;
    }

    final user = ref.read(currentUserProvider);
    final storageService = ref.read(storageServiceProvider);

    try {
      final url = await storageService.uploadImage(
        bytes: _selectedImageBytes!,
        fileName: _selectedImageFileName ?? 'adoption.jpg',
        bucket: 'pet_images',
        folder: user?.id,
      );
      return url;
    } on ValidationException catch (e) {
      if (!mounted) return null;
      _showErrorDialog(context, [e.message]);
      return null;
    } catch (e) {
      if (!mounted) return null;
      _showErrorDialog(context, ['Falha ao enviar imagem. Tente novamente.']);
      return null;
    }
  }

  Future<void> _submitForm() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuário não autenticado.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedImageBytes == null &&
        (_existingImageUrl == null || _existingImageUrl!.isEmpty)) {
      _showErrorDialog(context, ['A foto do pet é obrigatória.']);
      return;
    }

    // Validação do telefone de contato (obrigatório para adoção)
    final contactText = _contactController.text.trim();
    final digits = contactText.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 11) {
      _showErrorDialog(context, [
        'O telefone de contato é obrigatório e deve ter DDD + número válido (10 ou 11 dígitos).'
      ]);
      return;
    }

    final imageUrl = await _uploadImageIfNeeded();
    if (!mounted) return;
    if (imageUrl == null) {
      return;
    }

    final tempEntity = PetAdoptionAlertEntity(
      id: widget.alertId ?? '',
      userId: user.id,
      name: _nameController.text,
      species: _selectedSpecies,
      characteristics: _characteristicsController.text,
      region: _regionController.text,
      isVaccinated: _isVaccinated,
      imageUrl: imageUrl,
    );

    final errors = tempEntity.validate();
    if (errors.isNotEmpty) {
      _showErrorDialog(context, errors);
      return;
    }

    // Sincroniza o telefone no perfil do usuário se necessário
    try {
      final profileState = ref.read(profileControllerProvider).value;
      if (profileState != null) {
        final currentPhoneDigits = profileState.phone.replaceAll(RegExp(r'\D'), '');
        if (currentPhoneDigits != digits) {
          final updated = ProfileEntity(
            id: profileState.id,
            name: profileState.name,
            email: profileState.email,
            phone: digits,
            location: profileState.location,
            address: profileState.address,
            avatarUrl: profileState.avatarUrl,
          );
          await ref.read(profileRepositoryProvider).updateProfile(updated);
          ref.invalidate(profileControllerProvider);
        }
      }
    } catch (_) {
      // Falha secundária não impede o cadastro de adoção
    }

    final controller = ref.read(petAdoptionControllerProvider.notifier);
    if (widget.alertId != null) {
      await controller.updateAdoption(tempEntity.copyWith(id: widget.alertId));
    } else {
      await controller.createAdoption(tempEntity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(petAdoptionControllerProvider);

    ref.listen<AsyncValue<List<PetAdoptionAlertEntity>>>(
      petAdoptionControllerProvider,
      (previous, next) {
        if (previous is AsyncLoading && next is AsyncData) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.alertId != null
                    ? 'Anúncio atualizado com sucesso!'
                    : 'Anúncio de adoção cadastrado com sucesso!',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        } else if (next is AsyncError) {
          final err = next.error;
          final errMsg = err is AppException
              ? err.message
              : 'Erro ao salvar anúncio.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errMsg), backgroundColor: AppColors.error),
          );
        }
      },
    );

    if (widget.alertId != null) {
      controllerState.maybeWhen(
        data: (adoptions) {
          try {
            final adoption = adoptions.firstWhere(
              (e) => e.id == widget.alertId,
            );
            _initializeControllers(adoption);
          } catch (_) {}
        },
        orElse: () {},
      );
    } else if (!_controllersInitialized) {
      final currentProfile = ref.watch(profileControllerProvider).value;
      if (currentProfile != null && currentProfile.phone.isNotEmpty) {
        _contactController.text = currentProfile.phone;
        _controllersInitialized = true;
      }
    }

    final isLoading = controllerState.isLoading;
    final isEditing = widget.alertId != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Voltar',
          onPressed: () => context.pop(),
        ),
        title: Text(isEditing ? 'Editar anúncio' : 'Anunciar para adoção'),
      ),
      body: isLoading && !_controllersInitialized && isEditing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildImagePicker(isLoading),
                    const SizedBox(height: 22),
                    const FieldLabel('Nome do pet *'),
                    TextFormField(
                      controller: _nameController,
                      decoration: AppInputDecoration.defaultDecoration(
                        labelText: '',
                        hintText: 'Ex.: Thor, Nina, Pipoca',
                      ),
                      textCapitalization: TextCapitalization.words,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 18),
                    const FieldLabel('Espécie *'),
                    Row(
                      children: [
                        for (final type in PetType.values) ...[
                          Expanded(
                            child: _SpeciesOption(
                              label: switch (type) {
                                PetType.dog => 'Cachorro',
                                PetType.cat => 'Gato',
                                PetType.other => 'Outro',
                              },
                              selected: _selectedSpecies == type,
                              onTap: isLoading
                                  ? null
                                  : () =>
                                        setState(() => _selectedSpecies = type),
                            ),
                          ),
                          if (type != PetType.values.last)
                            const SizedBox(width: 10),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                    const FieldLabel('Região / Cidade *'),
                    TextFormField(
                      controller: _regionController,
                      decoration: AppInputDecoration.defaultDecoration(
                        labelText: '',
                        hintText: 'Ex.: São Paulo, Vila Mariana',
                        prefixIcon: const Icon(Icons.place_outlined, size: 20),
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 18),
                    const FieldLabel('Telefone de contato *'),
                    TextFormField(
                      controller: _contactController,
                      decoration: AppInputDecoration.defaultDecoration(
                        labelText: '',
                        hintText: '(11) 99999-9999',
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                        helperText: 'Com quem os interessados em adotar vão conversar',
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [PhoneInputFormatter()],
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 18),
                    const FieldLabel('Características detalhadas *'),
                    TextFormField(
                      controller: _characteristicsController,
                      decoration: AppInputDecoration.defaultDecoration(
                        labelText: '',
                        hintText:
                            'Brincalhão, dócil com crianças, porte médio…',
                        helperText: 'Mínimo de 10 caracteres.',
                      ),
                      maxLines: 3,
                      maxLength: 255,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: SwitchListTile(
                        title: Text(
                          'Pet vacinado',
                          style: AppTextStyles.label(),
                        ),
                        subtitle: Text(
                          'Informe se o pet já recebeu vacinas',
                          style: AppTextStyles.bodySmall(),
                        ),
                        value: _isVaccinated,
                        activeThumbColor: AppColors.primary,
                        onChanged: isLoading
                            ? null
                            : (val) => setState(() => _isVaccinated = val),
                        secondary: const Icon(
                          Icons.health_and_safety_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      ElevatedButton(
                        onPressed: _submitForm,
                        child: Text(
                          isEditing
                              ? 'Salvar alterações'
                              : 'Publicar para adoção',
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImagePicker(bool isLoading) {
    final hasPreview =
        _selectedImageBytes != null ||
        (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);

    if (!hasPreview) {
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isLoading ? null : _showImageSourceSheet,
        child: CustomPaint(
          painter: _DashedBorderPainter(),
          child: SizedBox(
            height: 170,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_camera_outlined,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Adicione uma foto do pet', style: AppTextStyles.label()),
                const SizedBox(height: 2),
                Text(
                  'Fotos nítidas aumentam as chances de adoção',
                  style: AppTextStyles.bodySmall(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 210,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _selectedImageBytes != null
                    ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                    : PetImage(url: _existingImageUrl),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Trocar foto',
                      icon: const Icon(
                        Icons.photo_camera_outlined,
                        color: AppColors.primary,
                      ),
                      onPressed: isLoading ? null : _showImageSourceSheet,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        TextButton.icon(
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: isLoading
              ? null
              : () {
                  setState(() {
                    _selectedImageBytes = null;
                    _selectedImageFileName = null;
                    _existingImageUrl = null;
                  });
                },
          label: const Text('Remover foto'),
        ),
      ],
    );
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tirar foto'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Escolher da galeria'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeciesOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _SpeciesOption({
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceLight,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.label(
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withAlpha(110)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(20),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 7), paint);
        distance += 13;
      }
    }
    canvas.drawRRect(
      rrect,
      Paint()..color = AppColors.primarySoft.withAlpha(90),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
