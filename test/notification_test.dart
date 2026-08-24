import 'package:flutter_test/flutter_test.dart';
import 'package:orelinhas/features/notification/domain/models/notification_entity.dart';
import 'package:orelinhas/features/notification/domain/models/notification_type.dart';
import 'package:orelinhas/features/notification/data/services/supabase_notification_service.dart';
import 'package:orelinhas/features/notification/data/repositories/notification_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeSupabaseClient extends Fake implements SupabaseClient {}

void main() {
  // =========================================================================
  // GRUPO 1: MODELO DE DOMÍNIO E SERIALIZAÇÃO
  // =========================================================================
  group('NotificationEntity & NotificationType - Domain & Serialization', () {
    test('NotificationType deve mapear strings corretamente', () {
      expect(NotificationType.fromString('match_found'), equals(NotificationType.matchFound));
      expect(NotificationType.fromString('matchFound'), equals(NotificationType.matchFound));
      expect(NotificationType.fromString('pet_status_update'), equals(NotificationType.petStatusUpdate));
      expect(NotificationType.fromString('system'), equals(NotificationType.system));
      expect(NotificationType.fromString('desconhecido'), equals(NotificationType.system));

      expect(NotificationType.matchFound.toSnakeCase(), equals('match_found'));
      expect(NotificationType.petStatusUpdate.toSnakeCase(), equals('pet_status_update'));
      expect(NotificationType.system.toSnakeCase(), equals('system'));
    });

    test('Deve serializar e deserializar NotificationEntity via toJson/fromJson', () {
      final now = DateTime.utc(2026, 8, 23, 14, 30);
      final entity = NotificationEntity(
        id: 'notif-123',
        userId: 'user-456',
        type: NotificationType.matchFound,
        title: 'Possível correspondência!',
        body: 'Um pet parecido com Rex foi avistado.',
        createdAt: now,
        isRead: false,
        relatedPetId: 'pet-lost-789',
        relatedMatchId: 'pet-found-999',
        metadata: {'similarity_score': 0.88},
      );

      final json = entity.toJson();
      final restored = NotificationEntity.fromJson({
        ...json,
        'id': 'notif-123',
      });

      expect(restored.id, equals(entity.id));
      expect(restored.userId, equals(entity.userId));
      expect(restored.type, equals(NotificationType.matchFound));
      expect(restored.title, equals(entity.title));
      expect(restored.body, equals(entity.body));
      expect(restored.isRead, isFalse);
      expect(restored.relatedPetId, equals('pet-lost-789'));
      expect(restored.relatedMatchId, equals('pet-found-999'));
      expect(restored.metadata?['similarity_score'], equals(0.88));
    });

    test('copyWith deve atualizar campos sem corromper os demais', () {
      final original = NotificationEntity(
        id: 'notif-1',
        userId: 'user-1',
        type: NotificationType.system,
        title: 'Boas-vindas',
        body: 'Bem-vindo ao Orelinhas!',
        createdAt: DateTime.now(),
        isRead: false,
      );

      final modified = original.copyWith(isRead: true, title: 'Atualizado');
      expect(modified.isRead, isTrue);
      expect(modified.title, equals('Atualizado'));
      expect(modified.body, equals(original.body));
      expect(modified.userId, equals(original.userId));
    });
  });

  // =========================================================================
  // GRUPO 2: REPOSITÓRIO E SERVIÇO DE NOTIFICAÇÕES
  // =========================================================================
  group('NotificationRepository - Lifecycle & Match Flow', () {
    late SupabaseNotificationService service;
    late NotificationRepository repository;

    setUp(() {
      service = SupabaseNotificationService(FakeSupabaseClient());
      repository = NotificationRepository(service);
    });

    test('Deve registrar e listar notificações do usuário', () async {
      await repository.notifyMatchFound(
        recipientUserId: 'user-100',
        lostPetName: 'Thor',
        foundLocation: 'Praça da Árvore',
        lostPetId: 'lost-1',
        foundPetId: 'found-2',
        similarityScore: 0.89,
      );

      final notifications = await repository.getUserNotifications('user-100');
      expect(notifications, hasLength(1));

      final notif = notifications.first;
      expect(notif.type, equals(NotificationType.matchFound));
      expect(notif.relatedPetId, equals('lost-1'));
      expect(notif.relatedMatchId, equals('found-2'));
      expect(notif.isRead, isFalse);
      expect(notif.body, contains('Thor'));
      expect(notif.body, contains('Praça da Árvore'));
    });

    test('Deve marcar notificação individual como lida', () async {
      await repository.notifyMatchFound(
        recipientUserId: 'user-200',
        lostPetName: 'Luna',
        foundLocation: 'Centro',
        lostPetId: 'lost-10',
        foundPetId: 'found-20',
        similarityScore: 0.92,
      );

      final listBefore = await repository.getUserNotifications('user-200');
      final notifId = listBefore.first.id;

      await repository.markAsRead('user-200', notifId);

      final listAfter = await repository.getUserNotifications('user-200');
      expect(listAfter.first.isRead, isTrue);
    });

    test('Deve marcar todas as notificações do usuário como lidas', () async {
      await repository.notifyMatchFound(
        recipientUserId: 'user-300',
        lostPetName: 'Bob',
        foundLocation: 'Bairro Alto',
        lostPetId: 'lost-1',
        foundPetId: 'found-1',
        similarityScore: 0.85,
      );
      await repository.notifyMatchFound(
        recipientUserId: 'user-300',
        lostPetName: 'Bob',
        foundLocation: 'Parque das Flores',
        lostPetId: 'lost-1',
        foundPetId: 'found-2',
        similarityScore: 0.81,
      );

      final listBefore = await repository.getUserNotifications('user-300');
      expect(listBefore.every((n) => !n.isRead), isTrue);

      await repository.markAllAsRead('user-300');

      final listAfter = await repository.getUserNotifications('user-300');
      expect(listAfter.every((n) => n.isRead), isTrue);
    });
  });
}
