import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../controllers/pet_adoption_controller.dart';
import '../../domain/pet_adoption_entity.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart' show PetType;

class CreatePetAdoptionScreen extends ConsumerStatefulWidget {
  final String? alertId;

  const CreatePetAdoptionScreen({super.key, this.alertId});

  @override
  ConsumerState<CreatePetAdoptionScreen> createState() =>
      _CreatePetAdoptionScreenState();
}

class _CreatePetAdoptionScreenState extends ConsumerState<CreatePetAdoptionScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _characteristicsController;
  late TextEditingController _regionController;

  PetType _selectedSpecies = PetType.dog;
  bool _isVaccinated = false;
  bool _controllersInitialized = false;

  // Imagem
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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _characteristicsController.dispose();
    _regionController.dispose();
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
      _controllersInitialized = true;
    }
  }

  void _showErrorDialog(BuildContext context, List<String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Erros de Validação'),
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
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageFileName = image.name;
          _existingImageUrl = null;
        });
      }
    } catch (e) {
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
      _showErrorDialog(context, [e.message]);
      return null;
    } catch (e) {
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
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validação prévia: imagem obrigatória
    if (_selectedImageBytes == null &&
        (_existingImageUrl == null || _existingImageUrl!.isEmpty)) {
      _showErrorDialog(context, ['A foto do pet é obrigatória.']);
      return;
    }

    final imageUrl = await _uploadImageIfNeeded();
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
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        } else if (next is AsyncError) {
          final err = next.error;
          final errMsg = err is AppException
              ? err.message
              : 'Erro ao salvar anúncio.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
          );
        }
      },
    );

    if (widget.alertId != null) {
      controllerState.maybeWhen(
        data: (adoptions) {
          try {
            final adoption = adoptions.firstWhere((e) => e.id == widget.alertId);
            _initializeControllers(adoption);
          } catch (_) {}
        },
        orElse: () {},
      );
    }

    final isLoading = controllerState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.alertId != null ? 'Editar Anúncio' : 'Cadastrar Pet para Adoção',
        ),
      ),
      body: isLoading && !_controllersInitialized && widget.alertId != null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Informações do Pet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Pet *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<PetType>(
                      value: _selectedSpecies,
                      decoration: const InputDecoration(
                        labelText: 'Espécie *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: PetType.dog,
                          child: Text('Cachorro'),
                        ),
                        DropdownMenuItem(
                          value: PetType.cat,
                          child: Text('Gato'),
                        ),
                        DropdownMenuItem(
                          value: PetType.other,
                          child: Text('Outro'),
                        ),
                      ],
                      onChanged: isLoading
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedSpecies = val;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _characteristicsController,
                      decoration: const InputDecoration(
                        labelText: 'Características Detalhadas *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                        helperText: 'Ex: Brincalhão, dócil com crianças. Mínimo 10 carac.',
                      ),
                      maxLines: 3,
                      maxLength: 255,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _regionController,
                      decoration: const InputDecoration(
                        labelText: 'Região / Cidade *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                        helperText: 'Ex: São Paulo, Zona Sul ou Vila Mariana',
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Status de Vacinação'),
                      subtitle: const Text('O pet está vacinado?'),
                      value: _isVaccinated,
                      onChanged: isLoading
                          ? null
                          : (val) {
                              setState(() {
                                _isVaccinated = val;
                              });
                            },
                      secondary: const Icon(Icons.health_and_safety),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Foto do Pet *',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildImagePicker(isLoading),
                    const SizedBox(height: 32),

                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green,
                        ),
                        onPressed: _submitForm,
                        child: Text(
                          widget.alertId != null
                              ? 'Salvar Alterações'
                              : 'Cadastrar para Adoção',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => context.pop(),
                        child: const Text('Cancelar'),
                      ),
                    ],
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

    return Column(
      children: [
        if (hasPreview)
          Container(
            height: 200,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: _selectedImageBytes != null
                  ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                  : Image.network(
                      _existingImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image),
                    ),
            ),
          )
        else
          Container(
            height: 120,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.add_a_photo, size: 48, color: Colors.grey),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Câmera'),
              onPressed: isLoading
                  ? null
                  : () => _pickImage(ImageSource.camera),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Galeria'),
              onPressed: isLoading
                  ? null
                  : () => _pickImage(ImageSource.gallery),
            ),
          ],
        ),
        if (hasPreview)
          TextButton(
            onPressed: isLoading
                ? null
                : () {
                    setState(() {
                      _selectedImageBytes = null;
                      _selectedImageFileName = null;
                      _existingImageUrl = null;
                    });
                  },
            child: const Text('Remover imagem'),
          ),
      ],
    );
  }
}
