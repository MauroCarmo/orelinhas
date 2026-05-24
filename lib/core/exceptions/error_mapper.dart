import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_exceptions.dart';

/// Classe responsável por capturar erros técnicos de infraestrutura (Supabase, Banco de Dados, Rede)
/// e mapeá-los para exceções tipadas de domínio (`AppException`) com mensagens amigáveis em português (PT-BR).
class AppErrorMapper {
  static AppException map(Object error, [StackTrace? stackTrace]) {
    // 1. Se já for uma AppException do nosso domínio, propaga diretamente.
    if (error is AppException) {
      return error;
    }

    // 2. Erros de Autenticação do Supabase
    if (error is AuthException) {
      final code = error.statusCode;
      final originalMessage = error.message.toLowerCase();

      // Mapeamento baseado no conteúdo da mensagem de erro e códigos comuns
      if (originalMessage.contains('invalid login credentials') ||
          originalMessage.contains('invalid_credentials') ||
          originalMessage.contains('invalid claims') ||
          originalMessage.contains('email/password match')) {
        return AppAuthException(
          'Usuário ou senha inválidos.',
          technicalMessage: error.message,
          context: {'status': code},
        );
      }

      if (originalMessage.contains('email not confirmed')) {
        return AppAuthException(
          'Por favor, verifique seu e-mail antes de fazer login.',
          technicalMessage: error.message,
          context: {'status': code},
        );
      }

      if (originalMessage.contains('user already exists') ||
          originalMessage.contains('email already in use')) {
        return AppAuthException(
          'Este e-mail já está cadastrado.',
          technicalMessage: error.message,
          context: {'status': code},
        );
      }

      if (originalMessage.contains('password should be') ||
          originalMessage.contains('password is too short')) {
        return AppAuthException(
          'A senha fornecida não atende aos requisitos de tamanho mínimo.',
          technicalMessage: error.message,
          context: {'status': code},
        );
      }

      return AppAuthException(
        'Falha na autenticação: ${error.message}',
        technicalMessage: error.message,
        context: {'status': code},
      );
    }

    // 3. Erros de Banco de Dados/PostgREST do Supabase
    if (error is PostgrestException) {
      final code = error.code;
      final originalMessage = error.message.toLowerCase();

      // unique_violation (Código PostgreSQL 23505)
      if (code == '23505') {
        if (originalMessage.contains('profiles_email_key') ||
            originalMessage.contains('email')) {
          return ConflictException(
            'Este e-mail já está cadastrado.',
            technicalMessage: '${error.message} (Código: $code)',
            context: {'code': code, 'hint': error.hint},
          );
        }
        return ConflictException(
          'Este registro já existe no sistema.',
          technicalMessage: '${error.message} (Código: $code)',
          context: {'code': code, 'hint': error.hint},
        );
      }

      // insufficient_privilege / permission_denied (Código PostgreSQL 42501 - RLS)
      if (code == '42501') {
        return PermissionException(
          'Você não tem permissão para realizar esta operação.',
          technicalMessage: '${error.message} (Código: $code)',
          context: {'code': code, 'hint': error.hint},
        );
      }

      // foreign_key_violation (Código PostgreSQL 23503)
      if (code == '23503') {
        return DatabaseException(
          'Operação inválida. O registro associado não foi encontrado.',
          technicalMessage: '${error.message} (Código: $code)',
          context: {'code': code},
        );
      }

      return DatabaseException(
        'Erro ao processar dados no servidor.',
        technicalMessage: '${error.message} (Código: $code)',
        context: {'code': code, 'details': error.details, 'hint': error.hint},
      );
    }

    // 4. Erros de Rede e Timeout
    if (error is SocketException ||
        error.toString().contains('SocketException') ||
        error.toString().contains('Failed host lookup')) {
      return const NetworkException(
        'Sem conexão com a internet. Verifique sua rede e tente novamente.',
        technicalMessage: 'Falha de conectividade (SocketException)',
      );
    }

    if (error is TimeoutException ||
        error.toString().contains('TimeoutException')) {
      return const NetworkException(
        'O tempo limite de conexão expirou. Tente novamente em instantes.',
        technicalMessage: 'Conexão interrompida por Timeout',
      );
    }

    // 5. Fallback para erros inesperados
    return UnknownException(
      'Ocorreu um erro inesperado. Tente novamente mais tarde.',
      technicalMessage: error.toString(),
    );
  }
}
