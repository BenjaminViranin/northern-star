import '../../core/config/supabase_config.dart';
import '../../core/constants/app_constants.dart';
import '../database/database.dart';

class UserSetupService {
  final AppDatabase _database;

  UserSetupService(this._database);

  /// Ensures default groups exist for the current user
  /// This is a fallback in case the database trigger fails
  Future<void> ensureDefaultGroups() async {
    if (!SupabaseConfig.isAuthenticated) return;

    try {
      // Check if user already has groups
      final existingGroups = await _database.getAllGroups();

      if (existingGroups.isNotEmpty) {
        // User already has groups, no need to create defaults
        return;
      }

      // Create default groups
      final defaultGroups = [
        GroupsCompanion.insert(
          name: 'Work',
          color: '#14b8a6',
        ),
        GroupsCompanion.insert(
          name: 'Personal',
          color: '#0d9488',
        ),
        GroupsCompanion.insert(
          name: 'Ideas',
          color: '#0f766e',
        ),
        GroupsCompanion.insert(
          name: 'Tasks',
          color: '#115e59',
        ),
        GroupsCompanion.insert(
          name: 'Uncategorized',
          color: '#134e4a',
        ),
      ];

      for (final group in defaultGroups) {
        await _database.insertGroup(group);
      }

      print('Created default groups for user');
    } catch (e) {
      print('Failed to create default groups: $e');
      // Don't throw - this is a fallback mechanism
    }
  }

  /// Sets up user data after successful authentication
  Future<void> setupUserData() async {
    if (!SupabaseConfig.isAuthenticated) return;

    try {
      // Ensure default groups exist
      await ensureDefaultGroups();

      // Could add other setup tasks here in the future
      // - Sync data from server
      // - Initialize user preferences
      // - etc.
    } catch (e) {
      print('User setup failed: $e');
      // Don't throw - setup failures shouldn't prevent app usage
    }
  }
}
