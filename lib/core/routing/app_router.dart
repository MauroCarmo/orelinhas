import 'dart:async';
import 'package:flutter/foundation.dart';
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
import '../../features/pet_lost/presentation/screens/pet_lost_detail_screen.dart';
import '../../features/pet_lost/presentation/screens/create_pet_lost_screen.dart';
import '../../features/user/presentation/screens/public_profile_screen.dart';
import '../../features/pet_lost/presentation/screens/pet_lost_map_screen.dart';
import '../../features/pet_found/presentation/screens/pet_found_list_screen.dart';
import '../../features/pet_found/presentation/screens/create_pet_found_screen.dart';
import '../../features/pet_found/presentation/screens/pet_found_map_screen.dart';
import '../../features/pet_adoption/presentation/screens/pet_adoption_list_screen.dart';
import '../../features/pet_adoption/presentation/screens/create_pet_adoption_screen.dart';
import '../../features/home/presentation/screens/report_abuse_screen.dart';
import '../../features/notification/presentation/screens/notification_list_screen.dart';
import '../../features/pet_recognition/presentation/screens/pet_match_results_screen.dart';
import '../../features/pet_recognition/presentation/screens/pet_match_detail_screen.dart';
import '../../features/pet_lost/domain/pet_lost_entity.dart';
import '../../features/pet_adoption/domain/pet_adoption_entity.dart';
import '../../features/pet_found/domain/pet_found_entity.dart';
import '../../features/welcome/presentation/screens/welcome_screen.dart';
import '../widgets/app_shell.dart';
import 'app_routes.dart';

// Notifier auxiliar para o GoRouter reavaliar redirects sem recriar a instância
class _AuthRouterRefreshNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;
  AuthChangeEvent? lastEvent;

  _AuthRouterRefreshNotifier(Stream<AuthState> stream) {
    _subscription = stream.listen((authState) {
      lastEvent = authState.event;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final authStream = Supabase.instance.client.auth.onAuthStateChange;
  final refreshNotifier = _AuthRouterRefreshNotifier(authStream);

  ref.onDispose(() {
    refreshNotifier.dispose();
  });

  return GoRouter(
    initialLocation: AppRoutes.welcome,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuthenticated = session != null;
      final authEvent = refreshNotifier.lastEvent;
      final currentPath = state.matchedLocation;

      // 1. Quando o link de recuperação de senha for clicado (Web ou Mobile)
      if (authEvent == AuthChangeEvent.passwordRecovery &&
          currentPath != AppRoutes.updatePassword) {
        return AppRoutes.updatePassword;
      }

      // 2. Evita que o deep link mobile (/login-callback) caia em erro de rota não encontrada
      // enquanto o Supabase ainda está trocando o código pela sessão
      if (currentPath == '/login-callback') {
        return isAuthenticated ? AppRoutes.home : AppRoutes.welcome;
      }

      // 3. Rotas públicas (que usuários não logados podem acessar)
      final isPublicRoute =
          currentPath == AppRoutes.welcome ||
          currentPath == AppRoutes.login ||
          currentPath == AppRoutes.register ||
          currentPath == AppRoutes.forgotPassword ||
          currentPath == AppRoutes.updatePassword;

      // 4. Auth Guard: Bloqueia rotas privadas se não estiver logado
      if (!isAuthenticated && !isPublicRoute) {
        return AppRoutes.welcome;
      }

      // 5. Se já estiver logado e tentar acessar telas de entrada (exceto updatePassword), vai para Home
      if (isAuthenticated &&
          isPublicRoute &&
          currentPath != AppRoutes.updatePassword) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
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
      // Rota de fallback caso o deep link mobile caia aqui antes do evento disparar
      GoRoute(
        path: '/login-callback',
        builder: (context, state) => const WelcomeScreen(),
      ),

      // Áreas principais com barra de navegação inferior
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.petLost,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PetLostListScreen()),
          ),
          GoRoute(
            path: AppRoutes.petLostMap,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PetLostMapScreen()),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
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
        path: '/pet-lost/details/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final initial = state.extra is PetLostAlertEntity
              ? state.extra as PetLostAlertEntity
              : null;
          return PetLostDetailScreen(alertId: id, initialAlert: initial);
        },
      ),
      GoRoute(
        path: AppRoutes.petFound,
        builder: (context, state) => const PetFoundListScreen(),
      ),
      GoRoute(
        path: AppRoutes.petFoundCreate,
        builder: (context, state) => const CreatePetFoundScreen(),
      ),
      GoRoute(
        path: '/pet-found/edit/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CreatePetFoundScreen(alertId: id);
        },
      ),
      GoRoute(
        path: '/public-profile/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          final lostId = state.uri.queryParameters['lostId'];
          final foundId = state.uri.queryParameters['foundId'];
          return PublicProfileScreen(
            userId: userId,
            lostAlert: state.extra is PetLostAlertEntity
                ? state.extra as PetLostAlertEntity
                : null,
            lostAlertId: lostId,
            foundAlert: state.extra is PetFoundAlertEntity
                ? state.extra as PetFoundAlertEntity
                : null,
            foundAlertId: foundId,
            adoptionAlert: state.extra is PetAdoptionAlertEntity
                ? state.extra as PetAdoptionAlertEntity
                : null,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.petFoundMap,
        builder: (context, state) => const PetFoundMapScreen(),
      ),
      GoRoute(
        path: AppRoutes.petAdoption,
        builder: (context, state) => const PetAdoptionListScreen(),
      ),
      GoRoute(
        path: AppRoutes.petAdoptionCreate,
        builder: (context, state) => const CreatePetAdoptionScreen(),
      ),
      GoRoute(
        path: '/pet-adoption/edit/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CreatePetAdoptionScreen(alertId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationListScreen(),
      ),
      GoRoute(
        path: AppRoutes.reportAbuse,
        builder: (context, state) => const ReportAbuseScreen(),
      ),
      GoRoute(
        path: '/pet-matches/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final targetFoundPetId = state.uri.queryParameters['foundId'];
          return PetMatchResultsScreen(
            petId: id,
            initialHighlightPetId: targetFoundPetId,
          );
        },
      ),
      GoRoute(
        path: '/match-detail/:foundId',
        builder: (context, state) {
          final foundId = state.pathParameters['foundId']!;
          final lostId = state.uri.queryParameters['lostId'];
          final scoreStr = state.uri.queryParameters['score'];
          final score = scoreStr != null ? double.tryParse(scoreStr) : null;
          return PetMatchDetailScreen(
            foundPetId: foundId,
            lostPetId: lostId,
            initialScore: score,
          );
        },
      ),
    ],
  );
});
