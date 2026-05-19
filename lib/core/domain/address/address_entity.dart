import '../../validation/validators.dart';

/// Entidade de domínio pura e estritamente imutável representando um Endereço.
class AddressEntity {
  final String cep;
  final String street;
  final String number;
  final String district;
  final String city;
  final String state;
  final String complement;

  const AddressEntity({
    required this.cep,
    required this.street,
    required this.number,
    required this.district,
    required this.city,
    required this.state,
    this.complement = '',
  });

  /// Reconstrói a entidade a partir de um JSON.
  factory AddressEntity.fromJson(Map<String, dynamic> json) {
    return AddressEntity(
      cep: json['cep'] as String? ?? '',
      street: json['street'] as String? ?? '',
      number: json['number'] as String? ?? '',
      district: json['district'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      complement: json['complement'] as String? ?? '',
    );
  }

  /// Converte a entidade para estrutura JSON.
  Map<String, dynamic> toJson() {
    return {
      'cep': cep,
      'street': street,
      'number': number,
      'district': district,
      'city': city,
      'state': state,
      'complement': complement,
    };
  }

  /// Retorna uma cópia da entidade com dados alterados, preservando a imutabilidade original.
  AddressEntity copyWith({
    String? cep,
    String? street,
    String? number,
    String? district,
    String? city,
    String? state,
    String? complement,
  }) {
    return AddressEntity(
      cep: cep ?? this.cep,
      street: street ?? this.street,
      number: number ?? this.number,
      district: district ?? this.district,
      city: city ?? this.city,
      state: state ?? this.state,
      complement: complement ?? this.complement,
    );
  }

  /// Valida as regras de negócio estruturais do endereço.
  /// Retorna a mensagem do primeiro erro ou `null` caso todos os campos sejam válidos.
  String? validate() {
    final cepError = AppValidators.combine([
      AppValidators.required('CEP'),
      AppValidators.cep(),
    ])(cep);
    if (cepError != null) return cepError;

    final streetError = AppValidators.combine([
      AppValidators.required('Rua/Logradouro'),
      AppValidators.maxLength(150, 'Rua/Logradouro'),
    ])(street);
    if (streetError != null) return streetError;

    final numberError = AppValidators.combine([
      AppValidators.required('Número'),
      AppValidators.maxLength(20, 'Número'),
    ])(number);
    if (numberError != null) return numberError;

    final districtError = AppValidators.combine([
      AppValidators.required('Bairro'),
      AppValidators.maxLength(100, 'Bairro'),
    ])(district);
    if (districtError != null) return districtError;

    final cityError = AppValidators.combine([
      AppValidators.required('Cidade'),
      AppValidators.maxLength(100, 'Cidade'),
    ])(city);
    if (cityError != null) return cityError;

    final stateError = AppValidators.combine([
      AppValidators.required('Estado (UF)'),
      AppValidators.minLength(2, 'Estado (UF)'),
      AppValidators.maxLength(2, 'Estado (UF)'),
    ])(state);
    if (stateError != null) return stateError;

    if (complement.length > 150) {
      return 'O complemento não pode exceder 150 caracteres.';
    }

    return null;
  }
}
