import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/formatters/cep_input_formatter.dart';
import '../../../../core/formatters/phone_input_formatter.dart';
import '../../../../core/services/geocoding_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/viacep_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_button_styles.dart';
import '../../../../core/theme/widgets/app_input_decoration.dart';
import '../../../../core/validation/sanitizers.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../../pet_recognition/data/services/supabase_pet_recognition_service.dart';
import '../controllers/pet_lost_controller.dart';
import '../../domain/pet_lost_entity.dart';

class _SelectedPhotoItem {
  final Uint8List? bytes;
  final String? fileName;
  final String? existingUrl;

  const _SelectedPhotoItem({this.bytes, this.fileName, this.existingUrl});
}

class CreatePetLostScreen extends ConsumerStatefulWidget {
  final String? alertId;

  const CreatePetLostScreen({super.key, this.alertId});

  @override
  ConsumerState<CreatePetLostScreen> createState() =>
      _CreatePetLostScreenState();
}

class _CreatePetLostScreenState extends ConsumerState<CreatePetLostScreen> {
  static const int _maxPhotos = 3;

  static const List<String> _brazilStates = [
    'AC',
    'AL',
    'AP',
    'AM',
    'BA',
    'CE',
    'DF',
    'ES',
    'GO',
    'MA',
    'MT',
    'MS',
    'MG',
    'PA',
    'PB',
    'PR',
    'PE',
    'PI',
    'RJ',
    'RN',
    'RS',
    'RO',
    'RR',
    'SC',
    'SP',
    'SE',
    'TO',
  ];

  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _breedController;
  late TextEditingController _ageController;
  late TextEditingController _descriptionController;
  late TextEditingController _cepController;
  late TextEditingController _streetController;
  late TextEditingController _districtController;
  late TextEditingController _cityController;
  late TextEditingController _referenceController;
  late TextEditingController _contactController;

  PetType _selectedType = PetType.dog;
  String? _selectedState;
  DateTime _selectedDate = DateTime.now();
  bool _controllersInitialized = false;
  bool _isSyncingLocation = false;
  bool _isUploadingPhotos = false;

  LatLng? _selectedLocation;
  final MapController _mapController = MapController();

  final List<_SelectedPhotoItem> _photos = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _breedController = TextEditingController();
    _ageController = TextEditingController();
    _descriptionController = TextEditingController();
    _cepController = TextEditingController();
    _streetController = TextEditingController();
    _districtController = TextEditingController();
    _cityController = TextEditingController();
    _referenceController = TextEditingController();
    _contactController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _descriptionController.dispose();
    _cepController.dispose();
    _streetController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _referenceController.dispose();
    _contactController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _initializeControllers(PetLostAlertEntity alert) {
    if (_controllersInitialized) return;
    _controllersInitialized = true;

    _nameController.text = alert.petName;
    _selectedType = alert.petType;
    _breedController.text = alert.breed ?? '';
    _ageController.text = alert.age ?? '';
    _descriptionController.text =
        alert.description == 'Sem descrição adicional.'
        ? ''
        : alert.description;
    _selectedDate = alert.lostDate;

    // 1. Parse determinístico do endereço salvo
    _parseExistingLocation(alert.lastLocation);

    // 2. Normaliza e formata o telefone (suporta 10, 11 dígitos, com +55 ou já formatado)
    var digits = AppSanitizers.digitsOnly(alert.contact);
    if (digits.startsWith('55') &&
        (digits.length == 12 || digits.length == 13)) {
      digits = digits.substring(2);
    }
    if (digits.length == 11) {
      _contactController.text =
          '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
    } else if (digits.length == 10) {
      _contactController.text =
          '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    } else {
      _contactController.text = alert.contact;
    }

    // 3. Preenche imediatamente as imagens conhecidas do alerta
    _photos.clear();
    for (final url in alert.effectiveImageUrls) {
      _photos.add(_SelectedPhotoItem(existingUrl: url));
    }

    // 4. Restaura coordenadas no mapa, se existirem
    if (alert.latitude != null && alert.longitude != null) {
      _selectedLocation = LatLng(alert.latitude!, alert.longitude!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedLocation != null) {
          _mapController.move(_selectedLocation!, 15.0);
        }
      });
    }

    // 5. Busca fotos extras (2 e 3) na tabela pet_images sem jamais perder a principal
    if (alert.id.isNotEmpty) {
      ref
          .read(supabasePetRecognitionServiceProvider)
          .getPetImageUrls(alert.id)
          .then((persistedUrls) {
            if (!mounted || persistedUrls.isEmpty) return;

            final merged = <String>[
              ...alert.effectiveImageUrls,
              for (final u in persistedUrls)
                if (!alert.effectiveImageUrls.contains(u)) u,
            ].take(_maxPhotos).toList();

            if (merged.length > _photos.length) {
              setState(() {
                _photos
                  ..clear()
                  ..addAll(
                    merged.map((url) => _SelectedPhotoItem(existingUrl: url)),
                  );
              });
            }
          });
    }
  }

  void _parseExistingLocation(String rawLocation) {
    final trimmed = rawLocation.trim();
    if (trimmed.isEmpty) return;

    // Formato estruturado determinístico ("Rua: ... | Bairro: ... | Cidade/UF: ... | CEP: ... | Ref: ...")
    if (trimmed.contains('Cidade/UF:') || trimmed.contains(' | ')) {
      for (final part in trimmed.split(' | ')) {
        final item = part.trim();
        if (item.startsWith('Rua:')) {
          _streetController.text = item.substring(4).trim();
        } else if (item.startsWith('Bairro:')) {
          _districtController.text = item.substring(7).trim();
        } else if (item.startsWith('Cidade/UF:')) {
          final cityUf = item.substring(10).trim();
          final slashIdx = cityUf.lastIndexOf('/');
          if (slashIdx != -1) {
            _cityController.text = cityUf.substring(0, slashIdx).trim();
            final uf = cityUf.substring(slashIdx + 1).trim().toUpperCase();
            if (_brazilStates.contains(uf)) _selectedState = uf;
          } else if (_brazilStates.contains(cityUf.toUpperCase())) {
            _selectedState = cityUf.toUpperCase();
          } else {
            _cityController.text = cityUf;
          }
        } else if (item.startsWith('CEP:')) {
          final digits = AppSanitizers.digitsOnly(item.substring(4));
          if (digits.length == 8) {
            _cepController.text =
                '${digits.substring(0, 5)}-${digits.substring(5)}';
          }
        } else if (item.startsWith('Ref:')) {
          _referenceController.text = item.substring(4).trim();
        }
      }
      return;
    }

    // Fallback para registros legados (ex.: "SP" puro ou texto livre antigo)
    if (_brazilStates.contains(trimmed.toUpperCase())) {
      _selectedState = trimmed.toUpperCase();
    } else {
      _referenceController.text = trimmed;
    }
  }

  /// CEP -> Preenche campos via ViaCEP e sincroniza pino no mapa via GeocodingService.
  Future<void> _lookupCepAndSyncMap([String? value]) async {
    final digits = AppSanitizers.digitsOnly(value ?? _cepController.text);
    if (digits.length != 8 || _isSyncingLocation) return;

    setState(() => _isSyncingLocation = true);
    try {
      final viaCep = ref.read(viaCepServiceProvider);
      final geocoding = ref.read(geocodingServiceProvider);

      final data = await viaCep.fetchAddress(digits);
      if (!mounted) return;

      final street = data['street'] ?? '';
      final district = data['district'] ?? '';
      final city = data['city'] ?? '';
      final uf = (data['state'] ?? '').toUpperCase();

      setState(() {
        if (street.isNotEmpty) _streetController.text = street;
        if (district.isNotEmpty) _districtController.text = district;
        if (city.isNotEmpty) _cityController.text = city;
        if (_brazilStates.contains(uf)) _selectedState = uf;
      });

      final coords = await geocoding.forwardGeocode(
        street: street,
        district: district,
        city: city,
        stateUf: uf,
        cep: digits,
      );

      if (!mounted) return;
      if (coords != null) {
        setState(() {
          _selectedLocation = coords;
        });
        _mapController.move(coords, 16.0);
      }
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncingLocation = false);
      }
    }
  }

  /// Campos de endereço escritos -> Sincroniza pino no mapa.
  Future<void> _syncMapFromAddressFields() async {
    if (_isSyncingLocation) return;

    final street = _streetController.text.trim();
    final district = _districtController.text.trim();
    final city = _cityController.text.trim();
    final uf = _selectedState ?? '';
    final cep = _cepController.text.trim();

    if (street.isEmpty && city.isEmpty && cep.isEmpty) {
      _showErrorDialog(context, [
        'Preencha ao menos o CEP, ou Cidade/Rua para localizar no mapa.',
      ]);
      return;
    }

    setState(() => _isSyncingLocation = true);
    try {
      final geocoding = ref.read(geocodingServiceProvider);
      final coords = await geocoding.forwardGeocode(
        street: street,
        district: district,
        city: city,
        stateUf: uf,
        cep: cep,
      );

      if (!mounted) return;
      if (coords != null) {
        setState(() {
          _selectedLocation = coords;
        });
        _mapController.move(coords, 16.0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível localizar esse endereço no mapa. Você pode marcar manualmente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingLocation = false);
      }
    }
  }

  /// Mapa / GPS -> Preenche automaticamente CEP e campos de endereço via geocodificação reversa.
  Future<void> _syncAddressFromCoordinates(LatLng point) async {
    setState(() {
      _selectedLocation = point;
      _isSyncingLocation = true;
    });

    try {
      final geocoding = ref.read(geocodingServiceProvider);
      final result = await geocoding.reverseGeocode(point);
      if (!mounted || result == null) return;

      setState(() {
        if (result.cep != null && result.cep!.isNotEmpty) {
          _cepController.text = result.cep!;
        }
        if (result.street != null && result.street!.isNotEmpty) {
          _streetController.text = result.street!;
        }
        if (result.district != null && result.district!.isNotEmpty) {
          _districtController.text = result.district!;
        }
        if (result.city != null && result.city!.isNotEmpty) {
          _cityController.text = result.city!;
        }
        if (result.stateUf != null && _brazilStates.contains(result.stateUf)) {
          _selectedState = result.stateUf;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isSyncingLocation = false);
      }
    }
  }

  String _composeFullLocation() {
    final street = _streetController.text.trim();
    final district = _districtController.text.trim();
    final city = _cityController.text.trim();
    final state = (_selectedState ?? '').trim();
    final reference = _referenceController.text.trim();
    final cepDigits = AppSanitizers.digitsOnly(_cepController.text);

    final parts = <String>[];
    if (street.isNotEmpty) parts.add('Rua: $street');
    if (district.isNotEmpty) parts.add('Bairro: $district');

    final cityState = [
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
    ].join('/');
    if (cityState.isNotEmpty) {
      parts.add('Cidade/UF: $cityState');
    }

    if (cepDigits.length == 8) {
      parts.add('CEP: ${cepDigits.substring(0, 5)}-${cepDigits.substring(5)}');
    }

    if (reference.isNotEmpty) {
      parts.add('Ref: $reference');
    }

    return parts.join(' | ');
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
                        const Text(
                          '• ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
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
      final point = LatLng(position.latitude, position.longitude);
      _mapController.move(point, 16.0);
      await _syncAddressFromCoordinates(point);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(context, [
        'Não foi possível obter a localização atual.',
      ]);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) {
      _showErrorDialog(context, [
        'Você já selecionou o máximo de $_maxPhotos fotos.',
      ]);
      return;
    }

    try {
      if (source == ImageSource.gallery && remaining > 1) {
        final List<XFile> images = await _picker.pickMultiImage(
          imageQuality: 85,
          limit: remaining,
        );
        if (images.isEmpty) return;

        final added = <_SelectedPhotoItem>[];
        for (final img in images.take(remaining)) {
          final bytes = await img.readAsBytes();
          added.add(_SelectedPhotoItem(bytes: bytes, fileName: img.name));
        }

        if (!mounted) return;
        setState(() {
          _photos.addAll(added);
        });
      } else {
        final XFile? image = await _picker.pickImage(
          source: source,
          imageQuality: 85,
          preferredCameraDevice: CameraDevice.rear,
        );
        if (image != null) {
          final bytes = await image.readAsBytes();
          if (!mounted) return;
          setState(() {
            _photos.add(_SelectedPhotoItem(bytes: bytes, fileName: image.name));
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(context, [
        'Não foi possível acessar a câmera ou galeria.',
      ]);
    }
  }

  Future<List<String>?> _uploadAllPhotos() async {
    if (_photos.isEmpty) return null;

    final user = ref.read(currentUserProvider);
    final storageService = ref.read(storageServiceProvider);
    final uploadedUrls = <String>[];

    setState(() => _isUploadingPhotos = true);
    try {
      for (int i = 0; i < _photos.length; i++) {
        final item = _photos[i];
        if (item.existingUrl != null && item.existingUrl!.isNotEmpty) {
          uploadedUrls.add(item.existingUrl!);
        } else if (item.bytes != null) {
          final url = await storageService.uploadImage(
            bytes: item.bytes!,
            fileName: item.fileName ?? 'pet_photo_${i + 1}.jpg',
            bucket: 'pet_images',
            folder: user?.id,
          );
          uploadedUrls.add(url);
        }
      }
      return uploadedUrls;
    } on ValidationException catch (e) {
      if (!mounted) return null;
      _showErrorDialog(context, [e.message]);
      return null;
    } catch (e) {
      if (!mounted) return null;
      _showErrorDialog(context, [
        'Falha ao enviar uma ou mais fotos. Tente novamente.',
      ]);
      return null;
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhotos = false);
      }
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

    final preErrors = <String>[];
    if (_cityController.text.trim().isEmpty) {
      preErrors.add('A Cidade é obrigatória.');
    }
    if (_selectedState == null || _selectedState!.isEmpty) {
      preErrors.add('O Estado (UF) é obrigatório.');
    }
    if (_photos.isEmpty) {
      preErrors.add('Pelo menos 1 foto do pet é obrigatória.');
    }
    if (preErrors.isNotEmpty) {
      _showErrorDialog(context, preErrors);
      return;
    }

    final uploadedUrls = await _uploadAllPhotos();
    if (!mounted) return;
    if (uploadedUrls == null || uploadedUrls.isEmpty) {
      return;
    }

    final fullLocation = _composeFullLocation();

    final tempEntity = PetLostAlertEntity(
      id: widget.alertId ?? '',
      userId: user.id,
      petName: _nameController.text,
      petType: _selectedType,
      breed: _breedController.text,
      age: _ageController.text,
      description: _descriptionController.text,
      lastLocation: fullLocation,
      lostDate: _selectedDate,
      contact: _contactController.text,
      imageUrl: uploadedUrls.first,
      imageUrls: uploadedUrls,
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

    final isLoading = controllerState.isLoading || _isUploadingPhotos;

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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
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
                              prefixIcon: const Icon(
                                Icons.pets_outlined,
                                size: 20,
                              ),
                            ),
                            enabled: !isLoading,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<PetType>(
                            initialValue: _selectedType,
                            decoration: AppInputDecoration.defaultDecoration(
                              labelText: 'Tipo do Pet *',
                              prefixIcon: const Icon(
                                Icons.category_outlined,
                                size: 20,
                              ),
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
                              prefixIcon: const Icon(
                                Icons.cruelty_free_outlined,
                                size: 20,
                              ),
                            ),
                            enabled: !isLoading,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _ageController,
                            decoration: AppInputDecoration.defaultDecoration(
                              labelText: 'Idade (Opcional)',
                              helperText: 'Ex: 2 anos, 6 meses',
                              prefixIcon: const Icon(
                                Icons.hourglass_empty_outlined,
                                size: 20,
                              ),
                            ),
                            enabled: !isLoading,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- Seção 2: Detalhes do Desaparecimento & Endereço Sincronizado ---
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
                              labelText: 'Descrição do ocorrido (Opcional)',
                              helperText:
                                  'Características, coleira, comportamento, etc.',
                              prefixIcon: const Icon(
                                Icons.notes_outlined,
                                size: 20,
                              ),
                            ),
                            maxLines: 3,
                            maxLength: 255,
                            enabled: !isLoading,
                          ),
                          const SizedBox(height: 16),

                          // CEP sincronizado com Endereço e Mapa
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _cepController,
                                  decoration: AppInputDecoration.defaultDecoration(
                                    labelText: 'CEP (Opcional)',
                                    helperText:
                                        'Preenche endereço e centraliza o mapa',
                                    prefixIcon: const Icon(
                                      Icons.markunread_mailbox_outlined,
                                      size: 20,
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [CepInputFormatter()],
                                  onChanged: (val) {
                                    if (AppSanitizers.digitsOnly(val).length ==
                                        8) {
                                      _lookupCepAndSyncMap(val);
                                    }
                                  },
                                  enabled: !isLoading,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 52,
                                child: OutlinedButton(
                                  style: AppButtonStyles.outlined(),
                                  onPressed: isLoading || _isSyncingLocation
                                      ? null
                                      : () => _lookupCepAndSyncMap(),
                                  child: _isSyncingLocation
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.search),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _streetController,
                            decoration: AppInputDecoration.defaultDecoration(
                              labelText: 'Rua / Logradouro (Opcional)',
                              prefixIcon: const Icon(
                                Icons.signpost_outlined,
                                size: 20,
                              ),
                            ),
                            enabled: !isLoading,
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _districtController,
                            decoration: AppInputDecoration.defaultDecoration(
                              labelText: 'Bairro (Opcional)',
                              prefixIcon: const Icon(
                                Icons.holiday_village_outlined,
                                size: 20,
                              ),
                            ),
                            enabled: !isLoading,
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _cityController,
                                  decoration:
                                      AppInputDecoration.defaultDecoration(
                                        labelText: 'Cidade *',
                                        prefixIcon: const Icon(
                                          Icons.location_city_outlined,
                                          size: 20,
                                        ),
                                      ),
                                  enabled: !isLoading,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedState,
                                  decoration:
                                      AppInputDecoration.defaultDecoration(
                                        labelText: 'UF *',
                                      ),
                                  items: _brazilStates
                                      .map(
                                        (uf) => DropdownMenuItem(
                                          value: uf,
                                          child: Text(uf),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: isLoading
                                      ? null
                                      : (val) {
                                          setState(() => _selectedState = val);
                                        },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _referenceController,
                            decoration: AppInputDecoration.defaultDecoration(
                              labelText:
                                  'Complemento / Ponto de referência (Opcional)',
                              helperText:
                                  'Ex: Próximo à praça central ou mercado',
                              prefixIcon: const Icon(
                                Icons.location_on_outlined,
                                size: 20,
                              ),
                            ),
                            enabled: !isLoading,
                          ),
                          const SizedBox(height: 6),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: isLoading || _isSyncingLocation
                                  ? null
                                  : _syncMapFromAddressFields,
                              icon: const Icon(
                                Icons.pin_drop_outlined,
                                size: 18,
                              ),
                              label: const Text('Localizar endereço no mapa'),
                            ),
                          ),
                          const SizedBox(height: 8),

                          InkWell(
                            onTap: isLoading
                                ? null
                                : () => _selectDate(context),
                            borderRadius: BorderRadius.circular(11),
                            child: InputDecorator(
                              decoration: AppInputDecoration.defaultDecoration(
                                labelText: 'Data do Desaparecimento *',
                                prefixIcon: const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 20,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDate(_selectedDate),
                                    style: AppTextStyles.body(),
                                  ),
                                  const Icon(
                                    Icons.calendar_month,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
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
                              prefixIcon: const Icon(
                                Icons.phone_outlined,
                                size: 20,
                              ),
                            ),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [PhoneInputFormatter()],
                            enabled: !isLoading,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.scaffoldLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.privacy_tip_outlined,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Proteção de Dados (LGPD): Seu telefone será usado exclusivamente para contato direto de pessoas que encontrarem seu pet e poderá ser removido a qualquer momento ao encerrar ou excluir o alerta.',
                                    style: AppTextStyles.bodySmall(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- Seção 3: Fotos do Pet (até 3) ---
                    Text(
                      'FOTOS DO PET (1 A 3 FOTOS) *',
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
                      child: _buildMultiImagePicker(isLoading),
                    ),
                    const SizedBox(height: 24),

                    // --- Seção 4: Localização Exata no Mapa (Sincronizada) ---
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
                            onPressed: isLoading || _isSyncingLocation
                                ? null
                                : _useCurrentLocation,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _isSyncingLocation
                                ? 'Sincronizando endereço e coordenadas...'
                                : _selectedLocation == null
                                ? 'Toque no mapa ou informe o CEP/endereço acima para fixar o pino.'
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
                                  initialCenter:
                                      _selectedLocation ??
                                      const LatLng(-23.5505, -46.6333),
                                  initialZoom: 15.0,
                                  onTap: (tapPosition, point) {
                                    if (!isLoading && !_isSyncingLocation) {
                                      _syncAddressFromCoordinates(point);
                                    }
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
                      const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
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

  Widget _buildMultiImagePicker(bool isLoading) {
    final canAddMore = _photos.length < _maxPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Adicione até $_maxPhotos fotos nítidas do pet (diferentes ângulos aumentam a precisão da IA).',
          style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _maxPhotos,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.9,
          ),
          itemBuilder: (context, index) {
            if (index < _photos.length) {
              final item = _photos[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: index == 0
                            ? AppColors.primary
                            : AppColors.border,
                        width: index == 0 ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: item.bytes != null
                          ? Image.memory(item.bytes!, fit: BoxFit.cover)
                          : Image.network(
                              item.existingUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 28,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                            ),
                    ),
                  ),
                  if (index == 0)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Principal',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: isLoading
                          ? null
                          : () {
                              setState(() {
                                _photos.removeAt(index);
                              });
                            },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return InkWell(
              onTap: isLoading ? null : () => _pickImage(ImageSource.gallery),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.scaffoldLight,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_a_photo_outlined,
                      size: 26,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Foto ${index + 1}',
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: AppButtonStyles.outlined(),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Câmera'),
                onPressed: isLoading || !canAddMore
                    ? null
                    : () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: AppButtonStyles.outlined(),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text('Galeria (${_photos.length}/$_maxPhotos)'),
                onPressed: isLoading || !canAddMore
                    ? null
                    : () => _pickImage(ImageSource.gallery),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
