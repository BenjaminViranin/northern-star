import '../database/database.dart';

class UserSetupService {
  final AppDatabase _database;

  UserSetupService(this._database);

  /// Ensures default groups exist for the current user
  /// This is a fallback in case the database trigger fails
  Future<void> ensureDefaultGroups() async {
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

      // Default groups created successfully
    } catch (e) {
      // Failed to create default groups - this is a fallback mechanism
      // In production, this would use a proper logging framework
    }
  }

  /// Sets up user data after successful authentication
  Future<void> setupUserData() async {
    try {
      // Ensure default groups exist
      await ensureDefaultGroups();

      // Could add other setup tasks here in the future
      // - Sync data from server
      // - Initialize user preferences
      // - etc.
    } catch (e) {
      // Don't throw - setup failures shouldn't prevent app usage
      // In production, this would use a proper logging framework
    }
  }
}
