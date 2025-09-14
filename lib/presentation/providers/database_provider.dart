import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/database/database.dart';
import '../../data/repositories/notes_repository.dart';
import '../../data/repositories/groups_repository.dart';
import '../../data/services/sync_service.dart';
import '../../data/services/user_setup_service.dart';
import '../../core/config/supabase_config.dart';

// Database instance provider
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

// Repository providers
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return NotesRepository(database);
});

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return GroupsRepository(database);
});

// Sync service provider
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

// Convenience provider for checking if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user != null,
    loading: () => false,
    error: (_, __) => false,
  );
});

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
