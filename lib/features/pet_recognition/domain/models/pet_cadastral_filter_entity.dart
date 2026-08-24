import '../../../pet_lost/domain/pet_lost_entity.dart';

/// Filtros cadastrais estruturados utilizados na Etapa 1 da busca e para espécies não suportadas pela IA visual.
class PetCadastralFilterEntity {
  final PetType petType;
  final String? breed;
  final String? age;
  final String? approximateLocation;
  final DateTime? lostDateFrom;
  final DateTime? lostDateTo;
  final double? latitude;
  final double? longitude;
  final double maxRadiusKm;

  const PetCadastralFilterEntity({
    required this.petType,
    this.breed,
    this.age,
    this.approximateLocation,
    this.lostDateFrom,
    this.lostDateTo,
    this.latitude,
    this.longitude,
    this.maxRadiusKm = 50.0,
  });

  /// Cria filtros a partir de uma entidade existente de Pet Perdido.
  factory PetCadastralFilterEntity.fromPetAlert(
    PetLostAlertEntity alert, {
    double radiusKm = 50.0,
    Duration dateTolerance = const Duration(days: 90),
  }) {
    return PetCadastralFilterEntity(
      petType: alert.petType,
      breed: alert.breed,
      age: alert.age,
      approximateLocation: alert.lastLocation,
      lostDateFrom: alert.lostDate.subtract(dateTolerance),
      lostDateTo: alert.lostDate.add(dateTolerance),
      latitude: alert.latitude,
      longitude: alert.longitude,
      maxRadiusKm: radiusKm,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pet_type': petType.name,
      'breed': breed,
      'age': age,
      'approximate_location': approximateLocation,
      'lost_date_from': lostDateFrom?.toIso8601String(),
      'lost_date_to': lostDateTo?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'max_radius_km': maxRadiusKm,
    };
  }
}
