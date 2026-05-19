import '../../../core/validation/validators.dart';
import '../../../core/domain/address/address_entity.dart';

class ProfileEntity {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String location;
  final AddressEntity address;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProfileEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.location,
    required this.address,
    this.createdAt,
    this.updatedAt,
  });

  factory ProfileEntity.fromJson(Map<String, dynamic> json) {
    return ProfileEntity(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      location: json['location'] as String? ?? '',
      address: AddressEntity.fromJson(json),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'location': location,
      ...address.toJson(),
    };
  }

  ProfileEntity copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? location,
    AddressEntity? address,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String? validate() {
    final nameError = AppValidators.combine([
      AppValidators.required('Nome'),
      AppValidators.maxLength(100, 'Nome'),
    ])(name);
    if (nameError != null) return nameError;

    final emailError = AppValidators.combine([
      AppValidators.required('E-mail'),
      AppValidators.maxLength(80, 'E-mail'),
      AppValidators.email(),
    ])(email);
    if (emailError != null) return emailError;

    final phoneError = AppValidators.combine([
      AppValidators.required('Telefone'),
      AppValidators.phone(),
    ])(phone);
    if (phoneError != null) return phoneError;

    // Validação recursiva e síncrona do endereço estruturado
    final addressError = address.validate();
    if (addressError != null) return addressError;

    final locationError = AppValidators.combine([
      AppValidators.required('Localização'),
      AppValidators.maxLength(150, 'Localização'),
    ])(location);
    if (locationError != null) return locationError;

    return null;
  }
}
