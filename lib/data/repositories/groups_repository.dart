import 'dart:convert';
import 'package:drift/drift.dart';

import '../database/database.dart';
import '../services/sync_service.dart';
import '../../core/constants/app_constants.dart';

class GroupsRepository {
  final AppDatabase _database;
  final SyncService? _syncService;

  GroupsRepository(this._database, [this._syncService]);

  // Local operations (always work offline)
  Future<List<Group>> getAllGroups() async {
    return await _database.getAllGroups();
  }

  Future<Group?> getGroupById(int id) async {
    return await _database.getGroupById(id);
  }

  Future<Group?> getUncategorizedGroup() async {
    final groups = await getAllGroups();
    return groups.where((g) => g.name == 'Uncategorized').firstOrNull;
  }

  /// Get available group colors from constants
  List<String> getAvailableColors() {
    return AppConstants.groupColors;
  }

  /// Get next available color for a new group
  Future<String> getNextAvailableColor() async {
    final existingGroups = await getAllGroups();
    final usedColors = existingGroups.map((g) => g.color).toSet();

    // Find first unused color
    for (final color in AppConstants.groupColors) {
      if (!usedColors.contains(color)) {
        return color;
      }
    }

    // If all colors are used, return the first one
    return AppConstants.groupColors.first;
  }

  Future<int> createGroup({
    required String name,
    required String color,
  }) async {
    final now = DateTime.now();

    final group = GroupsCompanion(
      name: Value(name),
      color: Value(color),
      createdAt: Value(now),
      updatedAt: Value(now),
      needsSync: const Value(true),
    );

    final id = await _database.insertGroup(group);

    // Add to sync queue
    await _addToSyncQueue('create', 'groups', id, {
      'name': name,
      'color': color,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    // Trigger immediate sync if sync service is available
    await _triggerImmediateSync();

    return id;
  }

  Future<bool> updateGroup({
    required int id,
    String? name,
    String? color,
  }) async {
    final now = DateTime.now();

    final group = GroupsCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      color: color != null ? Value(color) : const Value.absent(),
      updatedAt: Value(now),
      needsSync: const Value(true),
    );

    final success = await _database.updateGroup(id, group);

    if (success) {
      // Add to sync queue
      final updateData = <String, dynamic>{
        'updated_at': now.toIso8601String(),
      };

      if (name != null) updateData['name'] = name;
      if (color != null) updateData['color'] = color;

      await _addToSyncQueue('update', 'groups', id, updateData);
    }

    return success;
  }

  Future<void> deleteGroup(int id) async {
    // First, migrate all notes to Uncategorized
    final uncategorizedGroup = await getUncategorizedGroup();
    if (uncategorizedGroup != null) {
      final notesToMigrate = await _database.getNotesByGroup(id);
      for (final note in notesToMigrate) {
        await _database.updateNote(
            note.id,
            NotesCompanion(
              groupId: Value(uncategorizedGroup.id),
              updatedAt: Value(DateTime.now()),
              needsSync: const Value(true),
            ));
      }
    }

    // Then soft delete the group
    await _database.deleteGroup(id);

    // Add to sync queue
    await _addToSyncQueue('delete', 'groups', id, {
      'is_deleted': true,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _addToSyncQueue(String operation, String table, int localId, Map<String, dynamic> data) async {
    await _database.addToSyncQueue(SyncQueueCompanion(
      operation: Value(operation),
      entityTable: Value(table),
      localId: Value(localId),
      data: Value(jsonEncode(data)),
    ));
  }

  Future<void> _triggerImmediateSync() async {
    if (_syncService != null) {
      await _syncService!.triggerImmediateSync();
    }
  }
}
