import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Northern Star Supabase Project Configuration
  static const String supabaseUrl = 'https://xfsdvhqryzrieqmdecps.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhmc2R2aHFyeXpyaWVxbWRlY3BzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY4NjQ1MTEsImV4cCI6MjA3MjQ0MDUxMX0.adlSvEfshkLIXkzagnOfWe2tWNqRPwytCA0rzVXvqEo';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
      storageOptions: const StorageClientOptions(
        retryAttempts: 10,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;
}
