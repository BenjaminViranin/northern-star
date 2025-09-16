import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/database.dart';

class UserSetupService {
  final AppDatabase _database;

  UserSetupService(this._database);

  /// Creates default groups for new users
  /// This is called when a user first signs up to provide them with starter groups
  Future<void> ensureDefaultGroups() async {
    try {
      // Check if user already has groups locally
      final existingGroups = await _database.getAllGroups();

      if (existingGroups.isNotEmpty) {
        // User already has groups, no need to create defaults
        print('✅ User already has ${existingGroups.length} groups, skipping default group creation');
        return;
      }

      print('📝 Creating default groups for new user...');

      // Create default groups with distinct colors and sync enabled
      final defaultGroups = [
        GroupsCompanion.insert(
          name: 'Work',
          color: '#3B82F6', // Blue
          needsSync: const Value(true),
        ),
        GroupsCompanion.insert(
          name: 'Personal',
          color: '#10B981', // Green
          needsSync: const Value(true),
        ),
        GroupsCompanion.insert(
          name: 'Ideas',
          color: '#FBBF24', // Yellow
          needsSync: const Value(true),
        ),
        GroupsCompanion.insert(
          name: 'Tasks',
          color: '#EF4444', // Red
          needsSync: const Value(true),
        ),
        GroupsCompanion.insert(
          name: 'Uncategorized',
          color: '#6B7280', // Gray
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

      print('✅ Created ${defaultGroups.length} default groups');
    } catch (e) {
      print('❌ Failed to create default groups: $e');
      // Failed to create default groups - this is a fallback mechanism
      // In production, this would use a proper logging framework
    }
  }

  /// Sets up user data after successful authentication
  Future<void> setupUserData() async {
    try {
      print('🚀 Starting user setup process...');

      // Ensure default groups exist
      await ensureDefaultGroups();

      print('✅ User setup completed successfully');

      // Could add other setup tasks here in the future
      // - Sync data from server
      // - Initialize user preferences
      // - etc.
    } catch (e) {
      print('❌ User setup failed: $e');
      // Don't throw - setup failures shouldn't prevent app usage
      // In production, this would use a proper logging framework
    }
  }
}
