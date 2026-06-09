import '../../../core/validation/validators.dart';
import '../../pet_lost/domain/pet_lost_entity.dart' show PetType;

enum AdoptionStatus {
  available,
  adopted;

  String get name => toString().split('.').last;
}

class PetAdoptionAlertEntity {
  final String id;
  final String userId;
  final String name;
  final String imageUrl;
  final String characteristics;
  final bool isVaccinated;
  final AdoptionStatus status;
  final PetType species;
  final String region;
  final DateTime? createdAt;

  const PetAdoptionAlertEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.imageUrl,
    required this.characteristics,
    required this.isVaccinated,
    this.status = AdoptionStatus.available,
    required this.species,
    required this.region,
    this.createdAt,
  });

  factory PetAdoptionAlertEntity.fromJson(Map<String, dynamic> json) {
    final speciesStr = json['species'] as String? ?? 'other';
    final parsedSpecies = PetType.values.firstWhere(
      (e) => e.name == speciesStr,
      orElse: () => PetType.other,
    );

    final statusStr = json['status'] as String? ?? 'available';
    final parsedStatus = AdoptionStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => AdoptionStatus.available,
    );

    return PetAdoptionAlertEntity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      characteristics: json['characteristics'] as String? ?? '',
      isVaccinated: json['is_vaccinated'] as bool? ?? false,
      status: parsedStatus,
      species: parsedSpecies,
      region: json['region'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'user_id': userId,
      'name': name,
      'image_url': imageUrl,
      'characteristics': characteristics,
      'is_vaccinated': isVaccinated,
      'status': status.name,
      'species': species.name,
      'region': region,
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  PetAdoptionAlertEntity copyWith({
    String? id,
    String? userId,
    String? name,
    String? imageUrl,
    String? characteristics,
    bool? isVaccinated,
    AdoptionStatus? status,
    PetType? species,
    String? region,
    DateTime? createdAt,
  }) {
    return PetAdoptionAlertEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      characteristics: characteristics ?? this.characteristics,
      isVaccinated: isVaccinated ?? this.isVaccinated,
      status: status ?? this.status,
      species: species ?? this.species,
      region: region ?? this.region,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  List<String> validate() {
    final List<String> errors = [];

    // Nome: obrigatório, máximo 100 caracteres
    final nameError = AppValidators.combine([
      AppValidators.required('Nome do pet'),
      AppValidators.maxLength(100, 'Nome do pet'),
    ])(name);
    if (nameError != null) errors.add(nameError);

    // Foto obrigatória
    if (imageUrl.trim().isEmpty) {
      errors.add('A foto do pet para adoção é obrigatória.');
    } else {
      final urlError = AppValidators.maxLength(500, 'URL da Imagem')(imageUrl);
      if (urlError != null) errors.add(urlError);
    }

    // Características: obrigatória, mínimo 10, máximo 255 caracteres
    final charError = AppValidators.combine([
      AppValidators.required('Características detalhadas'),
      AppValidators.minLength(10, 'Características detalhadas'),
      AppValidators.maxLength(255, 'Características detalhadas'),
    ])(characteristics);
    if (charError != null) errors.add(charError);

    // Região: obrigatória, máximo 150 caracteres
    final regError = AppValidators.combine([
      AppValidators.required('Região do pet'),
      AppValidators.maxLength(150, 'Região do pet'),
    ])(region);
    if (regError != null) errors.add(regError);

    return errors;
  }
}
