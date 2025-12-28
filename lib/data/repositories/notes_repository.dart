import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../services/sync_service.dart';

class NotesRepository {
  final AppDatabase _database;
  final SyncService? _syncService;
  final _uuid = const Uuid();

  NotesRepository(this._database, [this._syncService]);

  // Local operations (always work offline)
  Future<List<Note>> getAllNotes() async {
    return await _database.getAllNotes();
  }

  Future<List<Note>> getNotesByGroup(int groupId) async {
    return await _database.getNotesByGroup(groupId);
  }

  Future<Note?> getNoteById(int id) async {
    return await _database.getNoteById(id);
  }

  Stream<Note?> watchNoteById(int id) {
    return _database.watchNoteById(id);
  }

  // Reactive streams - automatically update when data changes
  Stream<List<Note>> watchAllNotes() {
    return _database.watchAllNotes();
  }

  Stream<List<Note>> watchNotesByGroup(int groupId) {
    return _database.watchNotesByGroup(groupId);
  }

  Future<int> createNote({
    required String title,
    required String content,
    required int groupId,
  }) async {
    final now = DateTime.now();

    final note = NotesCompanion(
      title: Value(title),
      content: Value(content),
      groupId: Value(groupId),
      createdAt: Value(now),
      updatedAt: Value(now),
      needsSync: const Value(true),
    );

    final id = await _database.insertNote(note);

    // Add to sync queue with client UUID for conflict resolution
    await _addToSyncQueue('create', 'notes', id, {
      'client_id': _uuid.v4(), // Unique client ID for sync
      'title': title,
      'content': content,
      'group_id': groupId,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    // Trigger immediate sync if sync service is available
    await _triggerImmediateSync();

    return id;
  }

  Future<bool> updateNote({
    required int id,
    String? title,
    String? content,
    int? groupId,
  }) async {
    final now = DateTime.now();

    final note = NotesCompanion(
      title: title != null ? Value(title) : const Value.absent(),
      content: content != null ? Value(content) : const Value.absent(),
      groupId: groupId != null ? Value(groupId) : const Value.absent(),
      updatedAt: Value(now),
      needsSync: const Value(true),
      version: const Value.absent(), // Will be incremented by trigger
    );

    final success = await _database.updateNote(id, note);

    if (success) {
      // Get current note to include group_id in sync data
      final currentNote = await _database.getNoteById(id);
      if (currentNote == null) return false;

      // Add to sync queue - always include group_id for updates
      final updateData = <String, dynamic>{
        'group_id': groupId ?? currentNote.groupId, // Use new groupId or keep current
        'updated_at': now.toIso8601String(),
      };

      if (title != null) updateData['title'] = title;
      if (content != null) updateData['content'] = content;

      await _addToSyncQueue('update', 'notes', id, updateData);

      // Trigger immediate sync if sync service is available
      await _triggerImmediateSync();
    }

    return success;
  }

  Future<void> deleteNote(int id) async {
    print(' Deleting note with ID: $id');

    final result = await _database.softDeleteNote(id);
    print(' Soft delete result: $result rows affected');

    // Add to sync queue
    await _addToSyncQueue('delete', 'notes', id, {
      'is_deleted': true,
      'updated_at': DateTime.now().toIso8601String(),
    });

    print(' Added note deletion to sync queue');

    // Trigger immediate sync if sync service is available
    await _triggerImmediateSync();
  }

  Future<List<Note>> searchNotes(String query) async {
    if (query.isEmpty) return getAllNotes();

    final notes = await _database.getAllNotes();
    return notes
        .where((note) => note.title.toLowerCase().contains(query.toLowerCase()) || note.content.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // Helper methods
  Future<void> _addToSyncQueue(String operation, String table, int localId, Map<String, dynamic> data) async {
    print(' Adding to sync queue: $operation $table (localId: $localId)');
    print(' Data: ${jsonEncode(data)}');

    await _database.addToSyncQueue(SyncQueueCompanion(
      operation: Value(operation),
      entityTable: Value(table),
      localId: Value(localId),
      data: Value(jsonEncode(data)),
    ));

    print(' Successfully added to sync queue');
  }

  Future<void> _triggerImmediateSync() async {
    if (_syncService != null) {
      print(' Triggering immediate sync from notes repository...');
      await _syncService.triggerImmediateSync();
    } else {
      print(' Sync service not available, cannot trigger immediate sync');
    }
  }
}
