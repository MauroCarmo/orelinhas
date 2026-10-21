import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/formatters/phone_input_formatter.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_button_styles.dart';
import '../../../../core/theme/widgets/app_input_decoration.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../controllers/pet_lost_controller.dart';
import '../../domain/pet_lost_entity.dart';

class CreatePetLostScreen extends ConsumerStatefulWidget {
  final String? alertId;

  const CreatePetLostScreen({super.key, this.alertId});

  @override
  ConsumerState<CreatePetLostScreen> createState() =>
      _CreatePetLostScreenState();
}

class _CreatePetLostScreenState extends ConsumerState<CreatePetLostScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _breedController;
  late TextEditingController _ageController;
  late TextEditingController _descriptionController;
  late TextEditingController _lastLocationController;
  late TextEditingController _contactController;

  PetType _selectedType = PetType.dog;
  DateTime _selectedDate = DateTime.now();
  bool _controllersInitialized = false;

  LatLng? _selectedLocation;
  final MapController _mapController = MapController();

  Uint8List? _selectedImageBytes;
  String? _selectedImageFileName;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _breedController = TextEditingController();
    _ageController = TextEditingController();
    _descriptionController = TextEditingController();
    _lastLocationController = TextEditingController();
    _contactController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _descriptionController.dispose();
    _lastLocationController.dispose();
    _contactController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _initializeControllers(PetLostAlertEntity alert) {
    if (!_controllersInitialized) {
      _nameController.text = alert.petName;
      _selectedType = alert.petType;
      _breedController.text = alert.breed ?? '';
      _ageController.text = alert.age ?? '';
      _descriptionController.text = alert.description;
      _lastLocationController.text = alert.lastLocation;
      _selectedDate = alert.lostDate;
      _existingImageUrl = alert.imageUrl;

      if (alert.latitude != null && alert.longitude != null) {
        _selectedLocation = LatLng(alert.latitude!, alert.longitude!);
        _mapController.move(_selectedLocation!, 15.0);
      }

      final rawPhone = alert.contact;
      if (rawPhone.length >= 10) {
        final ddd = rawPhone.substring(0, 2);
        if (rawPhone.length == 11) {
          _contactController.text =
              '($ddd) ${rawPhone.substring(2, 7)}-${rawPhone.substring(7)}';
        } else {
          _contactController.text =
              '($ddd) ${rawPhone.substring(2, 6)}-${rawPhone.substring(6)}';
        }
      } else {
        _contactController.text = rawPhone;
      }

      _controllersInitialized = true;
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.accent,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showErrorDialog(BuildContext context, List<String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Text('Erros de Validação', style: AppTextStyles.heading3()),
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
                        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text(err, style: AppTextStyles.body())),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          ElevatedButton(
            style: AppButtonStyles.primary(),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
        if (permission == LocationPermission.denied) {
          _showErrorDialog(context, [
            'Permissão de localização negada. Você pode definir a localização manualmente no mapa.',
          ]);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorDialog(context, [
          'Permissão de localização permanentemente negada. Ative nas configurações do dispositivo.',
        ]);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _mapController.move(_selectedLocation!, 15.0);
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(context, [
        'Não foi possível obter a localização atual.',
      ]);
    }
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
        fileName: _selectedImageFileName ?? 'image.jpg',
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

    final imageUrl = await _uploadImageIfNeeded();
    if (!mounted) return;
    if (imageUrl == null) {
      return;
    }

    final tempEntity = PetLostAlertEntity(
      id: widget.alertId ?? '',
      userId: user.id,
      petName: _nameController.text,
      petType: _selectedType,
      breed: _breedController.text,
      age: _ageController.text,
      description: _descriptionController.text,
      lastLocation: _lastLocationController.text,
      lostDate: _selectedDate,
      contact: _contactController.text,
      imageUrl: imageUrl,
      latitude: _selectedLocation?.latitude,
      longitude: _selectedLocation?.longitude,
    );

    final errors = tempEntity.validate();
    if (errors.isNotEmpty) {
      _showErrorDialog(context, errors);
      return;
    }

    final controller = ref.read(petLostControllerProvider.notifier);
    if (widget.alertId != null) {
      await controller.updateAlert(tempEntity.copyWith(id: widget.alertId));
    } else {
      await controller.createAlert(tempEntity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(petLostControllerProvider);

    ref.listen<AsyncValue<List<PetLostAlertEntity>>>(
      petLostControllerProvider,
      (previous, next) {
        if (previous is AsyncLoading && next is AsyncData) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.alertId != null
                    ? 'Alerta atualizado com sucesso!'
                    : 'Alerta registrado com sucesso!',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        } else if (next is AsyncError) {
          final err = next.error;
          final errMsg = err is AppException
              ? err.message
              : 'Erro ao salvar alerta.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errMsg), backgroundColor: AppColors.error),
          );
        }
      },
    );

    if (widget.alertId != null) {
      controllerState.maybeWhen(
        data: (alerts) {
          try {
            final alert = alerts.firstWhere((e) => e.id == widget.alertId);
            _initializeControllers(alert);
          } catch (_) {}
        },
        orElse: () {},
      );
    }

    final isLoading = controllerState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.scaffoldLight,
      appBar: AppBar(
        title: Text(
          widget.alertId != null ? 'Editar Alerta' : 'Novo Alerta de Pet',
          style: AppTextStyles.heading2(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading && !_controllersInitialized && widget.alertId != null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Seção 1: Informações do Pet ---
                    Text(
                      'INFORMAÇÕES DO PET',
                      style: AppTextStyles.sectionHeader(),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: AppInputDecoration.defaultDecoration(
                              labelText: 'Nome do Pet *',
                              prefixIcon: const Icon(Icons.pets_outlined, size: 20),
                            ),
                            enabled: !isLoading,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<PetType>(
                            initialValue: _selectedType,
                            decoration: AppInputDecoration.defaultDecoration(
                              labelText: 'Tipo do Pet *',
                              prefixIcon: const Icon(Icons.category_outlined, size: 20),
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
                                        _selectedType = val;
                                      });
                                    }
                                  },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _breedController,
                            decoration: AppInputDecoration.defaultDecoration(
                              labelText: 'Raça (Opcional)',
                              prefixIcon: const Icon(Icons.cruelty_free_outlined, size: 20),
                            ),
                            enabled: !isLoading,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _ageController,
                            decoration: AppInputDecoration.defaultDecoration(
                              labelText: 'Idade (Opcional)',
                              helperText: 'Ex: 2 anos, 6 meses',
                              prefixIcon: const Icon(Icons.hourglass_empty_outlined, size: 20),
                            ),
                            enabled: !isLoading,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- Seção 2: Detalhes do Desaparecimento ---
                    Text(
                      'DETALHES DO DESAPARECIMENTO',
                      style: AppTextStyles.sectionHeader(),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _descriptionController,
                            decoration: AppInputDecoration.defaultDecoration(
                              labelText: 'Descrição do ocorrido *',
                              helperText: 'Mínimo de 10 caracteres, máximo 255.',
                              prefixIcon: const Icon(Icons.notes_outlined, size: 20),
                            ),
                            maxLines: 3,
                            maxLength: 255,
                            enabled: !isLoading,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _lastLocationController,
                            decoration: AppInputDecoration.defaultDecoration(
                              labelText: 'Último local visto *',
                              helperText: 'Ex: Próximo à praça central, Bairro X',
                              prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                            ),
                            enabled: !isLoading,
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: isLoading ? null : () => _selectDate(context),
                            borderRadius: BorderRadius.circular(11),
                            child: InputDecorator(
                              decoration: AppInputDecoration.defaultDecoration(
                                labelText: 'Data do Desaparecimento *',
                                prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDate(_selectedDate),
                                    style: AppTextStyles.body(),
                                  ),
                                  const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _contactController,
                            decoration: AppInputDecoration.defaultDecoration(
                              labelText: 'Telefone de Contato *',
                              helperText: 'Ex: (11) 99999-9999',
                              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                            ),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [PhoneInputFormatter()],
                            enabled: !isLoading,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- Seção 3: Foto do Pet ---
                    Text(
                      'FOTO DO PET *',
                      style: AppTextStyles.sectionHeader(),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: _buildImagePicker(isLoading),
                    ),
                    const SizedBox(height: 24),

                    // --- Seção 4: Localização Exata no Mapa ---
                    Text(
                      'LOCALIZAÇÃO NO MAPA (OPCIONAL)',
                      style: AppTextStyles.sectionHeader(),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            style: AppButtonStyles.outlined(),
                            icon: const Icon(Icons.my_location, size: 18),
                            label: const Text('Usar minha localização atual'),
                            onPressed: isLoading ? null : _useCurrentLocation,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _selectedLocation == null
                                ? 'Nenhuma coordenada fixada no mapa.'
                                : 'Coordenadas: ${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                            style: AppTextStyles.bodySmall(
                              color: _selectedLocation == null
                                  ? AppColors.textSecondary
                                  : AppColors.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 260,
                              child: FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: _selectedLocation ??
                                      const LatLng(-23.5505, -46.6333),
                                  initialZoom: 15.0,
                                  onTap: (tapPosition, point) {
                                    setState(() {
                                      _selectedLocation = point;
                                    });
                                  },
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.example.app',
                                  ),
                                  if (_selectedLocation != null)
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: _selectedLocation!,
                                          width: 40,
                                          height: 40,
                                          child: const Icon(
                                            Icons.location_on,
                                            color: AppColors.error,
                                            size: 40,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- Ações de Submissão ---
                    if (isLoading)
                      const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    else ...[
                      ElevatedButton(
                        style: AppButtonStyles.primary(),
                        onPressed: _submitForm,
                        child: Text(
                          widget.alertId != null
                              ? 'Salvar Alterações'
                              : 'Cadastrar Alerta',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        style: AppButtonStyles.outlined(),
                        onPressed: () => context.pop(),
                        child: const Text('Cancelar'),
                      ),
                    ],
                    const SizedBox(height: 24),
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
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
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
                          const Center(child: Icon(Icons.broken_image, size: 40, color: AppColors.textSecondary)),
                    ),
            ),
          )
        else
          Container(
            height: 120,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.scaffoldLight,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.textSecondary),
                const SizedBox(height: 6),
                Text('Nenhuma foto selecionada', style: AppTextStyles.bodySmall()),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: AppButtonStyles.outlined(),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Câmera'),
                onPressed: isLoading ? null : () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: AppButtonStyles.outlined(),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Galeria'),
                onPressed: isLoading ? null : () => _pickImage(ImageSource.gallery),
              ),
            ),
          ],
        ),
        if (hasPreview) ...[
          const SizedBox(height: 8),
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
            child: Text('Remover foto', style: AppTextStyles.bodySmall(color: AppColors.error)),
          ),
        ],
      ],
    );
  }
}
