import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

/// Níveis de severidade suportados pelo logger.
enum LogLevel { debug, info, warning, error }

/// Logger profissional, estruturado e orientado a produção para o aplicativo Orelinhas.
/// 
/// Garante que dados sensíveis (credenciais e informações pessoais identificáveis) 
/// sejam automaticamente higienizados/mascarados antes de serem gravados ou impressos.
class AppLogger {
  final String? _tag;

  const AppLogger._(this._tag);

  /// Instância global padrão do logger.
  static const AppLogger _global = AppLogger._(null);

  /// Cria uma instância de logger escopada para uma tag específica.
  factory AppLogger.tag(String tag) => AppLogger._(tag);

  /// Cria uma instância de logger escopada para uma categoria específica (sinônimo de tag).
  factory AppLogger.category(String category) => AppLogger._(category);

  // ---------------------------------------------------------------------------
  // Métodos Estáticos (Global Shortcuts)
  // ---------------------------------------------------------------------------

  /// Registra um log de depuração rápida (debug).
  static void debug(String message, {String? tag, Map<String, dynamic>? context, Object? error, StackTrace? stackTrace}) {
    _global.d(message, context: context, error: error, stackTrace: stackTrace, tagOverride: tag);
  }

  /// Registra um log informativo geral do sistema (info).
  static void info(String message, {String? tag, Map<String, dynamic>? context, Object? error, StackTrace? stackTrace}) {
    _global.i(message, context: context, error: error, stackTrace: stackTrace, tagOverride: tag);
  }

  /// Registra um log de aviso para falhas recuperáveis ou fluxos anômalos (warning).
  static void warning(String message, {String? tag, Map<String, dynamic>? context, Object? error, StackTrace? stackTrace}) {
    _global.w(message, context: context, error: error, stackTrace: stackTrace, tagOverride: tag);
  }

  /// Registra um log de erro fatal ou falha impeditiva com rastreamento (error).
  static void error(String message, {String? tag, Map<String, dynamic>? context, Object? error, StackTrace? stackTrace}) {
    _global.e(message, context: context, error: error, stackTrace: stackTrace, tagOverride: tag);
  }

  // ---------------------------------------------------------------------------
  // Métodos de Instância (Scoped Logger Shortcuts)
  // ---------------------------------------------------------------------------

  /// Log de depuração escopado.
  void d(String message, {Map<String, dynamic>? context, Object? error, StackTrace? stackTrace, String? tagOverride}) {
    _log(LogLevel.debug, message, context: context, error: error, stackTrace: stackTrace, tagOverride: tagOverride);
  }

  /// Log informativo escopado.
  void i(String message, {Map<String, dynamic>? context, Object? error, StackTrace? stackTrace, String? tagOverride}) {
    _log(LogLevel.info, message, context: context, error: error, stackTrace: stackTrace, tagOverride: tagOverride);
  }

  /// Log de aviso escopado.
  void w(String message, {Map<String, dynamic>? context, Object? error, StackTrace? stackTrace, String? tagOverride}) {
    _log(LogLevel.warning, message, context: context, error: error, stackTrace: stackTrace, tagOverride: tagOverride);
  }

  /// Log de erro escopado.
  void e(String message, {Map<String, dynamic>? context, Object? error, StackTrace? stackTrace, String? tagOverride}) {
    _log(LogLevel.error, message, context: context, error: error, stackTrace: stackTrace, tagOverride: tagOverride);
  }

  // ---------------------------------------------------------------------------
  // Implementação Interna & Filtro de Segurança
  // ---------------------------------------------------------------------------

  static const List<String> _sensitiveKeys = [
    'password',
    'password_hash',
    'senha',
    'token',
    'jwt',
    'access_token',
    'refresh_token',
    'cookie',
    'authorization',
    'secret',
    // Informações Pessoais Identificáveis (PII)
    'email',
    'phone',
    'telefone',
    'location',
    'localizacao',
    'name',
    'nome',
    'cpf',
    'cnpj',
  ];

  void _log(
    LogLevel level,
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
    String? tagOverride,
  }) {
    final activeTag = tagOverride ?? _tag;
    final levelName = level.name.toUpperCase();
    final timestamp = DateTime.now().toIso8601String();

    final sanitizedMsg = _sanitizeText(message);
    final sanitizedContext = _sanitizeContext(context);
    final sanitizedError = error != null ? _sanitizeText(error.toString()) : null;

    final StringBuffer logBuffer = StringBuffer()
      ..write('[$timestamp] [$levelName]');

    if (activeTag != null && activeTag.isNotEmpty) {
      logBuffer.write(' [$activeTag]');
    }

    logBuffer.write(' $sanitizedMsg');

    if (sanitizedContext != null && sanitizedContext.isNotEmpty) {
      logBuffer.write(' | Context: $sanitizedContext');
    }

    if (sanitizedError != null) {
      logBuffer.write(' | Error: $sanitizedError');
    }

    final formattedLog = logBuffer.toString();

    if (kDebugMode) {
      // Usa developer.log para visualização otimizada com cores no console da IDE
      int devLogLevel = 0;
      switch (level) {
        case LogLevel.debug:
          devLogLevel = 500;
          break;
        case LogLevel.info:
          devLogLevel = 800;
          break;
        case LogLevel.warning:
          devLogLevel = 900;
          break;
        case LogLevel.error:
          devLogLevel = 1000;
          break;
      }

      dev.log(
        formattedLog,
        name: 'OrelinhasLogger',
        level: devLogLevel,
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      // Em produção, registra apenas avisos e erros críticos via debugPrint padrão de forma resumida
      if (level == LogLevel.error || level == LogLevel.warning) {
        debugPrint('[$levelName] $sanitizedMsg${sanitizedError != null ? ' | Error: $sanitizedError' : ''}');
      }
    }
  }

  /// Limpa e mascara dados sensíveis encontrados em blocos de texto corrido.
  static String _sanitizeText(String text) {
    var sanitized = text;
    for (final key in _sensitiveKeys) {
      final regexEq = RegExp('$key\\s*=\\s*[^\\s,\\)]+', caseSensitive: false);
      final regexCol = RegExp('"$key"\\s*:\\s*"[^"]+"', caseSensitive: false);
      
      sanitized = sanitized.replaceAll(regexEq, '$key=[MASCARADO]');
      sanitized = sanitized.replaceAll(regexCol, '"$key":"[MASCARADO]"');
    }
    return sanitized;
  }

  /// Clona e higieniza recursivamente mapas de contexto, blindando PII e credenciais.
  static Map<String, dynamic>? _sanitizeContext(Map<String, dynamic>? context) {
    if (context == null) return null;

    final Map<String, dynamic> sanitized = {};
    context.forEach((key, value) {
      final normalizedKey = key.toLowerCase();
      if (_sensitiveKeys.contains(normalizedKey)) {
        sanitized[key] = '[MASCARADO]';
      } else if (value is Map<String, dynamic>) {
        sanitized[key] = _sanitizeContext(value);
      } else if (value is List) {
        sanitized[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _sanitizeContext(item);
          }
          return _sanitizeText(item.toString());
        }).toList();
      } else {
        sanitized[key] = value != null ? _sanitizeText(value.toString()) : null;
      }
    });

    return sanitized;
  }
}
