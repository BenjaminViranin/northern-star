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

  Future<int> createNote({
    required String title,
    required String content,
    required int groupId,
  }) async {
    final now = DateTime.now();
    final plainText = content; // Content is already plain text

    final note = NotesCompanion(
      title: Value(title),
      content: Value(content),
      markdown: const Value(''), // No longer used
      plainText: Value(plainText),
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
      'markdown': '',
      'plain_text': plainText,
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
    String? plainText;

    if (content != null) {
      plainText = content; // Content is already plain text
    }

    final note = NotesCompanion(
      title: title != null ? Value(title) : const Value.absent(),
      content: content != null ? Value(content) : const Value.absent(),
      markdown: const Value(''), // No longer used
      plainText: plainText != null ? Value(plainText) : const Value.absent(),
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

      await _addToSyncQueue('update', 'notes', id, {
        'id': currentNote.supabaseId,
        'title': title ?? currentNote.title,
        'content': content ?? currentNote.content,
        'markdown': '',
        'plain_text': plainText ?? currentNote.plainText,
        'group_id': groupId ?? currentNote.groupId,
        'updated_at': now.toIso8601String(),
      });

      // Trigger immediate sync if sync service is available
      await _triggerImmediateSync();
    }

    return success;
  }

  Future<bool> deleteNote(int id) async {
    final note = await _database.getNoteById(id);
    if (note == null) return false;

    final success = await _database.softDeleteNote(id) > 0;

    if (success && note.supabaseId != null) {
      await _addToSyncQueue('delete', 'notes', id, {
        'id': note.supabaseId,
      });

      // Trigger immediate sync if sync service is available
      await _triggerImmediateSync();
    }

    return success;
  }

  Future<List<Note>> searchNotes(String query) async {
    final allNotes = await getAllNotes();
    return allNotes
        .where(
            (note) => note.title.toLowerCase().contains(query.toLowerCase()) || note.plainText.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

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
