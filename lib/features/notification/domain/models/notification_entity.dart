import 'notification_type.dart';

/// Entidade que representa uma notificação gerada para o usuário (ex: Match de IA).
class NotificationEntity {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? relatedPetId; // ID do pet do usuário (ex: pet perdido)
  final String? relatedMatchId; // ID do match ou do pet encontrado correspondente
  final Map<String, dynamic>? metadata;

  const NotificationEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.relatedPetId,
    this.relatedMatchId,
    this.metadata,
  });

  factory NotificationEntity.fromJson(Map<String, dynamic> json) {
    return NotificationEntity(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      type: NotificationType.fromString(json['type'] as String?),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      isRead: json['is_read'] as bool? ?? false,
      relatedPetId: json['related_pet_id'] as String?,
      relatedMatchId: json['related_match_id'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'user_id': userId,
      'type': type.toSnakeCase(),
      'title': title,
      'body': body,
      'is_read': isRead,
      'related_pet_id': relatedPetId,
      'related_match_id': relatedMatchId,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  NotificationEntity copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? body,
    DateTime? createdAt,
    bool? isRead,
    String? relatedPetId,
    String? relatedMatchId,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      relatedPetId: relatedPetId ?? this.relatedPetId,
      relatedMatchId: relatedMatchId ?? this.relatedMatchId,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          type == other.type &&
          title == other.title &&
          body == other.body &&
          isRead == other.isRead &&
          relatedPetId == other.relatedPetId &&
          relatedMatchId == other.relatedMatchId;

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        type,
        title,
        body,
        isRead,
        relatedPetId,
        relatedMatchId,
      );
}
