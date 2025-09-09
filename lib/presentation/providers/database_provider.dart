import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../../data/repositories/notes_repository.dart';
import '../../data/repositories/groups_repository.dart';
import '../../data/services/sync_service.dart';
import '../../data/services/user_setup_service.dart';

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
  return SyncService(database);
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

// Groups state providers
final groupsProvider = StreamProvider<List<Group>>((ref) {
  final repository = ref.watch(groupsRepositoryProvider);
  return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) => repository.getAllGroups());
});

// Selected group provider for filtering
final selectedGroupProvider = StateProvider<int?>((ref) => null);

// Search query provider
final searchQueryProvider = StateProvider<String>((ref) => '');

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
