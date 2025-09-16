import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:sqlite3/sqlite3.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Groups, Notes, SyncQueue, LocalHistory, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forUser(String userId) : super(_openConnectionForUser(userId));
  AppDatabase._(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Don't seed default groups here - they will be created by Supabase trigger
        // and synced down when user authenticates
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle future migrations here
      },
    );
  }

  // Group operations
  Future<List<Group>> getAllGroups() => (select(groups)..where((g) => g.isDeleted.equals(false))).get();

  Future<Group?> getGroupById(int id) => (select(groups)..where((g) => g.id.equals(id) & g.isDeleted.equals(false))).getSingleOrNull();

  Future<int> insertGroup(GroupsCompanion group) => into(groups).insert(group);

  Future<bool> updateGroup(int id, GroupsCompanion group) async {
    final result = await (update(groups)..where((g) => g.id.equals(id))).write(group);
    return result > 0;
  }

  Future<int> deleteGroup(int id) => (update(groups)..where((g) => g.id.equals(id))).write(const GroupsCompanion(isDeleted: Value(true)));

  // Note operations
  Future<List<Note>> getAllNotes() => (select(notes)..where((n) => n.isDeleted.equals(false))).get();

  Future<List<Note>> getNotesByGroup(int groupId) =>
      (select(notes)..where((n) => n.groupId.equals(groupId) & n.isDeleted.equals(false))).get();

  Future<Note?> getNoteById(int id) => (select(notes)..where((n) => n.id.equals(id) & n.isDeleted.equals(false))).getSingleOrNull();

  // Special method for sync operations that need to access deleted notes
  Future<Note?> getNoteByIdIncludingDeleted(int id) => (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();

  Future<int> insertNote(NotesCompanion note) => into(notes).insert(note);

  Future<bool> updateNote(int id, NotesCompanion note) async {
    final result = await (update(notes)..where((n) => n.id.equals(id))).write(note);
    return result > 0;
  }

  Future<int> softDeleteNote(int id) => (update(notes)..where((n) => n.id.equals(id))).write(const NotesCompanion(isDeleted: Value(true)));

  // Sync queue operations
  Future<List<SyncQueueData>> getPendingSyncOperations() => select(syncQueue).get();

  Future<int> addToSyncQueue(SyncQueueCompanion operation) => into(syncQueue).insert(operation);

  Future<int> removeSyncOperation(int id) => (delete(syncQueue)..where((s) => s.id.equals(id))).go();

  Future<bool> updateSyncOperationRetry(int id, int retryCount, DateTime nextRetryAt) async {
    final result = await (update(syncQueue)..where((s) => s.id.equals(id))).write(SyncQueueCompanion(
      retryCount: Value(retryCount),
      nextRetryAt: Value(nextRetryAt),
    ));
    return result > 0;
  }

  // Local history operations
  Future<int> addToLocalHistory(LocalHistoryCompanion history) => into(localHistory).insert(history);

  // Settings operations
  Future<String?> getSetting(String key) async {
    final result = await (select(appSettings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return result?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await into(appSettings).insertOnConflictUpdate(AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
    ));
  }

  /// Clear all user data from the database (for logout)
  Future<void> clearAllUserData() async {
    await transaction(() async {
      await delete(notes).go();
      await delete(groups).go();
      await delete(syncQueue).go();
      await delete(localHistory).go();
      await delete(appSettings).go();
    });
  }

  /// Get the database file path for debugging
  Future<String> getDatabasePath() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, 'northern_star.db');
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'northern_star.db'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}

LazyDatabase _openConnectionForUser(String userId) {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    // Create user-specific database file
    final sanitizedUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File(p.join(dbFolder.path, 'northern_star_$sanitizedUserId.db'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}
