import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  // Escuta as mudanças no estado de autenticação (logado ou não)
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      // Pega o status atual da sessão
      final isAuthenticated = authState.value?.session != null;
      
      // Rotas públicas (que usuários não logados podem acessar)
      final isLoggingIn = state.matchedLocation == '/login' || 
                          state.matchedLocation == '/register' ||
                          state.matchedLocation == '/forgot-password';

      // Redirecionamento (Auth Guard)
      if (!isAuthenticated && !isLoggingIn) {
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
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});
