import 'dart:async';
import 'dart:convert';
// import 'dart:isolate'; // TODO: Implement background isolate
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart';

import '../database/database.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/app_constants.dart';

class SyncService {
  final AppDatabase _database;
  final Connectivity _connectivity = Connectivity();

  Timer? _syncTimer;
  StreamSubscription? _connectivitySubscription;
  RealtimeChannel? _realtimeChannel;
  bool _isSyncing = false;

  // Callbacks for status updates
  Function(bool)? onSyncStatusChanged;
  Function(String?)? onSyncErrorChanged;
  Function(DateTime?)? onLastSyncTimeChanged;

  SyncService(this._database);

  Future<void> initialize() async {
    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none && !_isSyncing) {
        _performSync();
      }
    });

    // Set up periodic sync
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!_isSyncing) {
        _performSync();
      }
    });

    // Set up realtime subscriptions if authenticated
    if (SupabaseConfig.isAuthenticated) {
      await _setupRealtimeSubscriptions();
    }
  }

  Future<void> dispose() async {
    _syncTimer?.cancel();
    await _connectivitySubscription?.cancel();
    await _realtimeChannel?.unsubscribe();
  }

  Future<void> _setupRealtimeSubscriptions() async {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null) return;

    _realtimeChannel = SupabaseConfig.client
        .channel('sync_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _handleRealtimeChange('notes', payload),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'groups',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _handleRealtimeChange('groups', payload),
        )
        .subscribe();
  }

  void _handleRealtimeChange(String table, PostgresChangePayload payload) {
    // Handle real-time updates from Supabase
    print('Realtime change in $table: ${payload.eventType}');

    // Process the change asynchronously to avoid blocking the realtime stream
    _processRealtimeChange(table, payload).catchError((error) {
      print('Error processing realtime change: $error');
    });
  }

  Future<void> _processRealtimeChange(String table, PostgresChangePayload payload) async {
    try {
      final changeData = payload.newRecord ?? payload.oldRecord;
      if (changeData == null) return;

      final supabaseId = changeData['id'] as String?;
      if (supabaseId == null) return;

      print('🔄 Realtime change: $table ${payload.eventType} - ID: $supabaseId');

      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
          await _handleRealtimeInsert(table, changeData);
          break;
        case PostgresChangeEvent.update:
          await _handleRealtimeUpdate(table, changeData);
          break;
        case PostgresChangeEvent.delete:
          await _handleRealtimeDelete(table, supabaseId);
          break;
        default:
          break;
      }
    } catch (e, stackTrace) {
      print('❌ Error in realtime change handler: $e');
      print('Stack trace: $stackTrace');
      print('Payload: ${payload.toString()}');
    }
  }

  Future<void> _handleRealtimeInsert(String table, Map<String, dynamic> data) async {
    // For inserts, we can directly merge the new record
    if (table == 'groups') {
      await _mergeGroupsFromServer([data]);
    } else if (table == 'notes') {
      await _mergeNotesFromServer([data]);
    }
  }

  Future<void> _handleRealtimeUpdate(String table, Map<String, dynamic> data) async {
    // For updates, check for conflicts and merge
    final supabaseId = data['id'] as String;
    final serverUpdatedAt = DateTime.parse(data['updated_at']);

    if (table == 'groups') {
      final localGroups = await _database.getAllGroups();
      final existingGroup = localGroups.where((g) => g.supabaseId == supabaseId).firstOrNull;

      if (existingGroup != null) {
        // Check if local version has pending changes
        if (existingGroup.needsSync) {
          // Conflict detected - local has unsaved changes
          await _handleConflict(table, existingGroup.id, data);
        } else {
          // No conflict - apply server changes
          await _mergeGroupsFromServer([data]);
        }
      } else {
        // New group from server
        await _mergeGroupsFromServer([data]);
      }
    } else if (table == 'notes') {
      final localNotes = await _database.getAllNotes();
      final existingNote = localNotes.where((n) => n.supabaseId == supabaseId).firstOrNull;

      if (existingNote != null) {
        // Check if local version has pending changes
        if (existingNote.needsSync) {
          // Conflict detected - local has unsaved changes
          await _handleConflict(table, existingNote.id, data);
        } else {
          // No conflict - apply server changes
          await _mergeNotesFromServer([data]);
        }
      } else {
        // New note from server
        await _mergeNotesFromServer([data]);
      }
    }
  }

  Future<void> _handleRealtimeDelete(String table, String supabaseId) async {
    // Handle soft deletes from server
    if (table == 'groups') {
      final localGroups = await _database.getAllGroups();
      final existingGroup = localGroups.where((g) => g.supabaseId == supabaseId).firstOrNull;

      if (existingGroup != null && !existingGroup.isDeleted) {
        await _database.updateGroup(
            existingGroup.id,
            const GroupsCompanion(
              isDeleted: Value(true),
              needsSync: Value(false),
            ));
        print('📥 Soft deleted local group from server realtime');
      }
    } else if (table == 'notes') {
      final localNotes = await _database.getAllNotes();
      final existingNote = localNotes.where((n) => n.supabaseId == supabaseId).firstOrNull;

      if (existingNote != null && !existingNote.isDeleted) {
        await _database.updateNote(
            existingNote.id,
            const NotesCompanion(
              isDeleted: Value(true),
              needsSync: Value(false),
            ));
        print('📥 Soft deleted local note from server realtime');
      }
    }
  }

  Future<void> _handleConflict(String table, int localId, Map<String, dynamic> serverData) async {
    // Simple conflict resolution: last-write-wins based on timestamp
    // In a more sophisticated implementation, you might want to:
    // 1. Show a conflict resolution UI to the user
    // 2. Implement automatic merging strategies
    // 3. Create conflict backup records

    final serverUpdatedAt = DateTime.parse(serverData['updated_at']);

    if (table == 'groups') {
      final localGroup = await _database.getGroupById(localId);
      if (localGroup != null) {
        if (serverUpdatedAt.isAfter(localGroup.updatedAt)) {
          // Server wins - backup local version and apply server changes
          await _createConflictBackup(table, localId, localGroup.toJson());
          await _mergeGroupsFromServer([serverData]);
          print('⚠️ Conflict resolved: Server version applied for group ${localGroup.name}');
        } else {
          // Local wins - keep local changes and they will sync later
          print('⚠️ Conflict resolved: Local version kept for group ${localGroup.name}');
        }
      }
    } else if (table == 'notes') {
      final localNote = await _database.getNoteById(localId);
      if (localNote != null) {
        if (serverUpdatedAt.isAfter(localNote.updatedAt)) {
          // Server wins - backup local version and apply server changes
          await _createConflictBackup(table, localId, localNote.toJson());
          await _mergeNotesFromServer([serverData]);
          print('⚠️ Conflict resolved: Server version applied for note ${localNote.title}');
        } else {
          // Local wins - keep local changes and they will sync later
          print('⚠️ Conflict resolved: Local version kept for note ${localNote.title}');
        }
      }
    }
  }

  Future<void> _createConflictBackup(String table, int recordId, Map<String, dynamic> localData) async {
    await _database.addToLocalHistory(LocalHistoryCompanion(
      entityTable: Value(table),
      recordId: Value(recordId),
      data: Value(jsonEncode(localData)),
      operation: const Value('conflict_backup'),
    ));
  }

  Future<void> _performSync() async {
    if (_isSyncing) return;

    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      onSyncErrorChanged?.call('No internet connection');
      return;
    }

    if (!SupabaseConfig.isAuthenticated) {
      onSyncErrorChanged?.call('Not authenticated');
      return;
    }

    _isSyncing = true;
    onSyncStatusChanged?.call(true);
    onSyncErrorChanged?.call(null);

    try {
      // Process sync queue
      await _processSyncQueue();

      // Pull latest changes from server
      await _pullFromServer();

      // Sync completed successfully
      onLastSyncTimeChanged?.call(DateTime.now());
      onSyncErrorChanged?.call(null);
    } catch (e) {
      print('Sync error: $e');
      onSyncErrorChanged?.call(e.toString());
    } finally {
      _isSyncing = false;
      onSyncStatusChanged?.call(false);
    }
  }

  Future<void> _processSyncQueue() async {
    final allPendingOps = await _database.getPendingSyncOperations();

    // Filter operations that are ready to retry (not waiting for next retry time)
    final now = DateTime.now();
    final readyOps = allPendingOps.where((op) => op.nextRetryAt == null || op.nextRetryAt!.isBefore(now)).toList();

    // Sort operations to ensure dependencies are handled first
    // Groups should be synced before notes that reference them
    final sortedOps = _sortOperationsByDependency(readyOps);

    for (final op in sortedOps) {
      try {
        await _processSyncOperation(op);
        await _database.removeSyncOperation(op.id);
      } catch (e) {
        // Implement exponential backoff
        final nextRetry = DateTime.now().add(
          AppConstants.syncRetryDelay * (op.retryCount + 1),
        );

        if (op.retryCount < AppConstants.maxSyncRetries) {
          // Update retry count and next retry time
          await _database.updateSyncOperationRetry(op.id, op.retryCount + 1, nextRetry);
          print(
              '⚠️ Sync operation failed, will retry: ${op.operation} ${op.entityTable} (attempt ${op.retryCount + 1}/${AppConstants.maxSyncRetries})');
        } else {
          // Max retries reached, remove from queue or handle differently
          await _database.removeSyncOperation(op.id);
          print('❌ Sync operation failed permanently: ${op.operation} ${op.entityTable}');
        }
      }
    }
  }

  Future<void> _processSyncOperation(SyncQueueData op) async {
    final data = jsonDecode(op.data);
    final userId = SupabaseConfig.currentUser!.id;

    switch (op.operation) {
      case 'create':
        await _createOnServer(op.entityTable, data, userId);
        break;
      case 'update':
        await _updateOnServer(op.entityTable, op.localId, data, userId);
        break;
      case 'delete':
        await _deleteOnServer(op.entityTable, op.localId, userId);
        break;
    }
  }

  Future<void> _createOnServer(String table, Map<String, dynamic> data, String userId) async {
    // Prepare data for Supabase
    final serverData = Map<String, dynamic>.from(data);
    serverData['user_id'] = userId;

    // Remove local-only fields and IDs (let Supabase generate UUIDs)
    serverData.remove('local_id');
    serverData.remove('needs_sync');
    serverData.remove('id'); // Remove local integer ID

    // For notes, we need to handle group_id mapping
    if (table == 'notes' && serverData.containsKey('group_id')) {
      final localGroupId = serverData['group_id'] as int;
      final supabaseGroupId = await _getSupabaseIdForLocalId('groups', localGroupId);

      if (supabaseGroupId == null) {
        print('⚠️ Skipping note sync - group not synced yet (local group ID: $localGroupId)');
        return;
      }

      serverData['group_id'] = supabaseGroupId;
    }

    try {
      final response = await SupabaseConfig.client.from(table).insert(serverData).select().single();
      final supabaseId = response['id'] as String;

      // Update local record with Supabase ID
      await _updateLocalRecordWithSupabaseId(table, data, supabaseId);

      print('✅ Created $table on server: $supabaseId');
    } catch (e) {
      print('❌ Failed to create $table on server: $e');
      rethrow;
    }
  }

  Future<void> _updateOnServer(String table, int localId, Map<String, dynamic> data, String userId) async {
    // Get Supabase ID for the local record
    final supabaseId = await _getSupabaseIdForLocalId(table, localId);

    if (supabaseId == null) {
      print('⚠️ Cannot update $table on server - no Supabase ID found for local ID: $localId');
      return;
    }

    // Prepare data for Supabase
    final serverData = Map<String, dynamic>.from(data);
    serverData['user_id'] = userId;

    // Remove local-only fields
    serverData.remove('local_id');
    serverData.remove('needs_sync');
    serverData.remove('id');

    // For notes, handle group_id mapping
    if (table == 'notes' && serverData.containsKey('group_id')) {
      final localGroupId = serverData['group_id'] as int;
      final supabaseGroupId = await _getSupabaseIdForLocalId('groups', localGroupId);

      if (supabaseGroupId == null) {
        print('⚠️ Cannot update note on server - group not synced yet (local group ID: $localGroupId)');
        return;
      }

      serverData['group_id'] = supabaseGroupId;
    }

    try {
      await SupabaseConfig.client.from(table).update(serverData).eq('id', supabaseId);
      print('✅ Updated $table on server: $supabaseId');
    } catch (e) {
      print('❌ Failed to update $table on server: $e');
      rethrow;
    }
  }

  Future<void> _deleteOnServer(String table, int localId, String userId) async {
    // Get Supabase ID for the local record
    final supabaseId = await _getSupabaseIdForLocalId(table, localId);

    if (supabaseId == null) {
      print('⚠️ Cannot delete $table on server - no Supabase ID found for local ID: $localId');
      return;
    }

    try {
      // Use soft delete by updating is_deleted flag
      await SupabaseConfig.client.from(table).update({
        'is_deleted': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', supabaseId);

      print('✅ Soft deleted $table on server: $supabaseId');
    } catch (e) {
      print('❌ Failed to delete $table on server: $e');
      rethrow;
    }
  }

  /// Sorts sync operations to ensure dependencies are handled first
  List<SyncQueueData> _sortOperationsByDependency(List<SyncQueueData> operations) {
    final sortedOps = <SyncQueueData>[];

    // First, add all group operations (they have no dependencies)
    final groupOps = operations.where((op) => op.entityTable == 'groups').toList();
    sortedOps.addAll(groupOps);

    // Then, add note operations (they depend on groups)
    final noteOps = operations.where((op) => op.entityTable == 'notes').toList();
    sortedOps.addAll(noteOps);

    // Add any other operations
    final otherOps = operations.where((op) => op.entityTable != 'groups' && op.entityTable != 'notes').toList();
    sortedOps.addAll(otherOps);

    return sortedOps;
  }

  // Helper methods for ID mapping and local record management

  /// Gets the Supabase UUID for a local integer ID
  Future<String?> _getSupabaseIdForLocalId(String table, int localId) async {
    if (table == 'groups') {
      final group = await _database.getGroupById(localId);
      return group?.supabaseId;
    } else if (table == 'notes') {
      final note = await _database.getNoteById(localId);
      return note?.supabaseId;
    }
    return null;
  }

  /// Updates a local record with its Supabase ID after successful server creation
  Future<void> _updateLocalRecordWithSupabaseId(String table, Map<String, dynamic> originalData, String supabaseId) async {
    // Find the local record by matching the data
    if (table == 'groups') {
      final groups = await _database.getAllGroups();
      final matchingGroup = groups
          .where((g) => g.name == originalData['name'] && g.color == originalData['color'] && g.supabaseId == null && g.needsSync == true)
          .firstOrNull;

      if (matchingGroup != null) {
        await _database.updateGroup(
            matchingGroup.id,
            GroupsCompanion(
              supabaseId: Value(supabaseId),
              needsSync: const Value(false),
            ));
      }
    } else if (table == 'notes') {
      final notes = await _database.getAllNotes();
      final matchingNote = notes
          .where((n) =>
              n.title == originalData['title'] && n.content == originalData['content'] && n.supabaseId == null && n.needsSync == true)
          .firstOrNull;

      if (matchingNote != null) {
        await _database.updateNote(
            matchingNote.id,
            NotesCompanion(
              supabaseId: Value(supabaseId),
              needsSync: const Value(false),
            ));
      }
    }
  }

  Future<void> _pullFromServer() async {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null) return;

    try {
      // Pull groups from server
      final groupsResponse = await SupabaseConfig.client.from('groups').select().eq('user_id', userId).eq('is_deleted', false);

      // Ensure response is a List
      final groupsList = groupsResponse is List ? groupsResponse : <dynamic>[];
      print('📥 Pulled ${groupsList.length} groups from server');
      await _mergeGroupsFromServer(groupsList);

      // Pull notes from server
      final notesResponse = await SupabaseConfig.client.from('notes').select().eq('user_id', userId).eq('is_deleted', false);

      // Ensure response is a List
      final notesList = notesResponse is List ? notesResponse : <dynamic>[];
      print('📥 Pulled ${notesList.length} notes from server');
      await _mergeNotesFromServer(notesList);
    } catch (e) {
      print('❌ Failed to pull from server: $e');
    }
  }

  /// Merges groups from server into local database
  Future<void> _mergeGroupsFromServer(List<dynamic> serverGroups) async {
    try {
      print('🔄 Merging ${serverGroups.length} groups from server');
      for (final serverGroup in serverGroups) {
        if (serverGroup is! Map<String, dynamic>) {
          print('❌ Invalid group data type: ${serverGroup.runtimeType}');
          continue;
        }
        final supabaseId = serverGroup['id'] as String;
        final serverUpdatedAt = DateTime.parse(serverGroup['updated_at']);

        // Check if we already have this group locally
        final localGroups = await _database.getAllGroups();
        final existingGroup = localGroups.where((g) => g.supabaseId == supabaseId).firstOrNull;

        if (existingGroup == null) {
          // New group from server - create locally
          await _database.insertGroup(GroupsCompanion(
            name: Value(serverGroup['name']),
            color: Value(serverGroup['color']),
            createdAt: Value(DateTime.parse(serverGroup['created_at'])),
            updatedAt: Value(serverUpdatedAt),
            isDeleted: Value(serverGroup['is_deleted'] ?? false),
            supabaseId: Value(supabaseId),
            version: Value(serverGroup['version'] ?? 1),
            needsSync: const Value(false),
          ));
          print('📥 Created local group from server: ${serverGroup['name']}');
        } else {
          // Check for conflicts and merge
          if (serverUpdatedAt.isAfter(existingGroup.updatedAt)) {
            // Server version is newer - update local
            await _database.updateGroup(
                existingGroup.id,
                GroupsCompanion(
                  name: Value(serverGroup['name']),
                  color: Value(serverGroup['color']),
                  updatedAt: Value(serverUpdatedAt),
                  isDeleted: Value(serverGroup['is_deleted'] ?? false),
                  version: Value(serverGroup['version'] ?? 1),
                  needsSync: const Value(false),
                ));
            print('📥 Updated local group from server: ${serverGroup['name']}');
          }
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error merging groups from server: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Merges notes from server into local database
  Future<void> _mergeNotesFromServer(List<dynamic> serverNotes) async {
    try {
      print('🔄 Merging ${serverNotes.length} notes from server');
      for (final serverNote in serverNotes) {
        if (serverNote is! Map<String, dynamic>) {
          print('❌ Invalid note data type: ${serverNote.runtimeType}');
          continue;
        }
        final supabaseId = serverNote['id'] as String;
        final serverUpdatedAt = DateTime.parse(serverNote['updated_at']);

        // Check if we already have this note locally
        final localNotes = await _database.getAllNotes();
        final existingNote = localNotes.where((n) => n.supabaseId == supabaseId).firstOrNull;

        // Map server group_id to local group_id
        int? localGroupId;
        if (serverNote['group_id'] != null) {
          final serverGroupId = serverNote['group_id'] as String;
          final localGroups = await _database.getAllGroups();
          final matchingGroup = localGroups.where((g) => g.supabaseId == serverGroupId).firstOrNull;
          localGroupId = matchingGroup?.id;
        }

        if (existingNote == null) {
          // New note from server - create locally
          if (localGroupId != null) {
            await _database.insertNote(NotesCompanion(
              title: Value(serverNote['title']),
              content: Value(serverNote['content']),
              markdown: Value(serverNote['markdown']),
              plainText: Value(serverNote['plain_text']),
              groupId: Value(localGroupId),
              createdAt: Value(DateTime.parse(serverNote['created_at'])),
              updatedAt: Value(serverUpdatedAt),
              isDeleted: Value(serverNote['is_deleted'] ?? false),
              supabaseId: Value(supabaseId),
              version: Value(serverNote['version'] ?? 1),
              needsSync: const Value(false),
            ));
            print('📥 Created local note from server: ${serverNote['title']}');
          } else {
            print('⚠️ Skipping note from server - group not found: ${serverNote['title']}');
          }
        } else {
          // Check for conflicts and merge
          if (serverUpdatedAt.isAfter(existingNote.updatedAt) && localGroupId != null) {
            // Server version is newer - update local
            await _database.updateNote(
                existingNote.id,
                NotesCompanion(
                  title: Value(serverNote['title']),
                  content: Value(serverNote['content']),
                  markdown: Value(serverNote['markdown']),
                  plainText: Value(serverNote['plain_text']),
                  groupId: Value(localGroupId),
                  updatedAt: Value(serverUpdatedAt),
                  isDeleted: Value(serverNote['is_deleted'] ?? false),
                  version: Value(serverNote['version'] ?? 1),
                  needsSync: const Value(false),
                ));
            print('📥 Updated local note from server: ${serverNote['title']}');
          }
          // If local is newer or same, keep local version
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error merging notes from server: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Manual sync trigger
  Future<void> forceSync() async {
    await _performSync();
  }
}
