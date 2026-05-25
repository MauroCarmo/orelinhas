import '../../../core/validation/validators.dart';

enum PetType {
  dog,
  cat,
  other;

  String get name => toString().split('.').last;
}

enum AlertStatus {
  active,
  resolved;

  String get name => toString().split('.').last;
}

class PetLostAlertEntity {
  final String id;
  final String userId;
  final String petName;
  final PetType petType;
  final String? breed;
  final String? age;
  final String description;
  final String lastLocation;
  final DateTime lostDate;
  final String contact;
  final String? imageUrl;
  final DateTime? createdAt;
  // Novos campos
  final double? latitude;
  final double? longitude;
  final AlertStatus status;

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
    this.latitude,
    this.longitude,
    this.status = AlertStatus.active,
  });

  factory PetLostAlertEntity.fromJson(Map<String, dynamic> json) {
    final petTypeStr = json['pet_type'] as String? ?? 'other';
    final parsedPetType = PetType.values.firstWhere(
      (e) => e.name == petTypeStr,
      orElse: () => PetType.other,
    );

    final statusStr = json['status'] as String? ?? 'active';
    final parsedStatus = AlertStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => AlertStatus.active,
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
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      status: parsedStatus,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
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
      'latitude': latitude,
      'longitude': longitude,
      'status': status.name,
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
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
    double? latitude,
    double? longitude,
    AlertStatus? status,
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
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
    );
  }

  List<String> validate() {
    final List<String> errors = [];

    // Nome do Pet
    final nameError = AppValidators.combine([
      AppValidators.required('Nome do Pet'),
      AppValidators.maxLength(100, 'Nome do Pet'),
    ])(petName);
    if (nameError != null) errors.add(nameError);

    // Raça (opcional)
    if (breed != null && breed!.isNotEmpty) {
      final breedError = AppValidators.maxLength(100, 'Raça')(breed);
      if (breedError != null) errors.add(breedError);
    }

    // Idade (opcional)
    if (age != null && age!.isNotEmpty) {
      final ageError = AppValidators.maxLength(50, 'Idade')(age);
      if (ageError != null) errors.add(ageError);
    }

    // Descrição: obrigatório, min 10, max 255
    final descError = AppValidators.combine([
      AppValidators.required('Descrição'),
      AppValidators.minLength(10, 'Descrição'),
      AppValidators.maxLength(255, 'Descrição'),
    ])(description);
    if (descError != null) errors.add(descError);

    // Última localização (texto): obrigatório, max 200
    final locError = AppValidators.combine([
      AppValidators.required('Última Localização'),
      AppValidators.maxLength(200, 'Última Localização'),
    ])(lastLocation);
    if (locError != null) errors.add(locError);

    // Data do desaparecimento
    if (lostDate.isAfter(DateTime.now())) {
      errors.add('A data do desaparecimento não pode ser no futuro.');
    }

    // Contato
    final contactError = AppValidators.combine([
      AppValidators.required('Contato'),
      AppValidators.phone(),
    ])(contact);
    if (contactError != null) errors.add(contactError);

    // Foto obrigatória
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      errors.add('A foto do pet é obrigatória.');
    } else {
      final urlError = AppValidators.maxLength(500, 'URL da Imagem')(imageUrl);
      if (urlError != null) errors.add(urlError);
    }

    // Coordenadas obrigatórias
    if (latitude == null || longitude == null) {
      errors.add('A localização exata (coordenadas) é obrigatória.');
    } else {
      if (latitude! < -90 || latitude! > 90) {
        errors.add('Latitude inválida.');
      }
      if (longitude! < -180 || longitude! > 180) {
        errors.add('Longitude inválida.');
      }
    }

    return errors;
  }
}