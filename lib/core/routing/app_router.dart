import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/update_password_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  // Escuta as mudanças no estado de autenticação (logado ou não)
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      // Pega o status atual da sessão
      final authStateVal = authState.value;
      final isAuthenticated = authStateVal?.session != null;
      final authEvent = authStateVal?.event;
      
      // Quando o deep link de recuperação de senha for clicado
      if (authEvent == AuthChangeEvent.passwordRecovery && state.matchedLocation != '/update-password') {
        return '/update-password';
      }
      
      // Rotas públicas (que usuários não logados podem acessar)
      final isLoggingIn = state.matchedLocation == '/login' || 
                          state.matchedLocation == '/register' ||
                          state.matchedLocation == '/forgot-password';

      // Redirecionamento (Auth Guard)
      if (!isAuthenticated && !isLoggingIn && state.matchedLocation != '/update-password') {
        // Bloqueia qualquer rota privada se não estiver logado
        return '/login';
      }
      
      if (isAuthenticated && isLoggingIn) {
        // Redireciona para a home se estiver logado e tentar acessar login/registro
        return '/home';
      }

      // Permite a navegação normal
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/update-password',
        builder: (context, state) => const UpdatePasswordScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});
