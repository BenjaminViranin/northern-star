import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/database/database.dart';
import '../../data/repositories/notes_repository.dart';
import '../../data/repositories/groups_repository.dart';
import '../../data/services/sync_service.dart';
import '../../data/services/user_setup_service.dart';
import '../../core/config/supabase_config.dart';

// Database instance provider - user-specific
final databaseProvider = Provider<AppDatabase>((ref) {
  final userId = ref.watch(currentUserIdProvider);

  if (userId != null) {
    // Create user-specific database
    return AppDatabase.forUser(userId);
  } else {
    // No user logged in - return default database (will be empty)
    return AppDatabase();
  }
});

// Repository providers
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final database = ref.watch(databaseProvider);
  final syncService = ref.watch(syncServiceProvider);
  return NotesRepository(database, syncService);
});

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  final database = ref.watch(databaseProvider);
  final syncService = ref.watch(syncServiceProvider);
  return GroupsRepository(database, syncService);
});

// Sync service provider with proper initialization
final syncServiceProvider = Provider<SyncService>((ref) {
  final database = ref.watch(databaseProvider);
  final syncService = SyncService(database);

  // Connect status callbacks
  syncService.onSyncStatusChanged = (isSyncing) {
    ref.read(syncStatusProvider.notifier).state = isSyncing ? SyncStatus.syncing : SyncStatus.idle;
  };

  syncService.onSyncErrorChanged = (error) {
    ref.read(syncErrorProvider.notifier).state = error;
    if (error != null) {
      ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
    }
  };

  syncService.onLastSyncTimeChanged = (time) {
    ref.read(lastSyncTimeProvider.notifier).state = time;
    if (time != null) {
      ref.read(syncStatusProvider.notifier).state = SyncStatus.success;
    }
  };

  return syncService;
});

// Sync service manager that handles initialization and auth state changes
final syncServiceManagerProvider = StateNotifierProvider<SyncServiceManager, SyncServiceState>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  final manager = SyncServiceManager(syncService);

  // Listen to authentication state changes
  ref.listen<bool>(isAuthenticatedProvider, (previous, next) {
    manager.handleAuthStateChange(next);
  });

  // Initialize with current auth state
  final isAuthenticated = ref.read(isAuthenticatedProvider);
  manager.handleAuthStateChange(isAuthenticated);

  return manager;
});

class SyncServiceState {
  final bool isInitialized;
  final String? error;

  const SyncServiceState({
    this.isInitialized = false,
    this.error,
  });

  SyncServiceState copyWith({
    bool? isInitialized,
    String? error,
  }) {
    return SyncServiceState(
      isInitialized: isInitialized ?? this.isInitialized,
      error: error,
    );
  }
}

class SyncServiceManager extends StateNotifier<SyncServiceState> {
  final SyncService _syncService;
  bool _wasAuthenticated = false;

  SyncServiceManager(this._syncService) : super(const SyncServiceState());

  void handleAuthStateChange(bool isAuthenticated) {
    if (isAuthenticated && !_wasAuthenticated) {
      // User just signed in, initialize sync service
      _initializeSyncService();
    } else if (!isAuthenticated && _wasAuthenticated) {
      // User signed out, dispose sync service
      _disposeSyncService();
    }
    _wasAuthenticated = isAuthenticated;
  }

  void _initializeSyncService() async {
    if (!state.isInitialized) {
      try {
        await _syncService.initialize();
        await _syncService.onAuthStateChanged(true); // User is authenticated
        state = state.copyWith(isInitialized: true, error: null);
        print('✅ Sync service initialized successfully');
      } catch (e) {
        state = state.copyWith(error: e.toString());
        print('❌ Failed to initialize sync service: $e');
      }
    }
  }

  void _disposeSyncService() async {
    if (state.isInitialized) {
      try {
        await _syncService.onAuthStateChanged(false); // User signed out
        await _syncService.dispose();
        state = state.copyWith(isInitialized: false, error: null);
        print('🔄 Sync service disposed');
      } catch (e) {
        state = state.copyWith(error: e.toString());
        print('❌ Failed to dispose sync service: $e');
      }
    }
  }

  SyncService get syncService => _syncService;
}

// User setup service provider
final userSetupServiceProvider = Provider<UserSetupService>((ref) {
  final database = ref.watch(databaseProvider);
  return UserSetupService(database);
});

// Notes state providers
final notesProvider = StreamProvider<List<Note>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  // Convert Future to Stream for real-time updates
  return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) => repository.getAllNotes());
});

final notesByGroupProvider = StreamProvider.family<List<Note>, int>((ref, groupId) {
  final repository = ref.watch(notesRepositoryProvider);
  return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) => repository.getNotesByGroup(groupId));
});

final noteByIdProvider = FutureProvider.family<Note?, int>((ref, noteId) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.getNoteById(noteId);
});

// Groups state providers
final groupsProvider = StreamProvider<List<Group>>((ref) {
  final repository = ref.watch(groupsRepositoryProvider);
  return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) => repository.getAllGroups());
});

// Selected group provider for filtering
final selectedGroupProvider = StateProvider<int?>((ref) => null);

// Search query provider
final searchQueryProvider = StateProvider<String>((ref) => '');

// Authentication state provider
final authStateProvider = StreamProvider<User?>((ref) {
  return SupabaseConfig.client.auth.onAuthStateChange.map((data) => data.session?.user);
});

// Current user ID provider
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user?.id,
    loading: () => null,
    error: (_, __) => null,
  );
});

// Convenience provider for checking if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user != null,
    loading: () => false,
    error: (_, __) => false,
  );
});

// User session manager that handles cleanup on logout
final userSessionManagerProvider = Provider<UserSessionManager>((ref) {
  return UserSessionManager(ref);
});

class UserSessionManager {
  final Ref _ref;
  String? _currentUserId;

  UserSessionManager(this._ref) {
    // Listen to auth state changes
    _ref.listen(currentUserIdProvider, (previous, next) {
      if (previous != next) {
        _handleUserChange(previous, next);
      }
    });
  }

  void _handleUserChange(String? previousUserId, String? currentUserId) {
    print('🔄 User session changed: $previousUserId -> $currentUserId');

    if (previousUserId != null && currentUserId != previousUserId) {
      // User signed out or different user signed in
      _cleanupPreviousUserSession(previousUserId);
    }

    _currentUserId = currentUserId;
  }

  void _cleanupPreviousUserSession(String userId) {
    print('🧹 Cleaning up session for user: $userId');

    // Invalidate all providers to force recreation with new user context
    _ref.invalidate(databaseProvider);
    _ref.invalidate(notesRepositoryProvider);
    _ref.invalidate(groupsRepositoryProvider);
    _ref.invalidate(syncServiceProvider);
    _ref.invalidate(selectedGroupProvider);
    _ref.invalidate(searchQueryProvider);

    print('✅ Session cleanup completed');
  }
}

// Current user provider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );
});

// Sync status provider
enum SyncStatus { idle, syncing, error, success }

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);

final lastSyncTimeProvider = StateProvider<DateTime?>((ref) => null);

final syncErrorProvider = StateProvider<String?>((ref) => null);

// Filtered notes provider
final filteredNotesProvider = StreamProvider<List<Note>>((ref) {
  final selectedGroupId = ref.watch(selectedGroupProvider);
  final searchQuery = ref.watch(searchQueryProvider);
  final repository = ref.watch(notesRepositoryProvider);

  return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
    List<Note> notes;

    if (selectedGroupId != null) {
      notes = await repository.getNotesByGroup(selectedGroupId);
    } else {
      notes = await repository.getAllNotes();
    }

    if (searchQuery.isNotEmpty) {
      notes = notes
          .where((note) =>
              note.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
              note.plainText.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }

    return notes;
  });
});
