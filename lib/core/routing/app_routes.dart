class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String updatePassword = '/update-password';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String petLost = '/pet-lost';
  static const String petLostCreate = '/pet-lost/create';
  static const String petLostMap = '/pet-lost-map';
  
  static const String petFound = '/pet-found';
  static const String petFoundCreate = '/pet-found/create';
  static const String petFoundMap = '/pet-found-map';

  static const String petAdoption = '/pet-adoption';
  static const String petAdoptionCreate = '/pet-adoption/create';
  
  // Rota com parâmetro dinâmico
  static String petLostEdit(String id) => '/pet-lost/edit/$id';
  static String petFoundEdit(String id) => '/pet-found/edit/$id';
  static String petAdoptionEdit(String id) => '/pet-adoption/edit/$id';
  // Rota para perfil público, com ID do usuário
  static String publicProfile(String userId) => '/public-profile/$userId';
  // Rota para correspondências de reconhecimento visual de pets
  static String petMatches(String id) => '/pet-matches/$id';
  // Rota para central de notificações
  static const String notifications = '/notifications';
}
