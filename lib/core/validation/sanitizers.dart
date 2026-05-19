class AppSanitizers {
  /// Remove espaços adicionais das extremidades de uma string.
  static String trim(String? value) {
    if (value == null) return '';
    return value.trim();
  }

  /// Filtra e retorna apenas os caracteres numéricos da string (ideal para CEP e telefones).
  static String digitsOnly(String? value) {
    if (value == null) return '';
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Normaliza um endereço de e-mail removendo espaços e convertendo para minúsculas.
  static String normalizeEmail(String? value) {
    if (value == null) return '';
    return value.trim().toLowerCase();
  }

  /// Sanitiza entradas de texto livre para evitar scripts maliciosos, HTML, XML ou tags perigosas.
  /// Preserva acentos, espaços, símbolos do português e capitalizações originais intactas.
  static String sanitizeText(String? value) {
    if (value == null) return '';
    
    // 1. Remove qualquer tag HTML/XML estrutural: <qualquer_coisa>
    final noTags = value.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // 2. Remove possíveis injeções de atributos JavaScript perigosos inline (onload, onerror, onclick, etc.)
    final cleanAttributes = noTags.replaceAll(
      RegExp(r'''\bon\w+\s*=\s*(["'][^"']*["']|[^>\s]+)''', caseSensitive: false),
      '',
    );
    
    return cleanAttributes.trim();
  }
}
