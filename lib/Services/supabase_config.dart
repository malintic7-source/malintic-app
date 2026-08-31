/// Supabase configuration loaded at compile time via `--dart-define`.
///
/// Example build:
/// ```bash
/// flutter build web --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=your_anon_key
/// ```
class SupabaseConfig {
  /// URL Supabase - défaut configuré pour le projet Malintic Supabase
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mzixlwnrsqoxolzafmjb.supabase.co',
  );

  /// Clé anon Supabase - défaut configuré pour l'accès client public
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_X9Srmcc9dIppUO8Hl0EDAw_C-giTCqt',
  );

  static const bool isEnabled = bool.fromEnvironment(
    'SUPABASE_ENABLED',
    defaultValue: true,
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static Map<String, String> get headers => {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Accept': 'application/json',
      };

  static Map<String, String> get writeHeaders => {
        ...headers,
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates',
      };
}
