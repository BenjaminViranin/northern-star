import 'dart:convert';
import 'package:drift/drift.dart';
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

      // Create default groups with sync enabled
      final defaultGroups = [
        GroupsCompanion.insert(
          name: 'Work',
          color: '#14b8a6',
          needsSync: const Value(true),
        ),
        GroupsCompanion.insert(
          name: 'Personal',
          color: '#0d9488',
          needsSync: const Value(true),
        ),
        GroupsCompanion.insert(
          name: 'Ideas',
          color: '#0f766e',
          needsSync: const Value(true),
        ),
        GroupsCompanion.insert(
          name: 'Tasks',
          color: '#115e59',
          needsSync: const Value(true),
        ),
        GroupsCompanion.insert(
          name: 'Uncategorized',
          color: '#134e4a',
          needsSync: const Value(true),
        ),
      ];

      for (final group in defaultGroups) {
        final groupId = await _database.insertGroup(group);

        // Add to sync queue
        await _database.addToSyncQueue(SyncQueueCompanion(
          operation: const Value('create'),
          entityTable: const Value('groups'),
          localId: Value(groupId),
          data: Value(jsonEncode({
            'name': group.name.value,
            'color': group.color.value,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })),
        ));
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
