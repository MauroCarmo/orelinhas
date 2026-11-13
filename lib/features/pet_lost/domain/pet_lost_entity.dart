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
  final List<String> imageUrls;
  final DateTime? createdAt;
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
    this.imageUrls = const [],
    this.createdAt,
    this.latitude,
    this.longitude,
    this.status = AlertStatus.active,
  });

  /// Retorna todas as URLs de imagens disponíveis (até 3), mantendo fallback para [imageUrl].
  List<String> get effectiveImageUrls {
    final urls = <String>[];
    for (final url in imageUrls) {
      final trimmed = url.trim();
      if (trimmed.isNotEmpty && !urls.contains(trimmed)) {
        urls.add(trimmed);
      }
    }
    if (urls.isEmpty && imageUrl != null && imageUrl!.trim().isNotEmpty) {
      urls.add(imageUrl!.trim());
    }
    return urls.take(3).toList();
  }

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

    final primaryImageUrl = json['image_url'] as String?;

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
      imageUrl: primaryImageUrl,
      imageUrls: primaryImageUrl != null && primaryImageUrl.isNotEmpty
          ? [primaryImageUrl]
          : const [],
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
    final effectiveDesc = description.trim().isEmpty
        ? 'Sem descrição adicional.'
        : description.trim();

    final map = <String, dynamic>{
      'user_id': userId,
      'pet_name': petName,
      'pet_type': petType.name,
      'breed': breed,
      'age': age,
      'description': effectiveDesc,
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
    List<String>? imageUrls,
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
      imageUrls: imageUrls ?? this.imageUrls,
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

    // Descrição (opcional, máx 255 caracteres se preenchida)
    if (description.trim().isNotEmpty) {
      final descError = AppValidators.maxLength(255, 'Descrição')(description);
      if (descError != null) errors.add(descError);
    }

    // Endereço / Localização consolidada (garante UF/localidade)
    final locError = AppValidators.combine([
      AppValidators.required('Endereço / Estado (UF)'),
      AppValidators.maxLength(200, 'Endereço'),
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

    // Foto obrigatória (1 a 3 fotos)
    final urls = effectiveImageUrls;
    if (urls.isEmpty) {
      errors.add('Pelo menos 1 foto do pet é obrigatória.');
    } else if (urls.length > 3) {
      errors.add('São permitidas no máximo 3 fotos por alerta.');
    } else {
      for (final url in urls) {
        final urlError = AppValidators.maxLength(500, 'URL da Imagem')(url);
        if (urlError != null) {
          errors.add(urlError);
          break;
        }
      }
    }

    // Coordenadas opcionais (valida faixa apenas se informadas)
    if (latitude != null && (latitude! < -90 || latitude! > 90)) {
      errors.add('Latitude inválida.');
    }
    if (longitude != null && (longitude! < -180 || longitude! > 180)) {
      errors.add('Longitude inválida.');
    }

    return errors;
  }
}
