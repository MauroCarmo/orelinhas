class ProfileEntity {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String location;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProfileEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.location,
    this.createdAt,
    this.updatedAt,
  });

  factory ProfileEntity.fromJson(Map<String, dynamic> json) {
    return ProfileEntity(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      location: json['location'] as String? ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'location': location,
    };
  }

  ProfileEntity copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? location,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Valida as regras de negócio do perfil de usuário de acordo com os requisitos IBL01.
  /// Retorna null se for válido, ou uma string de erro caso contrário.
  String? validate() {
    if (name.trim().isEmpty) {
      return 'O nome é obrigatório.';
    }
    if (name.length > 100) {
      return 'O nome deve ter no máximo 100 caracteres.';
    }

    if (email.trim().isEmpty) {
      return 'O e-mail é obrigatório.';
    }
    if (email.length > 80) {
      return 'O e-mail deve ter no máximo 80 caracteres.';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      return 'Formato de e-mail inválido.';
    }

    if (phone.trim().isEmpty) {
      return 'O telefone é obrigatório.';
    }
    // Remove espaços e símbolos para validação de tamanho de dígitos
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 8 || digitsOnly.length > 15) {
      return 'O telefone deve conter entre 8 e 15 dígitos numéricos.';
    }
    final phoneRegex = RegExp(r'^\+?[0-9\s\-()]+$');
    if (!phoneRegex.hasMatch(phone)) {
      return 'Formato de telefone inválido.';
    }

    if (location.trim().isEmpty) {
      return 'A localização é obrigatória.';
    }
    if (location.length > 150) {
      return 'A localização deve ter no máximo 150 caracteres.';
    }

    return null;
  }
}
