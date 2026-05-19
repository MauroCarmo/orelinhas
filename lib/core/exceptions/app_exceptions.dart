/// Classe base para todas as exceções estruturadas e previsíveis do domínio da aplicação.
abstract class AppException implements Exception {
  final String message;
  final String? technicalMessage;
  final Map<String, dynamic>? context;

  const AppException({
    required this.message,
    this.technicalMessage,
    this.context,
  });

  @override
  String toString() {
    final technicalDetails = technicalMessage != null ? ' (Detalhes técnicos: $technicalMessage)' : '';
    final contextDetails = context != null ? ' [Contexto: $context]' : '';
    return 'AppException: $message$technicalDetails$contextDetails';
  }
}

/// Exceção lançada ao falhar em validações de negócio ou entradas do usuário no cliente/domínio.
class ValidationException extends AppException {
  const ValidationException(
    String message, {
    super.technicalMessage,
    super.context,
  }) : super(message: message);
}

/// Exceção lançada para falhas relativas à autenticação, credenciais incorretas ou sessões.
class AppAuthException extends AppException {
  const AppAuthException(
    String message, {
    super.technicalMessage,
    super.context,
  }) : super(message: message);
}

/// Exceção lançada para problemas de conexão de internet, timeouts ou indisponibilidade de servidores.
class NetworkException extends AppException {
  const NetworkException(
    String message, {
    super.technicalMessage,
    super.context,
  }) : super(message: message);
}

/// Exceção lançada ao ocorrer problemas de integridade de banco de dados, restrições violadas ou chaves duplicadas.
class DatabaseException extends AppException {
  const DatabaseException(
    String message, {
    super.technicalMessage,
    super.context,
  }) : super(message: message);
}

/// Exceção lançada quando o usuário não possui privilégios de acesso para uma operação (ex: violação de RLS).
class PermissionException extends AppException {
  const PermissionException(
    String message, {
    super.technicalMessage,
    super.context,
  }) : super(message: message);
}

/// Exceção de fallback para falhas genéricas de sistema não mapeadas individualmente.
class UnknownException extends AppException {
  const UnknownException(
    String message, {
    super.technicalMessage,
    super.context,
  }) : super(message: message);
}
