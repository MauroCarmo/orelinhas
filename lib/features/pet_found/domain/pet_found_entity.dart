import '../../../core/validation/sanitizers.dart';
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
  final List<String> imageUrls;
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
    this.imageUrls = const [],
    this.latitude,
    this.longitude,
    this.status = AlertStatus.active,
    this.createdAt,
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
    if (urls.isEmpty && imageUrl.trim().isNotEmpty) {
      urls.add(imageUrl.trim());
    }
    return urls.take(3).toList();
  }

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

    final primaryImageUrl = json['image_url'] as String? ?? '';

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
      imageUrl: primaryImageUrl,
      imageUrls: primaryImageUrl.isNotEmpty ? [primaryImageUrl] : const [],
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
    final cleanDescription = AppSanitizers.sanitizeText(description);
    final effectiveDesc = cleanDescription.isEmpty
        ? 'Sem descrição adicional.'
        : cleanDescription;

    final cleanBreed = AppSanitizers.sanitizeText(breed);
    final cleanAge = AppSanitizers.sanitizeText(apparentAge);
    final cleanLocation = AppSanitizers.sanitizeText(foundLocation);
    final cleanContact = AppSanitizers.digitsOnly(contact);

    final map = <String, dynamic>{
      'user_id': userId,
      'pet_type': petType.name,
      'breed': cleanBreed.isNotEmpty ? cleanBreed : null,
      'apparent_age': cleanAge.isNotEmpty ? cleanAge : null,
      'description': effectiveDesc,
      'found_location': cleanLocation,
      'found_date': foundDate.toIso8601String(),
      'contact': cleanContact.isNotEmpty ? cleanContact : null,
      'image_url': imageUrl.trim(),
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
    List<String>? imageUrls,
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
      imageUrls: imageUrls ?? this.imageUrls,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  List<String> validate() {
    final List<String> errors = [];

    // Raça (opcional)
    if (breed != null && breed!.trim().isNotEmpty) {
      final breedError = AppValidators.maxLength(100, 'Raça')(breed);
      if (breedError != null) errors.add(breedError);
    }

    // Idade aparente (opcional)
    if (apparentAge != null && apparentAge!.trim().isNotEmpty) {
      final ageError = AppValidators.maxLength(50, 'Idade Aparente')(
        apparentAge,
      );
      if (ageError != null) errors.add(ageError);
    }

    // Descrição (opcional, máx 255 caracteres se preenchida)
    if (description.trim().isNotEmpty &&
        description.trim() != 'Sem descrição adicional.') {
      final descError = AppValidators.maxLength(255, 'Descrição')(description);
      if (descError != null) errors.add(descError);
    }

    // Endereço / Localização consolidada
    final locError = AppValidators.combine([
      AppValidators.required('Endereço / Estado (UF)'),
      AppValidators.maxLength(250, 'Endereço'),
    ])(foundLocation);
    if (locError != null) errors.add(locError);

    // Data em que foi encontrado
    if (foundDate.isAfter(DateTime.now())) {
      errors.add('A data em que foi encontrado não pode ser no futuro.');
    }

    // Contato (Opcional - consentimento livre)
    if (contact != null && AppSanitizers.digitsOnly(contact).isNotEmpty) {
      final contactError = AppValidators.phone()(contact);
      if (contactError != null) errors.add(contactError);
    }

    // Foto obrigatória (1 a 3 fotos)
    final urls = effectiveImageUrls;
    if (urls.isEmpty) {
      errors.add('Pelo menos 1 foto do pet é obrigatória.');
    } else if (urls.length > 3) {
      errors.add('São permitidas no máximo 3 fotos por registro.');
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
