import '../../../core/validation/validators.dart';

enum PetType {
  dog,
  cat,
  other;

  String get name => toString().split('.').last;
}

class PetLostAlertEntity {
  final String id;
  final String userId;
  final String petName;
  final PetType petType; // Enum safety
  final String? breed;
  final String? age;
  final String description;
  final String lastLocation;
  final DateTime lostDate;
  final String contact;
  final String? imageUrl;
  final DateTime? createdAt;

  const PetLostAlertEntity({
    required this.id,
    required this.userId,
    required this.petName,
    required this.petType,
    this.breed,
    this.age,
    required this.description,
    required this.lastLocation,
    required this.lostDate,
    required this.contact,
    this.imageUrl,
    this.createdAt,
  });

  factory PetLostAlertEntity.fromJson(Map<String, dynamic> json) {
    final petTypeStr = json['pet_type'] as String? ?? 'other';
    final parsedPetType = PetType.values.firstWhere(
      (e) => e.name == petTypeStr,
      orElse: () => PetType.other,
    );

    return PetLostAlertEntity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      petName: json['pet_name'] as String? ?? '',
      petType: parsedPetType,
      breed: json['breed'] as String?,
      age: json['age'] as String?,
      description: json['description'] as String? ?? '',
      lastLocation: json['last_location'] as String? ?? '',
      lostDate: json['lost_date'] != null
          ? DateTime.parse(json['lost_date'] as String)
          : DateTime.now(),
      contact: json['contact'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'pet_name': petName,
      'pet_type': petType.name,
      'breed': breed,
      'age': age,
      'description': description,
      'last_location': lastLocation,
      'lost_date': lostDate.toIso8601String(),
      'contact': contact,
      'image_url': imageUrl,
    };
  }

  PetLostAlertEntity copyWith({
    String? id,
    String? userId,
    String? petName,
    PetType? petType,
    String? breed,
    String? age,
    String? description,
    String? lastLocation,
    DateTime? lostDate,
    String? contact,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return PetLostAlertEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      petName: petName ?? this.petName,
      petType: petType ?? this.petType,
      breed: breed ?? this.breed,
      age: age ?? this.age,
      description: description ?? this.description,
      lastLocation: lastLocation ?? this.lastLocation,
      lostDate: lostDate ?? this.lostDate,
      contact: contact ?? this.contact,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Validação estritamente síncrona que retorna uma lista de erros.
  /// Se a entidade estiver totalmente válida, retorna uma lista vazia [].
  List<String> validate() {
    final List<String> errors = [];

    // 1. Validação de petName
    final nameError = AppValidators.combine([
      AppValidators.required('Nome do Pet'),
      AppValidators.maxLength(100, 'Nome do Pet'),
    ])(petName);
    if (nameError != null) errors.add(nameError);

    // 2. Validação de petType (Não é mais necessária validação de string, pois é fortemente tipado)

    // 3. Validação de breed (opcional)
    if (breed != null && breed!.isNotEmpty) {
      final breedError = AppValidators.maxLength(100, 'Raça')(breed);
      if (breedError != null) errors.add(breedError);
    }

    // 4. Validação de age (opcional)
    if (age != null && age!.isNotEmpty) {
      final ageError = AppValidators.maxLength(50, 'Idade')(age);
      if (ageError != null) errors.add(ageError);
    }

    // 5. Validação de description
    final descError = AppValidators.combine([
      AppValidators.required('Descrição'),
      AppValidators.minLength(10, 'Descrição'),
      AppValidators.maxLength(1000, 'Descrição'),
    ])(description);
    if (descError != null) errors.add(descError);

    // 6. Validação de lastLocation
    final locError = AppValidators.combine([
      AppValidators.required('Última Localização'),
      AppValidators.maxLength(200, 'Última Localização'),
    ])(lastLocation);
    if (locError != null) errors.add(locError);

    // 7. Validação de lostDate
    if (lostDate.isAfter(DateTime.now())) {
      errors.add('A data do desaparecimento não pode ser no futuro.');
    }

    // 8. Validação de contact (usando o validador de telefone core)
    final contactError = AppValidators.combine([
      AppValidators.required('Contato'),
      AppValidators.phone(),
    ])(contact);
    if (contactError != null) errors.add(contactError);

    // 9. Validação de imageUrl (opcional)
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final urlError = AppValidators.maxLength(500, 'URL da Imagem')(imageUrl);
      if (urlError != null) errors.add(urlError);
    }

    return errors;
  }
}
