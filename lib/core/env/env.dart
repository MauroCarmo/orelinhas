import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static Future<void> init() async {
    await dotenv.load(fileName: ".env");
  }

  static String get supabaseUrl {
    final value = dotenv.env['SUPABASE_URL'];
    if (value == null || value.isEmpty) {
      throw Exception(
        'SUPABASE_URL não está definida no arquivo .env. '
        'Crie um arquivo .env na raiz do projeto com: SUPABASE_URL=https://seu-projeto.supabase.co',
      );
    }
    return value;
  }

  static String get supabaseAnonKey {
    final value = dotenv.env['SUPABASE_ANON_KEY'];
    if (value == null || value.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY não está definida no arquivo .env. '
        'Crie um arquivo .env na raiz do projeto com: SUPABASE_ANON_KEY=sua-chave-aqui',
      );
    }
    return value;
  }
}
