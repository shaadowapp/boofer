class SupabaseConfig {
  static const String _rawUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _rawKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Use values from --dart-define if they exist and are not empty,
  // otherwise fallback to the hardcoded official production secrets.
  static const String url =
      _rawUrl != "" ? _rawUrl : 'https://fvjdohkfaxomtosiibua.supabase.co';

  static const String anonKey = _rawKey != ""
      ? _rawKey
      : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ2amRvaGtmYXhvbXRvc2lpYnVhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA5MDM3NDgsImV4cCI6MjA4NjQ3OTc0OH0.TNcqAUqLFPWpfYI-6RZjVQ25eyXGBEluzTd9Ps-RRXs';

  /// Validates that required values are available
  static void validate() {
    if (url.isEmpty || !url.startsWith('https://')) {
      throw Exception(
        'SUPABASE_URL invalid or empty. Fallback failed or missing.',
      );
    }
    if (anonKey.isEmpty || anonKey.length < 50) {
      throw Exception(
        'SUPABASE_ANON_KEY invalid or empty. Fallback failed or missing.',
      );
    }
  }
}
