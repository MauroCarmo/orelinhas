/// Tipos de notificações suportadas no sistema.
enum NotificationType {
  /// Uma possível correspondência visual/cadastral foi detectada pela IA.
  matchFound,

  /// Atualização de status de um pet (ex: pet marcado como encontrado).
  petStatusUpdate,

  /// Mensagem informativa ou do sistema.
  system;

  /// Converte string do banco/backend para o enum.
  static NotificationType fromString(String? value) {
    switch (value) {
      case 'match_found':
      case 'matchFound':
        return NotificationType.matchFound;
      case 'pet_status_update':
      case 'petStatusUpdate':
        return NotificationType.petStatusUpdate;
      case 'system':
      default:
        return NotificationType.system;
    }
  }

  /// Retorna o valor snake_case correspondente para o banco de dados.
  String toSnakeCase() {
    switch (this) {
      case NotificationType.matchFound:
        return 'match_found';
      case NotificationType.petStatusUpdate:
        return 'pet_status_update';
      case NotificationType.system:
        return 'system';
    }
  }
}
