import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/formatters/phone_input_formatter.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_input_decoration.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../controllers/pet_lost_controller.dart';
import '../../domain/pet_lost_entity.dart';
import '../widgets/pet_widgets.dart';

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

  // Etapa atual do formulário (0 = pet, 1 = localização, 2 = finalizar)
  int _step = 0;
  static const _stepTitles = ['Pet', 'Localização', 'Finalizar'];

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
        // O mapa pode ainda não ter sido desenhado neste frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _mapController.move(_selectedLocation!, 15.0);
          } catch (_) {}
        });
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
          _existingImageUrl = null; // substitui URL existente
        });
      }
    } catch (e) {
      _showErrorDialog(context, ['Erro ao selecionar imagem.']);
    }
  }

  Future<String?> _uploadImageIfNeeded() async {
    // Se já havia uma URL e não foi selecionada nova imagem, mantém a URL (edição)
    if (_selectedImageBytes == null &&
        _existingImageUrl != null &&
        _existingImageUrl!.isNotEmpty) {
      return _existingImageUrl;
    }

    // Se não há imagem selecionada e nem URL existente, retorna null (imagem obrigatória será tratada depois)
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
          backgroundColor: AppColors.error,
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

    // Upload da imagem (se necessário)
    final imageUrl = await _uploadImageIfNeeded();
    if (imageUrl == null) {
      // Se havia imagem selecionada mas o upload falhou, já mostramos erro.
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

    final isEditing = widget.alertId != null;
    final isLastStep = _step == _stepTitles.length - 1;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: _step == 0 ? 'Fechar' : 'Etapa anterior',
          onPressed: () {
            if (_step > 0) {
              setState(() => _step--);
            } else {
              context.pop();
            }
          },
        ),
        title: Text(isEditing ? 'Editar alerta' : 'Registrar pet perdido'),
      ),
      body: isLoading && !_controllersInitialized && isEditing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 4, 28, 8),
                  child: _StepIndicator(current: _step, titles: _stepTitles),
                ),
                Expanded(
                  child: Form(
                    key: _formKey,
                    // IndexedStack mantém o estado (mapa, campos) entre as etapas
                    child: IndexedStack(
                      index: _step,
                      children: [
                        _buildPetStep(isLoading),
                        _buildLocationStep(isLoading),
                        _buildFinishStep(isLoading),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: isLoading
              ? const SizedBox(
                  height: 52,
                  child: Center(child: CircularProgressIndicator()),
                )
              : ElevatedButton(
                  onPressed: isLastStep
                      ? _submitForm
                      : () => setState(() => _step++),
                  child: Text(
                    isLastStep
                        ? (isEditing ? 'Salvar alterações' : 'Publicar alerta')
                        : 'Próximo',
                  ),
                ),
        ),
      ),
    );
  }

  Widget _stepBody(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  // --- Etapa 1: foto e informações do pet ---
  Widget _buildPetStep(bool isLoading) {
    return _stepBody([
      _buildImagePicker(isLoading),
      const SizedBox(height: 22),
      const FieldLabel('Nome do pet'),
      TextFormField(
        controller: _nameController,
        decoration: AppInputDecoration.defaultDecoration(
          labelText: '',
          hintText: 'Ex.: Mel, Bob, Luna',
        ),
        textCapitalization: TextCapitalization.words,
        enabled: !isLoading,
      ),
      const SizedBox(height: 18),
      const FieldLabel('Espécie'),
      Row(
        children: [
          for (final type in PetType.values) ...[
            Expanded(
              child: _SpeciesOption(
                label: type.label,
                selected: _selectedType == type,
                onTap: isLoading
                    ? null
                    : () => setState(() => _selectedType = type),
              ),
            ),
            if (type != PetType.values.last) const SizedBox(width: 10),
          ],
        ],
      ),
      const SizedBox(height: 18),
      const FieldLabel('Raça (opcional)'),
      TextFormField(
        controller: _breedController,
        decoration: AppInputDecoration.defaultDecoration(
          labelText: '',
          hintText: 'Ex.: SRD, Golden, Persa',
        ),
        enabled: !isLoading,
      ),
      const SizedBox(height: 18),
      const FieldLabel('Idade (opcional)'),
      TextFormField(
        controller: _ageController,
        decoration: AppInputDecoration.defaultDecoration(
          labelText: '',
          hintText: 'Ex.: 2 anos, 6 meses',
        ),
        enabled: !isLoading,
      ),
    ]);
  }

  // --- Etapa 2: onde e quando ---
  Widget _buildLocationStep(bool isLoading) {
    return _stepBody([
      const FieldLabel('Último local visto'),
      TextFormField(
        controller: _lastLocationController,
        decoration: AppInputDecoration.defaultDecoration(
          labelText: '',
          hintText: 'Ex.: Próximo à praça central, Bairro X',
          prefixIcon: const Icon(Icons.place_outlined, size: 20),
        ),
        enabled: !isLoading,
      ),
      const SizedBox(height: 18),
      const FieldLabel('Data do desaparecimento'),
      InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isLoading ? null : () => _selectDate(context),
        child: InputDecorator(
          decoration: AppInputDecoration.defaultDecoration(
            labelText: '',
            prefixIcon: const Icon(Icons.calendar_month_outlined, size: 20),
            suffixIcon: const Icon(Icons.expand_more_rounded),
          ),
          child: Text(_formatDate(_selectedDate), style: AppTextStyles.body()),
        ),
      ),
      const SizedBox(height: 22),
      Row(
        children: [
          Expanded(child: Text('Marque no mapa', style: AppTextStyles.label())),
          TextButton.icon(
            icon: const Icon(Icons.my_location_rounded, size: 18),
            label: const Text('Usar minha localização'),
            onPressed: isLoading ? null : _useCurrentLocation,
          ),
        ],
      ),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 280,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  _selectedLocation ?? const LatLng(-23.5505, -46.6333),
              initialZoom: 15.0,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedLocation = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.error,
                        size: 44,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Icon(
            _selectedLocation == null
                ? Icons.touch_app_outlined
                : Icons.check_circle_rounded,
            size: 18,
            color: _selectedLocation == null
                ? AppColors.textSecondary
                : AppColors.success,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _selectedLocation == null
                  ? 'Toque no mapa onde o pet foi visto pela última vez.'
                  : 'Local marcado: ${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
              style: AppTextStyles.bodySmall(),
            ),
          ),
        ],
      ),
    ]);
  }

  // --- Etapa 3: descrição, contato e revisão ---
  Widget _buildFinishStep(bool isLoading) {
    return _stepBody([
      const FieldLabel('Descrição'),
      TextFormField(
        controller: _descriptionController,
        decoration: AppInputDecoration.defaultDecoration(
          labelText: '',
          hintText: 'Cor, coleira, comportamento, como sumiu…',
          helperText: 'Entre 10 e 255 caracteres.',
        ),
        maxLines: 4,
        maxLength: 255,
        enabled: !isLoading,
      ),
      const SizedBox(height: 10),
      const FieldLabel('Telefone para contato'),
      TextFormField(
        controller: _contactController,
        decoration: AppInputDecoration.defaultDecoration(
          labelText: '',
          hintText: '(11) 99999-9999',
          prefixIcon: const Icon(Icons.phone_outlined, size: 20),
        ),
        keyboardType: TextInputType.phone,
        inputFormatters: [PhoneInputFormatter()],
        enabled: !isLoading,
      ),
      const SizedBox(height: 24),
      Text('Revise antes de publicar', style: AppTextStyles.sectionHeader()),
      const SizedBox(height: 10),
      _ReviewCard(
        imageBytes: _selectedImageBytes,
        imageUrl: _existingImageUrl,
        name: _nameController.text.trim().isEmpty
            ? 'Sem nome'
            : _nameController.text.trim(),
        subtitle: [
          _selectedType.label,
          if (_breedController.text.trim().isNotEmpty)
            _breedController.text.trim(),
        ].join(' • '),
        location: _lastLocationController.text.trim().isEmpty
            ? 'Local não informado'
            : _lastLocationController.text.trim(),
        date: _formatDate(_selectedDate),
        hasPin: _selectedLocation != null,
        onEditStep: (step) => setState(() => _step = step),
      ),
    ]);
  }

  Widget _buildImagePicker(bool isLoading) {
    final hasPreview =
        _selectedImageBytes != null ||
        (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);

    if (!hasPreview) {
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isLoading ? null : () => _showImageSourceSheet(),
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
                Text(
                  'Adicione uma foto do seu pet',
                  style: AppTextStyles.label(),
                ),
                const SizedBox(height: 2),
                Text(
                  'Prefira fotos nítidas e recentes',
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

/// Indicador de etapas: círculos numerados ligados por uma linha.
class _StepIndicator extends StatelessWidget {
  final int current;
  final List<String> titles;

  const _StepIndicator({required this.current, required this.titles});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < titles.length; i++) ...[
          // Largura fixa para os círculos ficarem igualmente espaçados
          SizedBox(
            width: 78,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: i <= current
                        ? AppColors.primary
                        : AppColors.surfaceLight,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: i <= current
                          ? AppColors.primary
                          : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: i < current
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : Text(
                          '${i + 1}',
                          style: AppTextStyles.label(
                            color: i == current
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  titles[i],
                  style:
                      AppTextStyles.bodySmall(
                        color: i == current
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ).copyWith(
                        fontWeight: i == current
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          if (i < titles.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(top: 14),
                color: i < current ? AppColors.primary : AppColors.border,
              ),
            ),
        ],
      ],
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

class _ReviewCard extends StatelessWidget {
  final Uint8List? imageBytes;
  final String? imageUrl;
  final String name;
  final String subtitle;
  final String location;
  final String date;
  final bool hasPin;
  final ValueChanged<int> onEditStep;

  const _ReviewCard({
    required this.imageBytes,
    required this.imageUrl,
    required this.name,
    required this.subtitle,
    required this.location,
    required this.date,
    required this.hasPin,
    required this.onEditStep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox.square(
                  dimension: 64,
                  child: imageBytes != null
                      ? Image.memory(imageBytes!, fit: BoxFit.cover)
                      : PetImage(url: imageUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.heading3()),
                    Text(subtitle, style: AppTextStyles.bodySmall()),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => onEditStep(0),
                child: const Text('Editar'),
              ),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(location, style: AppTextStyles.body()),
                    Text(
                      '$date • ${hasPin ? 'local marcado no mapa' : 'falta marcar no mapa'}',
                      style: AppTextStyles.bodySmall(
                        color: hasPin
                            ? AppColors.textSecondary
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => onEditStep(1),
                child: const Text('Editar'),
              ),
            ],
          ),
        ],
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
