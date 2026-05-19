import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: Text('Orelinhas App - Base Setup'),
          ),
        ),
      ),
      // Exemplo de rota de funcionalidade:
      // GoRoute(
      //   path: '/login',
      //   builder: (context, state) => const LoginScreen(),
      // ),
    ],
    // Adicione redirecionamentos baseados em autenticação aqui
    // redirect: (context, state) {
    //   final authState = ref.read(authControllerProvider);
    //   ...
    // },
  );
});
