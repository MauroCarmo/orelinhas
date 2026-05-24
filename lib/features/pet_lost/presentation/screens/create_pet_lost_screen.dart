import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/formatters/phone_input_formatter.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../controllers/pet_lost_controller.dart';
import '../../domain/pet_lost_entity.dart';

class CreatePetLostScreen extends ConsumerStatefulWidget {
  final String? alertId;

  const CreatePetLostScreen({
    super.key,
    this.alertId,
  });

  @override
  ConsumerState<CreatePetLostScreen> createState() => _CreatePetLostScreenState();
}

class _CreatePetLostScreenState extends ConsumerState<CreatePetLostScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _breedController;
  late TextEditingController _ageController;
  late TextEditingController _descriptionController;
  late TextEditingController _lastLocationController;
  late TextEditingController _contactController;
  late TextEditingController _imageUrlController;

  PetType _selectedType = PetType.dog;
  DateTime _selectedDate = DateTime.now();
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _breedController = TextEditingController();
    _ageController = TextEditingController();
    _descriptionController = TextEditingController();
    _lastLocationController = TextEditingController();
    _contactController = TextEditingController();
    _imageUrlController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _descriptionController.dispose();
    _lastLocationController.dispose();
    _contactController.dispose();
    _imageUrlController.dispose();
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
      _imageUrlController.text = alert.imageUrl ?? '';

      // Formata o telefone para exibição visual
      final rawPhone = alert.contact;
      if (rawPhone.length >= 10) {
        final ddd = rawPhone.substring(0, 2);
        if (rawPhone.length == 11) {
          _contactController.text = '($ddd) ${rawPhone.substring(2, 7)}-${rawPhone.substring(7)}';
        } else {
          _contactController.text = '($ddd) ${rawPhone.substring(2, 6)}-${rawPhone.substring(6)}';
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
                .map((err) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(child: Text(err)),
                        ],
                      ),
                    ))
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

  Future<void> _submitForm() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não autenticado.'), backgroundColor: Colors.red),
      );
      return;
    }

    // Instancia a Entidade com valores brutos dos campos de input (Domínio)
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
      imageUrl: _imageUrlController.text,
    );

    // Validação estrita acumulativa a nível de domínio (Única Fonte de Validação)
    final errors = tempEntity.validate();
    if (errors.isNotEmpty) {
      _showErrorDialog(context, errors);
      return;
    }

    // Se estiver válido, despacha para o controller
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

    // Escuta reativamente as mudanças de estado para pop/erro
    ref.listen<AsyncValue<List<PetLostAlertEntity>>>(
      petLostControllerProvider,
      (previous, next) {
        if (previous is AsyncLoading && next is AsyncData) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.alertId != null
                  ? 'Alerta atualizado com sucesso!'
                  : 'Alerta registrado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        } else if (next is AsyncError) {
          final err = next.error;
          final errMsg = err is AppException ? err.message : 'Erro ao salvar alerta.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
          );
        }
      },
    );

    // Se for modo de edição, busca os dados existentes
    if (widget.alertId != null) {
      controllerState.maybeWhen(
        data: (alerts) {
          try {
            final alert = alerts.firstWhere((e) => e.id == widget.alertId);
            _initializeControllers(alert);
          } catch (_) {
            // Se o alerta não foi encontrado
          }
        },
        orElse: () {},
      );
    }

    final isLoading = controllerState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.alertId != null ? 'Editar Alerta' : 'Novo Alerta de Pet'),
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 16),

                    // Campo Nome do Pet (sem TextFormField.validator!)
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Pet *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.pets),
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),

                    // Dropdown de Tipo de Pet
                    DropdownButtonFormField<PetType>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo do Pet *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: const [
                        DropdownMenuItem(value: PetType.dog, child: Text('Cachorro')),
                        DropdownMenuItem(value: PetType.cat, child: Text('Gato')),
                        DropdownMenuItem(value: PetType.other, child: Text('Outro')),
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

                    // Campo Raça
                    TextFormField(
                      controller: _breedController,
                      decoration: const InputDecoration(
                        labelText: 'Raça (Opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.pets),
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),

                    // Campo Idade
                    TextFormField(
                      controller: _ageController,
                      decoration: const InputDecoration(
                        labelText: 'Idade (Opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.hourglass_empty),
                        helperText: 'Ex: 2 anos, 6 meses',
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),

                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Detalhes do Desaparecimento',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 16),

                    // Campo Descrição
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição do ocorrido *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                        helperText: 'Mínimo de 10 caracteres. Detalhe como ele sumiu.',
                      ),
                      maxLines: 3,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),

                    // Campo Último Local
                    TextFormField(
                      controller: _lastLocationController,
                      decoration: const InputDecoration(
                        labelText: 'Último local visto *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                        helperText: 'Ex: Próximo à praça central, Bairro X',
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),

                    // Data do Desaparecimento
                    InkWell(
                      onTap: isLoading ? null : () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Data do Desaparecimento *',
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

                    // Campo Contato (Visual Formatting Mask Only)
                    TextFormField(
                      controller: _contactController,
                      decoration: const InputDecoration(
                        labelText: 'Telefone de Contato *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                        helperText: 'Ex: (11) 99999-9999',
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        PhoneInputFormatter(),
                      ],
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),

                    // Campo URL da Imagem
                    TextFormField(
                      controller: _imageUrlController,
                      decoration: const InputDecoration(
                        labelText: 'URL da Imagem do Pet (Opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.image),
                        helperText: 'Link público da imagem para ajudar na identificação.',
                      ),
                      keyboardType: TextInputType.url,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 32),

                    // Botões de Ação
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blue,
                        ),
                        onPressed: _submitForm,
                        child: Text(
                          widget.alertId != null ? 'Salvar Alterações' : 'Criar Alerta',
                          style: const TextStyle(fontSize: 16, color: Colors.white),
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
}
