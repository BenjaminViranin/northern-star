import 'dart:async';
import 'dart:convert';
// import 'dart:isolate'; // Background isolate for future optimization
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart';

import '../database/database.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/app_constants.dart';

class SyncService {
  static SyncService? _instance;
  static AppDatabase? _currentDatabase;
  static bool _globalSyncInProgress = false;
  static DateTime? _lastSyncTime;

  final AppDatabase _database;
  final Connectivity _connectivity = Connectivity();

  Timer? _syncTimer;
  StreamSubscription? _connectivitySubscription;
  RealtimeChannel? _realtimeChannel;
  bool _isSyncing = false;
  bool _isInitialized = false;

  // Callbacks for status updates
  Function(bool)? onSyncStatusChanged;
  Function(String?)? onSyncErrorChanged;
  Function(DateTime?)? onLastSyncTimeChanged;

  SyncService._(this._database);

  /// Factory constructor that ensures only one instance exists per database
  factory SyncService(AppDatabase database) {
    // If we have an instance and it's for the same database, return it
    if (_instance != null && _currentDatabase == database) {
      return _instance!;
    }

    // Dispose old instance if database changed
    if (_instance != null && _currentDatabase != database) {
      print('🔄 Database changed, disposing old sync service');
      _instance!.dispose();
    }

    // Create new instance
    print('🔄 Creating new sync service instance');
    _instance = SyncService._(database);
    _currentDatabase = database;
    return _instance!;
  }

  /// Triggers immediate sync when new items are added to the queue
  Future<void> triggerImmediateSync() async {
    if (!_isSyncing && SupabaseConfig.isAuthenticated) {
      print('⚡ Triggering immediate sync for new queue items...');
      _performSync();
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ Sync service already initialized, skipping...');
      return;
    }

    _isInitialized = true;
    print('🔄 Initializing sync service...');

    // Listen to connectivity changes for immediate sync when connection is restored
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none && !_isSyncing) {
        print('📶 Network connection restored, syncing immediately...');
        _performSync();
      }
    });

    // Set up periodic sync (less frequent since we sync immediately on changes)
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!_isSyncing) {
        _performSync();
      }
    });

    // Set up realtime subscriptions if authenticated
    if (SupabaseConfig.isAuthenticated) {
      await _setupRealtimeSubscriptions();

      // Check for pending operations and sync immediately
      final pendingOps = await _database.getPendingSyncOperations();
      if (pendingOps.isNotEmpty && !_isSyncing) {
        print('🔄 Found ${pendingOps.length} pending operations on startup, syncing immediately...');
        _performSync();
      }
    }
  }

  Future<void> dispose() async {
    print('🔄 Disposing sync service...');
    _isInitialized = false;
    _syncTimer?.cancel();
    await _connectivitySubscription?.cancel();
    await _realtimeChannel?.unsubscribe();
    _syncTimer = null;
    _connectivitySubscription = null;
    _realtimeChannel = null;

    // Clear singleton instance if this is the current instance
    if (_instance == this) {
      _instance = null;
      _currentDatabase = null;
      print('🔄 Cleared singleton instance');
    }
  }

  /// Called when authentication state changes to set up or tear down realtime subscriptions
  Future<void> onAuthStateChanged(bool isAuthenticated) async {
    if (isAuthenticated) {
      // User signed in, set up realtime subscriptions
      await _setupRealtimeSubscriptions();
      // Trigger an immediate sync to pull any server changes
      if (!_isSyncing) {
        _performSync();
      }
    } else {
      // User signed out, tear down realtime subscriptions
      await _realtimeChannel?.unsubscribe();
      _realtimeChannel = null;
    }
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
        print('Soft deleted local group from server realtime');
      }
    } else if (table == 'notes') {
      final localNotes = await _database.getAllNotes();
      final existingNote = localNotes.where((n) => n.supabaseId == supabaseId).firstOrNull;

      if (existingNote != null && !existingNote.isDeleted) {
        await _recordServerConflict('notes', existingNote.id, {
          'id': supabaseId,
          'is_deleted': true,
          'updated_at': DateTime.now().toIso8601String(),
        }, 'server_delete');
        await _markNoteNeedsSync(existingNote.id);
        print('Preserved local note after server delete event');
      }
    }
  }

  Future<void> _handleConflict(String table, int localId, Map<String, dynamic> serverData) async {
    // Preserve local data and record the server version for manual resolution.
    if (table == 'groups') {
      final localGroup = await _database.getGroupById(localId);
      if (localGroup != null) {
        await _recordServerConflict(table, localId, serverData, 'realtime_conflict');
        print('Conflict preserved: Local version kept for group ${localGroup.name}');
      }
    } else if (table == 'notes') {
      final localNote = await _database.getNoteById(localId);
      if (localNote != null) {
        await _recordServerConflict(table, localId, serverData, 'realtime_conflict');
        print('Conflict preserved: Local version kept for note ${localNote.title}');
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

  Future<void> _recordServerConflict(String table, int localId, Map<String, dynamic> serverData, String reason) async {
    final payload = Map<String, dynamic>.from(serverData);
    payload['conflict_reason'] = reason;

    await _database.addToLocalHistory(LocalHistoryCompanion(
      entityTable: Value(table),
      recordId: Value(localId),
      data: Value(jsonEncode(payload)),
      operation: const Value('server_conflict'),
    ));
  }

  Future<void> _markNoteNeedsSync(int localId) async {
    await _database.updateNote(
      localId,
      NotesCompanion(
        needsSync: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  String _resolveNoteContent(String localContent, dynamic serverContent) {
    if (serverContent is! String) {
      return localContent;
    }
    if (serverContent.trim().isEmpty && localContent.trim().isNotEmpty) {
      return localContent;
    }
    return serverContent;
  }

  Future<void> _performSync() async {
    // Global sync lock to prevent multiple sync processes
    if (_globalSyncInProgress || _isSyncing) {
      print('⏭️ Sync already in progress, skipping...');
      return;
    }

    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      onSyncErrorChanged?.call('No internet connection');
      return;
    }

    if (!SupabaseConfig.isAuthenticated) {
      onSyncErrorChanged?.call('Not authenticated');
      return;
    }

    // Set global sync lock
    _globalSyncInProgress = true;
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
      _globalSyncInProgress = false; // Release global sync lock
      _lastSyncTime = DateTime.now();
      onSyncStatusChanged?.call(false);
    }
  }

  Future<void> _processSyncQueue() async {
    print('🔄 Starting comprehensive sync process...');

    // Step 1: Discover ALL local data that needs syncing (not just queue)
    await _discoverAndQueueAllUnsyncedData();

    // Step 2: Process queue with dependency resolution
    await _processQueueWithDependencyResolution();

    print('✅ Sync process completed');
  }

  /// Discovers all local data that needs syncing and adds to queue if missing
  Future<void> _discoverAndQueueAllUnsyncedData() async {
    print('🔍 Discovering all unsynced local data...');

    // Find all groups that need syncing
    final allGroups = await _database.getAllGroups();
    final unsyncedGroups = allGroups.where((g) => g.needsSync || g.supabaseId == null).toList();
    print('📋 Found ${unsyncedGroups.length} groups needing sync');

    // Find all notes that need syncing
    final allNotes = await _database.getAllNotes();
    final unsyncedNotes = allNotes.where((n) => n.needsSync || n.supabaseId == null).toList();
    print('📋 Found ${unsyncedNotes.length} notes needing sync');

    // Get existing queue operations to avoid duplicates
    final existingOps = await _database.getPendingSyncOperations();
    final existingGroupOps = existingOps.where((op) => op.entityTable == 'groups').map((op) => op.localId).toSet();
    final existingNoteOps = existingOps.where((op) => op.entityTable == 'notes').map((op) => op.localId).toSet();

    // Add missing group operations to queue
    for (final group in unsyncedGroups) {
      if (!existingGroupOps.contains(group.id)) {
        final operation = group.supabaseId == null ? 'create' : 'update';
        await _addGroupToSyncQueue(group, operation);
        print('➕ Added group to sync queue: ${group.name} ($operation)');
      }
    }

    // Add missing note operations to queue
    for (final note in unsyncedNotes) {
      if (!existingNoteOps.contains(note.id)) {
        final operation = note.supabaseId == null ? 'create' : 'update';
        await _addNoteToSyncQueue(note, operation);
        print('➕ Added note to sync queue: ${note.title} ($operation)');
      }
    }
  }

  /// Processes sync queue with intelligent dependency resolution
  Future<void> _processQueueWithDependencyResolution() async {
    final allPendingOps = await _database.getPendingSyncOperations();
    print('🔄 Processing sync queue: ${allPendingOps.length} total operations');

    // Filter operations that are ready to retry
    final now = DateTime.now();
    final readyOps = allPendingOps.where((op) => op.nextRetryAt == null || op.nextRetryAt!.isBefore(now)).toList();
    print('🔄 Ready operations: ${readyOps.length}');

    // Process with dependency resolution
    await _processOperationsWithDependencies(readyOps);
  }

  /// Adds a group to sync queue with proper data formatting
  Future<void> _addGroupToSyncQueue(Group group, String operation) async {
    final data = {
      'name': group.name,
      'color': group.color,
      'created_at': group.createdAt.toIso8601String(),
      'updated_at': group.updatedAt.toIso8601String(),
    };

    await _database.addToSyncQueue(SyncQueueCompanion(
      operation: Value(operation),
      entityTable: const Value('groups'),
      localId: Value(group.id),
      data: Value(jsonEncode(data)),
    ));
  }

  /// Adds a note to sync queue with proper data formatting
  Future<void> _addNoteToSyncQueue(Note note, String operation) async {
    final data = {
      'title': note.title,
      'content': note.content,
      'group_id': note.groupId,
      'created_at': note.createdAt.toIso8601String(),
      'updated_at': note.updatedAt.toIso8601String(),
    };

    await _database.addToSyncQueue(SyncQueueCompanion(
      operation: Value(operation),
      entityTable: const Value('notes'),
      localId: Value(note.id),
      data: Value(jsonEncode(data)),
    ));
  }

  /// Processes operations with intelligent dependency resolution
  Future<void> _processOperationsWithDependencies(List<SyncQueueData> operations) async {
    // Separate operations by type
    final groupOps = operations.where((op) => op.entityTable == 'groups').toList();
    final noteOps = operations.where((op) => op.entityTable == 'notes').toList();

    print('🔄 Processing ${groupOps.length} group operations first...');

    // Process all group operations first
    for (final op in groupOps) {
      await _processSingleOperation(op);
    }

    print('🔄 Processing ${noteOps.length} note operations...');

    // Process note operations with dependency checking
    for (final op in noteOps) {
      await _processNoteOperationWithDependencyResolution(op);
    }
  }

  /// Processes a note operation, automatically resolving group dependencies
  Future<void> _processNoteOperationWithDependencyResolution(SyncQueueData op) async {
    final data = jsonDecode(op.data);

    // For delete operations, we don't need group_id validation
    if (op.operation == 'delete') {
      print('🗑️ Processing delete operation for note (local ID: ${op.localId})');
      await _processSingleOperation(op);
      return;
    }

    final groupIdValue = data['group_id'];

    if (groupIdValue == null) {
      print('❌ Note has null group_id, removing from queue');
      await _database.removeSyncOperation(op.id);
      return;
    }

    final localGroupId = groupIdValue as int;

    // Check if the referenced group is synced
    final group = await _database.getGroupById(localGroupId);
    if (group == null) {
      print('❌ Note references non-existent group (ID: $localGroupId)');
      await _database.removeSyncOperation(op.id);
      return;
    }

    // If group doesn't have Supabase ID, sync it first
    if (group.supabaseId == null) {
      print('🔄 Auto-syncing dependency: group "${group.name}" for note "${data['title']}"');

      try {
        // Create group on server first
        await _createGroupOnServer(group);
        print('✅ Auto-synced group dependency: ${group.name}');

        // Now process the note
        await _processSingleOperation(op);
      } catch (e) {
        print('❌ Failed to auto-sync group dependency: $e');
        await _handleOperationFailure(op, e);
      }
    } else {
      // Group is already synced, process note normally
      await _processSingleOperation(op);
    }
  }

  /// Creates a group on server and updates local record
  Future<void> _createGroupOnServer(Group group) async {
    final userId = SupabaseConfig.currentUser!.id;
    final serverData = {
      'name': group.name,
      'color': group.color,
      'user_id': userId,
      'created_at': group.createdAt.toIso8601String(),
      'updated_at': group.updatedAt.toIso8601String(),
    };

    final response = await SupabaseConfig.client.from('groups').insert(serverData).select().single();
    final supabaseId = response['id'] as String;

    // Update local record with Supabase ID
    await _database.updateGroup(
      group.id,
      GroupsCompanion(
        supabaseId: Value(supabaseId),
        needsSync: const Value(false),
      ),
    );

    print('🔄 Created group on server: ${group.name} (${group.id} -> $supabaseId)');
  }

  /// Processes a single operation with proper error handling
  Future<void> _processSingleOperation(SyncQueueData op) async {
    print('🔄 Processing: ${op.operation} ${op.entityTable} (local ID: ${op.localId})');
    try {
      await _processSyncOperation(op);
      await _database.removeSyncOperation(op.id);
      print('✅ Completed: ${op.operation} ${op.entityTable} (local ID: ${op.localId})');
    } catch (e) {
      print('❌ Failed: ${op.operation} ${op.entityTable} (local ID: ${op.localId}) - $e');
      await _handleOperationFailure(op, e);
    }
  }

  /// Handles operation failures with intelligent retry logic
  Future<void> _handleOperationFailure(SyncQueueData op, dynamic error) async {
    final nextRetry = DateTime.now().add(
      AppConstants.syncRetryDelay * (op.retryCount + 1),
    );

    if (op.retryCount < AppConstants.maxSyncRetries) {
      await _database.updateSyncOperationRetry(op.id, op.retryCount + 1, nextRetry);
      print('⚠️ Will retry: ${op.operation} ${op.entityTable} (attempt ${op.retryCount + 1}/${AppConstants.maxSyncRetries})');
    } else {
      await _database.removeSyncOperation(op.id);
      print('❌ Permanently failed: ${op.operation} ${op.entityTable}');
    }
  }

  Future<void> _processSyncOperation(SyncQueueData op) async {
    final data = jsonDecode(op.data);
    final userId = SupabaseConfig.currentUser!.id;

    switch (op.operation) {
      case 'create':
        await _createOnServer(op.entityTable, op.localId, data, userId);
        break;
      case 'update':
        await _updateOnServer(op.entityTable, op.localId, data, userId);
        break;
      case 'delete':
        await _deleteOnServer(op.entityTable, op.localId, userId);
        break;
    }
  }

  Future<void> _createOnServer(String table, int localId, Map<String, dynamic> data, String userId) async {
    // Prepare data for Supabase
    final serverData = Map<String, dynamic>.from(data);
    serverData['user_id'] = userId;

    // Remove local-only fields and IDs (let Supabase generate UUIDs)
    serverData.remove('local_id');
    serverData.remove('needs_sync');
    serverData.remove('id'); // Remove local integer ID
    serverData.remove('client_id'); // Remove client ID used for conflict resolution

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

      // Update local record with Supabase ID using the local ID
      await _updateLocalRecordWithSupabaseIdByLocalId(table, localId, supabaseId);

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
      print('✅ Delete operation successful - $table was never synced to server (local ID: $localId)');
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
      final group = await _database.getGroupByIdIncludingDeleted(localId);
      print('🔍 Looking up group ID $localId: found=${group != null}, supabaseId=${group?.supabaseId}');
      return group?.supabaseId;
    } else if (table == 'notes') {
      // For notes, we need to look up even deleted notes for sync operations
      final note = await _database.getNoteByIdIncludingDeleted(localId);
      print('🔍 Looking up note ID $localId: found=${note != null}, supabaseId=${note?.supabaseId}');
      return note?.supabaseId;
    }
    return null;
  }

  /// Updates a local record with its Supabase ID after successful server creation using local ID
  Future<void> _updateLocalRecordWithSupabaseIdByLocalId(String table, int localId, String supabaseId) async {
    if (table == 'groups') {
      await _database.updateGroup(
          localId,
          GroupsCompanion(
            supabaseId: Value(supabaseId),
            needsSync: const Value(false),
          ));
      print('🔄 Updated local group $localId with Supabase ID: $supabaseId');
    } else if (table == 'notes') {
      await _database.updateNote(
          localId,
          NotesCompanion(
            supabaseId: Value(supabaseId),
            needsSync: const Value(false),
          ));
      print('🔄 Updated local note $localId with Supabase ID: $supabaseId');
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
          // Check if there's a local group with the same name that needs to be linked
          final matchingLocalGroup = localGroups.where((g) => g.name == serverGroup['name'] && g.supabaseId == null).firstOrNull;

          if (matchingLocalGroup != null) {
            // Update existing local group with Supabase ID instead of creating new one
            await _database.updateGroup(
                matchingLocalGroup.id,
                GroupsCompanion(
                  color: Value(serverGroup['color']),
                  updatedAt: Value(serverUpdatedAt),
                  isDeleted: Value(serverGroup['is_deleted'] ?? false),
                  supabaseId: Value(supabaseId),
                  version: Value(serverGroup['version'] ?? 1),
                  needsSync: const Value(false),
                ));
            print('📥 Linked local group to server: ${serverGroup['name']} (local ID: ${matchingLocalGroup.id})');
          } else {
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
          }
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
      print('Merging ${serverNotes.length} notes from server');
      for (final serverNote in serverNotes) {
        if (serverNote is! Map<String, dynamic>) {
          print('Invalid note data type: ${serverNote.runtimeType}');
          continue;
        }
        final supabaseId = serverNote['id'] as String;
        final serverUpdatedAt = DateTime.parse(serverNote['updated_at']);
        final serverDeleted = serverNote['is_deleted'] == true;

        final localNotes = await _database.getAllNotes();
        final existingNote = localNotes.where((n) => n.supabaseId == supabaseId).firstOrNull;

        int? localGroupId;
        if (serverNote['group_id'] != null) {
          final serverGroupId = serverNote['group_id'] as String;
          final localGroups = await _database.getAllGroups();
          final matchingGroup = localGroups.where((g) => g.supabaseId == serverGroupId).firstOrNull;
          localGroupId = matchingGroup?.id;
        }

        if (existingNote == null) {
          if (serverDeleted) {
            continue;
          }
          if (localGroupId != null) {
            await _database.insertNote(NotesCompanion(
              title: Value(serverNote['title']),
              content: Value(serverNote['content']),
              groupId: Value(localGroupId),
              createdAt: Value(DateTime.parse(serverNote['created_at'])),
              updatedAt: Value(serverUpdatedAt),
              isDeleted: Value(serverDeleted),
              supabaseId: Value(supabaseId),
              version: Value(serverNote['version'] ?? 1),
              needsSync: const Value(false),
            ));
            print('Created local note from server: ${serverNote['title']}');
          } else {
            print('Skipping note from server - group not found: ${serverNote['title']}');
          }
          continue;
        }

        if (serverDeleted && !existingNote.isDeleted) {
          await _recordServerConflict('notes', existingNote.id, serverNote, 'server_deleted');
          await _markNoteNeedsSync(existingNote.id);
          print('Preserved local note after server delete update: ${existingNote.title}');
          continue;
        }

        if (existingNote.needsSync) {
          await _recordServerConflict('notes', existingNote.id, serverNote, 'local_unsynced');
          print('Preserved local note with unsynced changes: ${existingNote.title}');
          continue;
        }

        if (serverUpdatedAt.isAfter(existingNote.updatedAt) && localGroupId != null) {
          final resolvedContent = _resolveNoteContent(existingNote.content, serverNote['content']);
          if (resolvedContent != existingNote.content) {
            await _createConflictBackup('notes', existingNote.id, existingNote.toJson());
          }

          await _database.updateNote(
              existingNote.id,
              NotesCompanion(
                title: Value(serverNote['title'] ?? existingNote.title),
                content: Value(resolvedContent),
                groupId: Value(localGroupId),
                updatedAt: Value(serverUpdatedAt),
                isDeleted: Value(serverDeleted),
                version: Value(serverNote['version'] ?? existingNote.version),
                needsSync: const Value(false),
              ));
          print('Updated local note from server: ${serverNote['title']}');
        }
      }
    } catch (e, stackTrace) {
      print('Error merging notes from server: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Manual sync trigger
  Future<void> forceSync() async {
    if (!_isInitialized) {
      await initialize();
    }
    if (_globalSyncInProgress || _isSyncing) {
      onSyncErrorChanged?.call('Sync already in progress');
      return;
    }
    await _performSync();
  }

  // Debug information
  Future<Map<String, dynamic>> getDebugInfo() async {
    try {
      final allPendingOps = await _database.getPendingSyncOperations();
      final now = DateTime.now();
      final readyOps = allPendingOps.where((op) => op.nextRetryAt == null || op.nextRetryAt!.isBefore(now)).toList();

      final allGroups = await _database.getAllGroups();
      final unsyncedGroups = allGroups.where((g) => g.needsSync || g.supabaseId == null).toList();

      final allNotes = await _database.getAllNotes();
      final unsyncedNotes = allNotes.where((n) => n.needsSync || n.supabaseId == null).toList();

      return {
        'syncQueueCount': allPendingOps.length,
        'readyOpsCount': readyOps.length,
        'localGroupsCount': allGroups.length,
        'unsyncedGroupsCount': unsyncedGroups.length,
        'localNotesCount': allNotes.length,
        'unsyncedNotesCount': unsyncedNotes.length,
        'syncQueueOps': allPendingOps
            .map((op) => {
                  'operation': op.operation,
                  'table': op.entityTable,
                  'localId': op.localId,
                  'retryCount': op.retryCount,
                  'nextRetryAt': op.nextRetryAt?.toIso8601String(),
                })
            .toList(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'syncQueueCount': 0,
        'readyOpsCount': 0,
        'localGroupsCount': 0,
        'unsyncedGroupsCount': 0,
        'localNotesCount': 0,
        'unsyncedNotesCount': 0,
        'syncQueueOps': [],
      };
    }
  }
}
