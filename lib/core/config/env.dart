// Runtime configuration read from the bundled `.env` file.
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  const Env({required this.supabaseUrl, required this.supabaseKey});

  final String supabaseUrl;

  /// Publishable (anon) key. Safe to ship in the app: access to data is
  /// enforced on the server by row-level security.
  final String supabaseKey;

  static Future<Env> load() async {
    await dotenv.load();
    return Env(
      supabaseUrl: _required('SUPABASE_URL'),
      supabaseKey: _required('SUPABASE_PUBLISHABLE_KEY'),
    );
  }

  static String _required(String name) {
    final value = dotenv.maybeGet(name)?.trim();
    if (value == null || value.isEmpty) {
      throw StateError('Missing $name in .env (see .env.example)');
    }
    return value;
  }
}
