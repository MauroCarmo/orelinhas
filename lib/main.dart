import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/env/env.dart';
import 'core/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Carrega as variáveis de ambiente
  await Env.init();
  
  // Inicializa o Supabase
  await SupabaseService.init();

  runApp(
    // ProviderScope é necessário para o Riverpod funcionar
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
