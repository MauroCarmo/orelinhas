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
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../controllers/pet_found_controller.dart';
import '../../domain/pet_found_entity.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart' show PetType;

class CreatePetFoundScreen extends ConsumerStatefulWidget {
  final String? alertId;

  const CreatePetFoundScreen({super.key, this.alertId});

  @override
  ConsumerState<CreatePetFoundScreen> createState() =>
      _CreatePetFoundScreenState();
}

class _CreatePetFoundScreenState extends ConsumerState<CreatePetFoundScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _breedController;
  late TextEditingController _apparentAgeController;
  late TextEditingController _descriptionController;
  late TextEditingController _foundLocationController;
  late TextEditingController _contactController;

  PetType _selectedType = PetType.dog;
  DateTime _selectedDate = DateTime.now();
  bool _controllersInitialized = false;

  // Coordenadas selecionadas no mapa
  LatLng? _selectedLocation;
  final MapController _mapController = MapController();

  // Imagem (compatível com mobile e web)
  Uint8List? _selectedImageBytes;
  String? _selectedImageFileName; // Nome original do arquivo
  String? _existingImageUrl; // URL carregada ao editar
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _breedController = TextEditingController();
    _apparentAgeController = TextEditingController();
    _descriptionController = TextEditingController();
    _foundLocationController = TextEditingController();
    _contactController = TextEditingController();
  }

  @override
  void dispose() {
    _breedController.dispose();
    _apparentAgeController.dispose();
    _descriptionController.dispose();
    _foundLocationController.dispose();
    _contactController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _initializeControllers(PetFoundAlertEntity alert) {
    if (!_controllersInitialized) {
      _selectedType = alert.petType;
      _breedController.text = alert.breed ?? '';
      _apparentAgeController.text = alert.apparentAge ?? '';
      _descriptionController.text = alert.description;
      _foundLocationController.text = alert.foundLocation;
      _selectedDate = alert.foundDate;
      _existingImageUrl = alert.imageUrl;

      if (alert.latitude != null && alert.longitude != null) {
        _selectedLocation = LatLng(alert.latitude!, alert.longitude!);
        _mapController.move(_selectedLocation!, 15.0);
      }

      final rawPhone = alert.contact ?? '';
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

  Future<void> _useCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
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

      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _mapController.move(_selectedLocation!, 15.0);
      });
    } catch (e) {
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
        fileName: _selectedImageFileName ?? 'image.jpg',
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

    final tempEntity = PetFoundAlertEntity(
      id: widget.alertId ?? '',
      userId: user.id,
      petType: _selectedType,
      breed: _breedController.text.isNotEmpty ? _breedController.text : null,
      apparentAge: _apparentAgeController.text.isNotEmpty ? _apparentAgeController.text : null,
      description: _descriptionController.text,
      foundLocation: _foundLocationController.text,
      foundDate: _selectedDate,
      contact: _contactController.text.isNotEmpty ? _contactController.text : null,
      imageUrl: imageUrl,
      latitude: _selectedLocation?.latitude,
      longitude: _selectedLocation?.longitude,
    );

    final errors = tempEntity.validate();
    if (errors.isNotEmpty) {
      _showErrorDialog(context, errors);
      return;
    }

    final controller = ref.read(petFoundControllerProvider.notifier);
    if (widget.alertId != null) {
      await controller.updateAlert(tempEntity.copyWith(id: widget.alertId));
    } else {
      await controller.createAlert(tempEntity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(petFoundControllerProvider);

    ref.listen<AsyncValue<List<PetFoundAlertEntity>>>(
      petFoundControllerProvider,
      (previous, next) {
        if (previous is AsyncLoading && next is AsyncData) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.alertId != null
                    ? 'Registro atualizado com sucesso!'
                    : 'Pet Encontrado cadastrado com sucesso!',
              ),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        } else if (next is AsyncError) {
          final err = next.error;
          final errMsg = err is AppException
              ? err.message
              : 'Erro ao salvar registro.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
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
      appBar: AppBar(
        title: Text(
          widget.alertId != null ? 'Editar Registro' : 'Cadastrar Pet Encontrado',
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
                    DropdownButtonFormField<PetType>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo do Pet *',
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
                                  _selectedType = val;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _breedController,
                      decoration: const InputDecoration(
                        labelText: 'Raça do Pet (Opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.pets),
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _apparentAgeController,
                      decoration: const InputDecoration(
                        labelText: 'Parece ter qual idade? (Opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.hourglass_empty),
                        helperText: 'Ex: filhote, idoso, uns 2 anos',
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Detalhes do Encontro',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Detalhes de onde foi encontrado e como ele estava *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                        helperText: 'Mínimo de 10 caracteres, máximo 255.',
                      ),
                      maxLines: 3,
                      maxLength: 255,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _foundLocationController,
                      decoration: const InputDecoration(
                        labelText: 'Último local que você o viu *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                        helperText: 'Ex: Próximo ao supermercado Y',
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: isLoading ? null : () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Data em que foi encontrado *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_month),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDate(_selectedDate)),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactController,
                      decoration: const InputDecoration(
                        labelText: 'Telefone de Contato (Opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                        helperText: 'Ex: (11) 99999-9999',
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [PhoneInputFormatter()],
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),

                    // Seção de imagem (obrigatória)
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
                    const SizedBox(height: 16),

                    // Localização no mapa
                    const Text(
                      'Localização Exata de Onde Encontrou o Pet *',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.my_location),
                      label: const Text('Usar minha localização atual'),
                      onPressed: isLoading ? null : _useCurrentLocation,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedLocation == null
                          ? 'Nenhuma localização selecionada.'
                          : 'Selecionado: ${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 300,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter:
                              _selectedLocation ??
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
                                    color: Colors.green,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
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
                              : 'Cadastrar Pet Encontrado',
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
