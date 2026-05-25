class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String updatePassword = '/update-password';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String petLost = '/pet-lost';
  static const String petLostCreate = '/pet-lost/create';
  
  // Rota com parâmetro dinâmico
  static String petLostEdit(String id) => '/pet-lost/edit/$id';
  // Rota para perfil público, com ID do usuário
  static String publicProfile(String userId) => '/public-profile/$userId';
}
