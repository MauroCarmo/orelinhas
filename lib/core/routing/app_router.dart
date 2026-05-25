import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/update_password_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/user/presentation/screens/profile_screen.dart';
import '../../features/pet_lost/presentation/screens/pet_lost_list_screen.dart';
import '../../features/pet_lost/presentation/screens/create_pet_lost_screen.dart';
import '../../features/user/presentation/screens/public_profile_screen.dart';
import 'app_routes.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  // Escuta as mudanças no estado de autenticação (logado ou não)
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    redirect: (context, state) {
      // Pega o status atual da sessão
      final authStateVal = authState.value;
      final isAuthenticated = authStateVal?.session != null;
      final authEvent = authStateVal?.event;
      
      // Quando o deep link de recuperação de senha for clicado
      if (authEvent == AuthChangeEvent.passwordRecovery && state.matchedLocation != AppRoutes.updatePassword) {
        return AppRoutes.updatePassword;
      }
      
      // Rotas públicas (que usuários não logados podem acessar)
      final isLoggingIn = state.matchedLocation == AppRoutes.login || 
                          state.matchedLocation == AppRoutes.register ||
                          state.matchedLocation == AppRoutes.forgotPassword;

      // Redirecionamento (Auth Guard)
      if (!isAuthenticated && !isLoggingIn && state.matchedLocation != AppRoutes.updatePassword) {
        // Bloqueia qualquer rota privada se não estiver logado
        return AppRoutes.login;
      }
      
      if (isAuthenticated && isLoggingIn) {
        // Redireciona para a home se estiver logado e tentar acessar login/registro
        return AppRoutes.home;
      }

      // Permite a navegação normal
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.updatePassword,
        builder: (context, state) => const UpdatePasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.petLost,
        builder: (context, state) => const PetLostListScreen(),
      ),
      GoRoute(
        path: AppRoutes.petLostCreate,
        builder: (context, state) => const CreatePetLostScreen(),
      ),
      GoRoute(
        path: '/pet-lost/edit/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CreatePetLostScreen(alertId: id);
        },
      ),
      GoRoute(
        path: '/public-profile/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return PublicProfileScreen(userId: userId);
        },
      ),
    ],
  );
});
