/// Supabase configuration loaded at compile time via `--dart-define`.
///
/// Example build:
/// ```bash
/// flutter build web --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=your_anon_key
/// ```
class SupabaseConfig {
  /// URL Supabase - DOIT être fourni via flutter build --dart-define
  /// Exemple: flutter build web --dart-define=SUPABASE_URL=https://your-project.supabase.co
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Clé anon Supabase - DOIT être fourni via flutter build --dart-define
  /// Exemple: flutter build web --dart-define=SUPABASE_ANON_KEY=sb_your_anon_key
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
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
