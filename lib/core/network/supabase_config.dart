class SupabaseConfig {
  // SECURITY: Credentials must be provided via environment variables
  // Build with: flutter build appbundle --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  
  /// Validates that required environment variables are set
  static void validate() {
    if (url.isEmpty) {
      throw Exception(
        'SUPABASE_URL not configured. '
        'Build with --dart-define=SUPABASE_URL=your-url'
      );
    }
    if (anonKey.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY not configured. '
        'Build with --dart-define=SUPABASE_ANON_KEY=your-key'
      );
    }
  }
}
