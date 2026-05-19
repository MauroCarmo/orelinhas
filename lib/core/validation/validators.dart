class AppValidators {
  /// Retorna o primeiro erro encontrado ao executar uma lista de validadores em sequência.
  static String? Function(String?) combine(List<String? Function(String?)> validators) {
    return (value) {
      for (final validator in validators) {
        final error = validator(value);
        if (error != null) {
          return error;
        }
      }
      return null;
    };
  }

  /// Valida se o campo é obrigatório (não nulo e não vazio).
  static String? Function(String?) required(String fieldName) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return 'O campo $fieldName é obrigatório.';
      }
      return null;
    };
  }

  /// Valida se o formato do e-mail é estruturalmente correto.
  static String? Function(String?) email() {
    return (value) {
      if (value == null || value.trim().isEmpty) return null; // Componível com required
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(value.trim())) {
        return 'Digite um e-mail válido (ex: seuemail@provedor.com).';
      }
      return null;
    };
  }

  /// Valida a complexidade de senhas fortes conforme os requisitos de segurança IBL01/IBL02.
  /// Mínimo de 8 caracteres, com pelo menos uma maiúscula, uma minúscula, um número e um caractere especial.
  static String? Function(String?) passwordComplexity() {
    return (value) {
      if (value == null || value.isEmpty) return null; // Componível com required
      
      if (value.length < 8) {
        return 'A senha deve ter no mínimo 8 caracteres.';
      }
      if (!RegExp(r'[A-Z]').hasMatch(value)) {
        return 'A senha precisa ter pelo menos uma letra maiúscula.';
      }
      if (!RegExp(r'[a-z]').hasMatch(value)) {
        return 'A senha precisa ter pelo menos uma letra minúscula.';
      }
      if (!RegExp(r'[0-9]').hasMatch(value)) {
        return 'A senha precisa ter pelo menos um número.';
      }
      if (!RegExp(r'[@$!%*?&.]').hasMatch(value)) {
        return 'A senha precisa ter pelo menos um caractere especial (@, \$, !, %, *, ?, &, ou .).';
      }
      
      return null;
    };
  }

  /// Valida o CEP brasileiro (deve conter exatamente 8 dígitos numéricos limpos).
  static String? Function(String?) cep() {
    return (value) {
      if (value == null || value.trim().isEmpty) return null; // Componível com required
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length != 8) {
        return 'O CEP deve conter exatamente 8 dígitos.';
      }
      return null;
    };
  }

  /// Valida o número de telefone (deve conter entre 8 e 15 dígitos numéricos limpos).
  static String? Function(String?) phone() {
    return (value) {
      if (value == null || value.trim().isEmpty) return null; // Componível com required
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length < 8 || digits.length > 15) {
        return 'O telefone deve conter entre 8 e 15 números (com DDD).';
      }
      return null;
    };
  }

  /// Valida se a string atende a um comprimento mínimo especificado.
  static String? Function(String?) minLength(int min, String fieldName) {
    return (value) {
      if (value == null || value.trim().isEmpty) return null;
      if (value.trim().length < min) {
        return 'O campo $fieldName deve conter no mínimo $min caracteres.';
      }
      return null;
    };
  }

  /// Valida se a string não ultrapassa um comprimento máximo especificado.
  static String? Function(String?) maxLength(int max, String fieldName) {
    return (value) {
      if (value == null || value.trim().isEmpty) return null;
      if (value.trim().length > max) {
        return 'O campo $fieldName não pode ter mais que $max caracteres.';
      }
      return null;
    };
  }

  /// Valida se todos os caracteres da string pertencem a um conjunto permitido (Expressão Regular).
  static String? Function(String?) allowedCharacters(RegExp allowed, String errorMessage) {
    return (value) {
      if (value == null || value.isEmpty) return null;
      if (!allowed.hasMatch(value)) {
        return errorMessage;
      }
      return null;
    };
  }
}
