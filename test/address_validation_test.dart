import 'package:flutter_test/flutter_test.dart';
import 'package:orelinhas/core/domain/address/address_entity.dart';
import 'package:orelinhas/features/user/domain/profile_entity.dart';

void main() {
  group('AddressEntity & ProfileEntity Validation Tests', () {
    test('Should return null (valid) for a correct AddressEntity', () {
      const address = AddressEntity(
        cep: '01001000',
        street: 'Praça da Sé',
        number: '123',
        district: 'Sé',
        city: 'São Paulo',
        state: 'SP',
        complement: 'Apt 12',
      );

      expect(address.validate(), isNull);
    });

    test('Should return error message when CEP is not exactly 8 digits', () {
      const address = AddressEntity(
        cep: '01001-00', // 7 digits after sanitization is not allowed in domain
        street: 'Praça da Sé',
        number: '123',
        district: 'Sé',
        city: 'São Paulo',
        state: 'SP',
      );

      final error = address.validate();
      expect(error, isNotNull);
      expect(error, contains('O CEP deve conter exatamente 8 dígitos'));
    });

    test('Should return error message when State (UF) is not exactly 2 characters', () {
      const address = AddressEntity(
        cep: '01001000',
        street: 'Praça da Sé',
        number: '123',
        district: 'Sé',
        city: 'São Paulo',
        state: 'SPF', // invalid UF length
      );

      final error = address.validate();
      expect(error, isNotNull);
      expect(error, contains('Estado (UF)'));
    });

    test('Should return error message for missing mandatory field (street)', () {
      const address = AddressEntity(
        cep: '01001000',
        street: '', // empty
        number: '123',
        district: 'Sé',
        city: 'São Paulo',
        state: 'SP',
      );

      final error = address.validate();
      expect(error, isNotNull);
      expect(error, contains('Rua/Logradouro é obrigatório'));
    });

    test('Should recursively validate AddressEntity inside ProfileEntity', () {
      final profile = ProfileEntity(
        id: 'user-123',
        name: 'João d\'Ávila',
        email: 'joao.davila@email.com',
        phone: '11999999999',
        location: 'São Paulo - SP',
        address: const AddressEntity(
          cep: '0100', // invalid cep
          street: 'Praça da Sé',
          number: '123',
          district: 'Sé',
          city: 'São Paulo',
          state: 'SP',
        ),
      );

      final error = profile.validate();
      expect(error, isNotNull);
      expect(error, contains('O CEP deve conter exatamente 8 dígitos'));
    });
  });
}
