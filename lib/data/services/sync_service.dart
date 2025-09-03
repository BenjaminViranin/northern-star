import 'dart:async';
import 'dart:convert';
// import 'dart:isolate'; // TODO: Implement background isolate
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    await _realtimeChannel?.subscribe();
  }

  void _handleRealtimeChange(String table, PostgresChangePayload payload) {
    // Handle real-time updates from Supabase
    // This would update local database with remote changes
    print('Realtime change in $table: ${payload.eventType}');
    // TODO: Implement conflict resolution and local update
  }

  Future<void> _performSync() async {
    if (_isSyncing) return;

    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    if (!SupabaseConfig.isAuthenticated) return;

    _isSyncing = true;

    try {
      // Process sync queue
      await _processSyncQueue();

      // Pull latest changes from server
      await _pullFromServer();
    } catch (e) {
      print('Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processSyncQueue() async {
    final pendingOps = await _database.getPendingSyncOperations();

    for (final op in pendingOps) {
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
          // TODO: Implement retry logic
        } else {
          // Max retries reached, remove from queue or handle differently
          await _database.removeSyncOperation(op.id);
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
    data['user_id'] = userId;

    final response = await SupabaseConfig.client.from(table).insert(data).select().single();

    // Update local record with server ID
    if (table == 'notes') {
      // TODO: Update local note with Supabase ID
    } else if (table == 'groups') {
      // TODO: Update local group with Supabase ID
    }
  }

  Future<void> _updateOnServer(String table, int localId, Map<String, dynamic> data, String userId) async {
    // Get local record to find Supabase ID
    // TODO: Implement update logic
  }

  Future<void> _deleteOnServer(String table, int localId, String userId) async {
    // TODO: Implement delete logic
  }

  Future<void> _pullFromServer() async {
    // TODO: Implement server pull logic
    // This should fetch latest changes and update local database
  }

  // Manual sync trigger
  Future<void> forcSync() async {
    await _performSync();
  }
}
