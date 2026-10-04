import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const enabled = bool.fromEnvironment('USE_SUPABASE');
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static Future<void> initialize() async {
    if (!enabled) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'Configurá SUPABASE_URL y SUPABASE_ANON_KEY mediante dart-define.',
      );
    }
    await Supabase.initialize(url: url, publishableKey: anonKey);
  }
}
