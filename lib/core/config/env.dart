// Runtime configuration read from the bundled `.env` file.
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  const Env({
    required this.supabaseUrl,
    required this.supabaseKey,
    this.revenueCatAndroidKey,
    this.premiumOverride,
  });

  factory Env.fromMap(Map<String, String> values) {
    return Env(
      supabaseUrl: _required(values, 'SUPABASE_URL'),
      supabaseKey: _required(values, 'SUPABASE_PUBLISHABLE_KEY'),
      revenueCatAndroidKey: _optional(values, 'REVENUECAT_ANDROID_KEY'),
      premiumOverride: switch (
          _optional(values, 'PREMIUM_OVERRIDE')?.toLowerCase()) {
        'true' => true,
        'false' => false,
        _ => null,
      },
    );
  }

  final String supabaseUrl;

  /// Publishable (anon) key. Safe to ship in the app: access to data is
  /// enforced on the server by row-level security.
  final String supabaseKey;

  /// Public RevenueCat SDK key for Android. Null disables purchases.
  final String? revenueCatAndroidKey;

  /// Forces the premium state on or off. Callers must only honor it in debug
  /// builds.
  final bool? premiumOverride;

  static Future<Env> load() async {
    await dotenv.load();
    return Env.fromMap(dotenv.env);
  }

  static String _required(Map<String, String> values, String name) {
    final value = _optional(values, name);
    if (value == null) {
      throw StateError('Missing $name in .env (see .env.example)');
    }
    return value;
  }

  static String? _optional(Map<String, String> values, String name) {
    final value = values[name]?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
