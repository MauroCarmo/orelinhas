import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orelinhas/core/exceptions/app_exceptions.dart';
import 'package:orelinhas/core/exceptions/error_mapper.dart';
import 'package:orelinhas/core/validation/sanitizers.dart';
import 'package:orelinhas/features/pet_lost/domain/pet_lost_entity.dart';

void main() {
  // =========================================================================
  // GRUPO 1: VALIDAÇÃO DE DOMÍNIO (PetLostAlertEntity.validate())
  // =========================================================================
  group('PetLostAlertEntity - Domain Validation', () {
    /// Helper para criar uma entidade válida base.
    PetLostAlertEntity validEntity({
      String petName = 'Rex',
      PetType petType = PetType.dog,
      String? breed = 'Labrador',
      String? age = '2 anos',
      String description = 'Cachorro muito brincalhão, sumiu perto da praça central.',
      String lastLocation = 'Praça Central',
      DateTime? lostDate,
      String contact = '11999998888',
      String? imageUrl = 'https://example.com/rex.png',
    }) {
      return PetLostAlertEntity(
        id: 'alert-uuid-123',
        userId: 'user-uuid-123',
        petName: petName,
        petType: petType,
        breed: breed,
        age: age,
        description: description,
        lastLocation: lastLocation,
        lostDate: lostDate ?? DateTime.now().subtract(const Duration(days: 1)),
        contact: contact,
        imageUrl: imageUrl,
      );
    }

    test('Deve retornar lista vazia [] para entidade totalmente válida', () {
      final errors = validEntity().validate();
      expect(errors, isEmpty);
    });

    test('Deve acumular múltiplos erros e NÃO parar no primeiro erro', () {
      final alert = validEntity(
        petName: '',
        petType: PetType.other,
        description: 'Curto',
        lastLocation: '',
        lostDate: DateTime.now().add(const Duration(days: 2)),
        contact: '123',
      );

      final errors = alert.validate();
      expect(errors, isNotEmpty);
      // Deve conter pelo menos 5 erros distintos simultâneos
      expect(errors.length, greaterThanOrEqualTo(5));
    });

    test('Deve retornar erro para petName vazio (obrigatório)', () {
      final errors = validEntity(petName: '').validate();
      expect(errors.any((e) => e.contains('Nome do Pet')), isTrue);
    });

    test('Deve aceitar petType PetType.dog, PetType.cat e PetType.other como válidos', () {
      for (final type in PetType.values) {
        final errors = validEntity(petType: type).validate();
        expect(errors.where((e) => e.contains('tipo do pet')), isEmpty,
            reason: 'petType "$type" deveria ser válido');
      }
    });

    test('Deve retornar erro para description com menos de 10 caracteres', () {
      final errors = validEntity(description: 'Curto').validate();
      expect(errors.any((e) => e.contains('Descrição')), isTrue);
    });

    test('Deve retornar erro para lastLocation vazio (obrigatório)', () {
      final errors = validEntity(lastLocation: '').validate();
      expect(errors.any((e) => e.contains('Última Localização')), isTrue);
    });

    test('Deve retornar erro para lostDate no futuro', () {
      final errors = validEntity(
        lostDate: DateTime.now().add(const Duration(days: 5)),
      ).validate();
      expect(errors.any((e) => e.contains('data do desaparecimento')), isTrue);
    });

    test('Deve aceitar lostDate no passado sem erros', () {
      final errors = validEntity(
        lostDate: DateTime.now().subtract(const Duration(days: 30)),
      ).validate();
      expect(errors.where((e) => e.contains('data')), isEmpty);
    });

    test('Deve retornar erro para contact com menos de 8 dígitos', () {
      final errors = validEntity(contact: '123').validate();
      expect(errors.any((e) => e.contains('Contato') || e.contains('telefone')), isTrue);
    });

    test('Deve aceitar contact com máscara visual e 11 dígitos', () {
      final errors = validEntity(contact: '(11) 99999-8888').validate();
      // O validator phone() extrai dígitos e valida o range 8-15
      expect(errors.where((e) => e.contains('telefone')), isEmpty);
    });

    test('Deve aceitar breed e age como opcionais (null)', () {
      final errors = validEntity(breed: null, age: null).validate();
      expect(errors, isEmpty);
    });

    test('Deve aceitar imageUrl como opcional (null)', () {
      final errors = validEntity(imageUrl: null).validate();
      expect(errors, isEmpty);
    });

    test('Domínio NÃO sanitiza dados - preserva HTML/scripts intactos', () {
      final alert = validEntity(
        petName: 'Rex <script>alert("xss")</script>',
        description: 'Meu cão sumiu perto do parque. <script>steal()</script>',
      );

      final errors = alert.validate();
      expect(errors, isEmpty);
      // A entidade mantém dados brutos - sanitização é responsabilidade do repositório
      expect(alert.petName, contains('<script>'));
      expect(alert.description, contains('<script>'));
    });
  });

  // =========================================================================
  // GRUPO 2: SERIALIZAÇÃO E DESERIALIZAÇÃO (fromJson / toJson)
  // =========================================================================
  group('PetLostAlertEntity - Serialization', () {
    test('Deve serializar e deserializar corretamente via toJson/fromJson', () {
      final original = PetLostAlertEntity(
        id: 'abc-123',
        userId: 'user-456',
        petName: 'Luna',
        petType: PetType.cat,
        breed: 'Siamês',
        age: '3 anos',
        description: 'Gata siamesa desapareceu na região central.',
        lastLocation: 'Rua das Flores, 123',
        lostDate: DateTime.utc(2025, 6, 15, 10, 30),
        contact: '11988887777',
        imageUrl: 'https://example.com/luna.jpg',
        createdAt: DateTime.utc(2025, 6, 16, 8, 0),
      );

      final json = original.toJson();
      final restored = PetLostAlertEntity.fromJson({
        ...json,
        'created_at': original.createdAt?.toIso8601String(),
      });

      expect(restored.id, equals(original.id));
      expect(restored.userId, equals(original.userId));
      expect(restored.petName, equals(original.petName));
      expect(restored.petType, equals(original.petType));
      expect(restored.breed, equals(original.breed));
      expect(restored.age, equals(original.age));
      expect(restored.description, equals(original.description));
      expect(restored.lastLocation, equals(original.lastLocation));
      expect(restored.contact, equals(original.contact));
      expect(restored.imageUrl, equals(original.imageUrl));
    });

    test('copyWith deve preservar campos não alterados', () {
      final original = PetLostAlertEntity(
        id: 'abc-123',
        userId: 'user-456',
        petName: 'Luna',
        petType: PetType.cat,
        description: 'Gata siamesa desapareceu na região central.',
        lastLocation: 'Rua das Flores, 123',
        lostDate: DateTime.utc(2025, 6, 15),
        contact: '11988887777',
      );

      final modified = original.copyWith(petName: 'Mimi', petType: PetType.other);

      expect(modified.petName, equals('Mimi'));
      expect(modified.petType, equals(PetType.other));
      // Campos não alterados permanecem iguais
      expect(modified.id, equals(original.id));
      expect(modified.userId, equals(original.userId));
      expect(modified.description, equals(original.description));
      expect(modified.contact, equals(original.contact));
    });
  });

  // =========================================================================
  // GRUPO 3: MAPEAMENTO DE ERROS (AppErrorMapper)
  // =========================================================================
  group('AppErrorMapper - Error Mapping', () {
    test('Deve mapear PostgreSQL 42501 (RLS violation) para PermissionException', () {
      final error = PostgrestException(
        message: 'insufficient_privilege or RLS violation',
        code: '42501',
      );
      final mapped = AppErrorMapper.map(error);
      expect(mapped, isA<PermissionException>());
      expect(mapped.message, contains('permissão'));
    });

    test('Deve mapear PostgreSQL 23505 (unique violation) para ConflictException', () {
      final error = PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
      );
      final mapped = AppErrorMapper.map(error);
      expect(mapped, isA<ConflictException>());
      expect(mapped.message, contains('já existe'));
    });

    test('Deve mapear PostgreSQL 23503 (foreign key violation) para DatabaseException', () {
      final error = PostgrestException(
        message: 'insert or update violates foreign key constraint',
        code: '23503',
      );
      final mapped = AppErrorMapper.map(error);
      expect(mapped, isA<DatabaseException>());
    });

    test('Deve mapear SocketException para NetworkException', () {
      // Simula o toString() de um SocketException
      const error = 'SocketException: Failed host lookup: "supabase.co"';
      final mapped = AppErrorMapper.map(error);
      expect(mapped, isA<NetworkException>());
      expect(mapped.message, contains('conexão'));
    });

    test('Deve mapear TimeoutException para NetworkException', () {
      const error = 'TimeoutException after 0:00:30';
      final mapped = AppErrorMapper.map(error);
      expect(mapped, isA<NetworkException>());
      expect(mapped.message, contains('tempo limite'));
    });

    test('Deve retornar UnknownException para erros não mapeados', () {
      final error = Exception('Some generic unknown crash');
      final mapped = AppErrorMapper.map(error);
      expect(mapped, isA<UnknownException>());
      expect(mapped.message, contains('erro inesperado'));
    });

    test('Deve propagar AppException já existente sem remapeamento', () {
      const original = PermissionException('Acesso negado pelo sistema.');
      final mapped = AppErrorMapper.map(original);
      expect(mapped, same(original));
      expect(mapped.message, equals('Acesso negado pelo sistema.'));
    });
  });

  // =========================================================================
  // GRUPO 4: SANITIZAÇÃO TÉCNICA (AppSanitizers)
  // =========================================================================
  group('AppSanitizers - Technical Sanitization', () {
    test('sanitizeText deve remover tags HTML/script perigosas', () {
      final result = AppSanitizers.sanitizeText(
        'Meu cão sumiu <script>alert("xss")</script> ontem.',
      );
      expect(result, isNot(contains('<script>')));
      expect(result, isNot(contains('</script>')));
      expect(result, contains('Meu cão sumiu'));
      expect(result, contains('ontem.'));
    });

    test('sanitizeText deve preservar acentos e caracteres do português', () {
      final result = AppSanitizers.sanitizeText('Cão perdido na região de São Paulo — urgência!');
      expect(result, equals('Cão perdido na região de São Paulo — urgência!'));
    });

    test('sanitizeText deve retornar string vazia para null', () {
      expect(AppSanitizers.sanitizeText(null), equals(''));
    });

    test('digitsOnly deve extrair apenas dígitos numéricos', () {
      expect(AppSanitizers.digitsOnly('(11) 99999-8888'), equals('11999998888'));
      expect(AppSanitizers.digitsOnly('01001-000'), equals('01001000'));
    });

    test('digitsOnly deve retornar string vazia para null', () {
      expect(AppSanitizers.digitsOnly(null), equals(''));
    });

    test('trim deve remover espaços das extremidades', () {
      expect(AppSanitizers.trim('  https://example.com  '), equals('https://example.com'));
    });

    test('trim deve retornar string vazia para null', () {
      expect(AppSanitizers.trim(null), equals(''));
    });

    test('normalizeEmail deve converter para lowercase e trim', () {
      expect(AppSanitizers.normalizeEmail('  JoAo@GMAIL.com  '), equals('joao@gmail.com'));
    });
  });

  // =========================================================================
  // GRUPO 5: EXCEÇÕES DE DOMÍNIO (AppException hierarchy)
  // =========================================================================
  group('AppException - Exception Hierarchy', () {
    test('ConflictException deve ser subtipo de AppException', () {
      const exception = ConflictException('Conflito de dados.');
      expect(exception, isA<AppException>());
      expect(exception.message, equals('Conflito de dados.'));
    });

    test('PermissionException deve ser subtipo de AppException', () {
      const exception = PermissionException('Sem permissão.');
      expect(exception, isA<AppException>());
    });

    test('NetworkException deve ser subtipo de AppException', () {
      const exception = NetworkException('Sem internet.');
      expect(exception, isA<AppException>());
    });

    test('UnknownException deve ser subtipo de AppException', () {
      const exception = UnknownException('Erro desconhecido.');
      expect(exception, isA<AppException>());
    });

    test('ValidationException deve ser subtipo de AppException', () {
      const exception = ValidationException('Campo inválido.');
      expect(exception, isA<AppException>());
    });

    test('AppException.toString() deve conter mensagem e detalhes técnicos', () {
      const exception = DatabaseException(
        'Registro duplicado.',
        technicalMessage: 'unique_violation code 23505',
        context: {'code': '23505'},
      );
      final str = exception.toString();
      expect(str, contains('Registro duplicado'));
      expect(str, contains('unique_violation'));
      expect(str, contains('23505'));
    });
  });
}
