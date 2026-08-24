import '../../../core/validation/validators.dart';
import '../../pet_lost/domain/pet_lost_entity.dart' show PetType, AlertStatus;

class PetFoundAlertEntity {
  final String id;
  final String userId;
  final PetType petType;
  final String? breed;
  final String? apparentAge;
  final String description;
  final String foundLocation;
  final DateTime foundDate;
  final String? contact;
  final String imageUrl;
  final double? latitude;
  final double? longitude;
  final AlertStatus status;
  final DateTime? createdAt;

  const PetFoundAlertEntity({
    required this.id,
    required this.userId,
    required this.petType,
    this.breed,
    this.apparentAge,
    required this.description,
    required this.foundLocation,
    required this.foundDate,
    this.contact,
    required this.imageUrl,
    this.latitude,
    this.longitude,
    this.status = AlertStatus.active,
    this.createdAt,
  });

  factory PetFoundAlertEntity.fromJson(Map<String, dynamic> json) {
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

    return PetFoundAlertEntity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      petType: parsedPetType,
      breed: json['breed'] as String?,
      apparentAge: json['apparent_age'] as String?,
      description: json['description'] as String? ?? '',
      foundLocation: json['found_location'] as String? ?? '',
      foundDate: json['found_date'] != null
          ? DateTime.parse(json['found_date'] as String)
          : DateTime.now(),
      contact: json['contact'] as String?,
      imageUrl: json['image_url'] as String? ?? '',
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      status: parsedStatus,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'user_id': userId,
      'pet_type': petType.name,
      'breed': breed,
      'apparent_age': apparentAge,
      'description': description,
      'found_location': foundLocation,
      'found_date': foundDate.toIso8601String(),
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

  PetFoundAlertEntity copyWith({
    String? id,
    String? userId,
    PetType? petType,
    String? breed,
    String? apparentAge,
    String? description,
    String? foundLocation,
    DateTime? foundDate,
    String? contact,
    String? imageUrl,
    double? latitude,
    double? longitude,
    AlertStatus? status,
    DateTime? createdAt,
  }) {
    return PetFoundAlertEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      petType: petType ?? this.petType,
      breed: breed ?? this.breed,
      apparentAge: apparentAge ?? this.apparentAge,
      description: description ?? this.description,
      foundLocation: foundLocation ?? this.foundLocation,
      foundDate: foundDate ?? this.foundDate,
      contact: contact ?? this.contact,
      imageUrl: imageUrl ?? this.imageUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  List<String> validate() {
    final List<String> errors = [];

    // Raça (opcional)
    if (breed != null && breed!.isNotEmpty) {
      final breedError = AppValidators.maxLength(100, 'Raça')(breed);
      if (breedError != null) errors.add(breedError);
    }

    // Idade aparente (opcional)
    if (apparentAge != null && apparentAge!.isNotEmpty) {
      final ageError = AppValidators.maxLength(50, 'Idade Aparente')(apparentAge);
      if (ageError != null) errors.add(ageError);
    }

    // Descrição: obrigatório, min 10, max 255
    final descError = AppValidators.combine([
      AppValidators.required('Descrição/Detalhes de como o pet estava'),
      AppValidators.minLength(10, 'Descrição'),
      AppValidators.maxLength(255, 'Descrição'),
    ])(description);
    if (descError != null) errors.add(descError);

    // Onde foi encontrado (texto): obrigatório, max 200
    final locError = AppValidators.combine([
      AppValidators.required('Onde foi encontrado'),
      AppValidators.maxLength(200, 'Onde foi encontrado'),
    ])(foundLocation);
    if (locError != null) errors.add(locError);

    // Data em que foi encontrado
    if (foundDate.isAfter(DateTime.now())) {
      errors.add('A data em que foi encontrado não pode ser no futuro.');
    }

    // Contato (Opcional, mas se preenchido deve ser telefone válido)
    if (contact != null && contact!.isNotEmpty) {
      final contactError = AppValidators.phone()(contact);
      if (contactError != null) errors.add(contactError);
    }

    // Foto obrigatória
    if (imageUrl.trim().isEmpty) {
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
