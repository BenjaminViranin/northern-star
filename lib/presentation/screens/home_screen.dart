import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/keyboard_shortcuts_service.dart';
import '../../core/services/app_state_service.dart';
import '../providers/session_provider.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/main_content_area.dart';
import '../providers/database_provider.dart';
import '../screens/split_view_screen.dart';
import '../dialogs/create_note_dialog.dart';
import '../dialogs/create_group_dialog.dart';

// Navigation state provider
final navigationStateProvider = StateNotifierProvider<NavigationStateNotifier, NavigationState>((ref) {
  return NavigationStateNotifier();
});

enum NavigationSection { notes, groups, settings }

class NavigationState {
  final NavigationSection selectedSection;
  final Map<int, bool> groupExpandedState;
  final String searchQuery;
  final int? selectedGroupId;
  final int? selectedNoteId;

  const NavigationState({
    this.selectedSection = NavigationSection.notes,
    this.groupExpandedState = const {},
    this.searchQuery = '',
    this.selectedGroupId,
    this.selectedNoteId,
  });

  NavigationState copyWith({
    NavigationSection? selectedSection,
    Map<int, bool>? groupExpandedState,
    String? searchQuery,
    int? selectedGroupId,
    int? selectedNoteId,
    bool clearSelectedNoteId = false,
  }) {
    return NavigationState(
      selectedSection: selectedSection ?? this.selectedSection,
      groupExpandedState: groupExpandedState ?? this.groupExpandedState,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedGroupId: selectedGroupId ?? this.selectedGroupId,
      selectedNoteId: clearSelectedNoteId ? null : (selectedNoteId ?? this.selectedNoteId),
    );
  }
}

class NavigationStateNotifier extends StateNotifier<NavigationState> {
  NavigationStateNotifier() : super(const NavigationState()) {
    _initializeFromPersistedState();
  }

  Future<void> _initializeFromPersistedState() async {
    await AppStateService.initialize();

    // Restore state from persistence
    final selectedSection = AppStateService.getSelectedSection();
    final selectedGroupId = AppStateService.getSelectedGroupId();
    final searchQuery = AppStateService.getSearchQuery();
    final expandedGroups = AppStateService.getExpandedGroups();
    final lastNoteId = AppStateService.getLastNoteId();

    // Convert expanded groups set to map
    final expandedGroupsMap = <int, bool>{};
    for (final groupId in expandedGroups) {
      expandedGroupsMap[groupId] = true;
    }

    // Convert section string to enum
    NavigationSection section = NavigationSection.notes;
    if (selectedSection != null) {
      switch (selectedSection) {
        case 'notes':
          section = NavigationSection.notes;
          break;
        case 'groups':
          section = NavigationSection.groups;
          break;
        case 'settings':
          section = NavigationSection.settings;
          break;
      }
    }

    // Update state with restored values
    state = NavigationState(
      selectedSection: section,
      groupExpandedState: expandedGroupsMap,
      searchQuery: searchQuery,
      selectedGroupId: selectedGroupId,
      selectedNoteId: lastNoteId,
    );
  }

  void selectSection(NavigationSection section) {
    state = state.copyWith(selectedSection: section);
    _persistState();
  }

  void toggleGroupExpanded(int groupId) {
    final newExpandedState = Map<int, bool>.from(state.groupExpandedState);
    newExpandedState[groupId] = !(newExpandedState[groupId] ?? true);
    state = state.copyWith(groupExpandedState: newExpandedState);
    _persistState();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _persistState();
  }

  void selectGroup(int? groupId) {
    state = state.copyWith(selectedGroupId: groupId);
    _persistState();
  }

  void selectNote(int? noteId) {
    if (noteId == null) {
      state = state.copyWith(clearSelectedNoteId: true);
    } else {
      state = state.copyWith(selectedNoteId: noteId);
    }
    _persistState();
  }

  bool isGroupExpanded(int groupId) {
    return state.groupExpandedState[groupId] ?? true;
  }

  void restoreFromSession(NavigationState sessionState) {
    state = sessionState;
    _persistState();
  }

  void _persistState() {
    // Save current state to persistence
    final sectionString = state.selectedSection.toString().split('.').last;
    AppStateService.saveSelectedSection(sectionString);
    AppStateService.saveSelectedGroupId(state.selectedGroupId);
    AppStateService.saveSearchQuery(state.searchQuery);
    AppStateService.saveLastNoteId(state.selectedNoteId);

    // Save expanded groups
    final expandedGroups = state.groupExpandedState.entries.where((entry) => entry.value == true).map((entry) => entry.key).toSet();
    AppStateService.saveExpandedGroups(expandedGroups);
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  ProviderSubscription<String?>? _syncErrorSub;

  @override
  void initState() {
    super.initState();

    // Initialize services and restore session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });

    // Non-blocking sync error feedback (outside build)
    _syncErrorSub = ref.listenManual<String?>(syncErrorProvider, (previous, next) {
      if (next != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to sync with server. Showing local data.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _syncErrorSub?.close();
    super.dispose();
  }

  void _initializeServices() async {
    // Initialize sync service (simple initialization)
    ref.read(syncInitializationProvider);

    // Initialize and restore session
    final sessionNotifier = ref.read(sessionProvider.notifier);
    await sessionNotifier.initializeSession();

    // Restore navigation state if available
    final sessionState = ref.read(sessionProvider);
    if (sessionState.uiState != null && mounted) {
      final uiState = sessionState.uiState!;
      final navigationNotifier = ref.read(navigationStateProvider.notifier);

      // Restore navigation section
      if (uiState.selectedTabIndex >= 0 && uiState.selectedTabIndex < 3) {
        final sections = [NavigationSection.notes, NavigationSection.groups, NavigationSection.settings];
        navigationNotifier.selectSection(sections[uiState.selectedTabIndex]);
      }

      // Restore search query and selected group
      if (uiState.searchQuery != null) {
        navigationNotifier.setSearchQuery(uiState.searchQuery!);
      }
      if (uiState.selectedGroupId != null) {
        navigationNotifier.selectGroup(uiState.selectedGroupId);
      }
    }

    // Check if split view should be restored (Windows only)
    if (mounted) {
      _checkAndRestoreSplitView();
    }
  }

  void _checkAndRestoreSplitView() async {
    // Only on Windows
    if (!Platform.isWindows) return;

    // Check if split view was previously active
    final splitViewEnabled = AppStateService.getSplitViewEnabled();
    final splitViewNoteIds = AppStateService.getSplitViewNoteIds();

    // Also check session state as fallback
    final sessionState = ref.read(sessionProvider);
    final sessionSplitViewActive = sessionState.splitViewState?.isActive ?? false;

    // Only restore if split view was explicitly enabled AND has notes
    final shouldRestore = splitViewEnabled && splitViewNoteIds.isNotEmpty;
    final shouldRestoreFromSession = sessionSplitViewActive && (sessionState.splitViewState?.noteIds.isNotEmpty == true);

    if (shouldRestore || shouldRestoreFromSession) {
      print('  -> Restoring split view');
      // Small delay to ensure the main screen is fully loaded
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        // Navigate to split view
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const SplitViewScreen(),
          ),
        );
      }
    } else {
      print('  -> NOT restoring split view');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: KeyboardShortcutsService.shortcuts,
      child: Actions(
        actions: KeyboardShortcutsService.getActions(context, ref),
        child: Focus(
          autofocus: true,
          child: _buildResponsiveLayout(context),
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < AppConstants.mobileBreakpoint;

    if (isMobile) {
      return _buildMobileLayout(context);
    } else {
      return _buildDesktopLayout(context);
    }
  }

  Widget _buildMobileLayout(BuildContext context) {
    final navigationState = ref.watch(navigationStateProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      // Remove AppBar for mobile - content will handle its own headers
      body: const MainContentArea(),
      bottomNavigationBar: _buildBottomNavigationBar(context, navigationState),
      floatingActionButton: _buildMobileFloatingActionButton(context, navigationState),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: const Row(
        children: [
          // Left Sidebar
          SidebarNavigation(),

          // Main Content Area
          Expanded(
            child: MainContentArea(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context, NavigationState navigationState) {
    return AppBar(
      backgroundColor: AppTheme.surfaceDark,
      elevation: 0,
      title: Text(
        _getSectionTitle(navigationState.selectedSection),
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        if (navigationState.selectedSection == NavigationSection.notes) ...[
          IconButton(
            icon: const Icon(Icons.search, color: AppTheme.textPrimary),
            onPressed: () => _showMobileSearch(context),
          ),
          IconButton(
            icon: const Icon(Icons.view_column, color: AppTheme.textPrimary),
            onPressed: () => _openSplitView(context),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, NavigationState navigationState) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(
          top: BorderSide(color: AppTheme.border, width: 0.5),
        ),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryTeal,
        unselectedItemColor: AppTheme.textSecondary,
        currentIndex: _getSectionIndex(navigationState.selectedSection),
        onTap: (index) => _onBottomNavTap(index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.note),
            label: 'Notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Groups',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget? _buildMobileFloatingActionButton(BuildContext context, NavigationState navigationState) {
    if (navigationState.selectedSection != NavigationSection.notes) {
      return null;
    }

    // If a note is selected (editing mode), show return button
    if (navigationState.selectedNoteId != null) {
      return FloatingActionButton(
        backgroundColor: AppTheme.primaryTeal,
        foregroundColor: Colors.white,
        onPressed: () {
          // Return to notes list
          ref.read(navigationStateProvider.notifier).selectNote(null);
        },
        child: const Icon(Icons.arrow_back),
      );
    }

    // Otherwise show add button
    return FloatingActionButton(
      backgroundColor: AppTheme.primaryTeal,
      foregroundColor: Colors.white,
      onPressed: () => _showMobileActionMenu(context),
      child: const Icon(Icons.add),
    );
  }

  // Helper methods for mobile navigation
  String _getSectionTitle(NavigationSection section) {
    switch (section) {
      case NavigationSection.notes:
        return 'Notes';
      case NavigationSection.groups:
        return 'Groups';
      case NavigationSection.settings:
        return 'Settings';
    }
  }

  int _getSectionIndex(NavigationSection section) {
    switch (section) {
      case NavigationSection.notes:
        return 0;
      case NavigationSection.groups:
        return 1;
      case NavigationSection.settings:
        return 2;
    }
  }

  void _onBottomNavTap(int index) {
    final sections = [
      NavigationSection.notes,
      NavigationSection.groups,
      NavigationSection.settings,
    ];
    ref.read(navigationStateProvider.notifier).selectSection(sections[index]);
  }

  void _showMobileSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: MobileSearchDelegate(ref),
    );
  }

  void _openSplitView(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SplitViewScreen(),
      ),
    );
  }

  void _showMobileActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _buildMobileActionMenu(context),
    );
  }

  Widget _buildMobileActionMenu(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.note_add, color: AppTheme.primaryTeal),
            title: const Text(
              'New Note',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              _showCreateNoteDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.create_new_folder, color: AppTheme.primaryTeal),
            title: const Text(
              'New Group',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              _showCreateGroupDialog(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showCreateNoteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateNoteDialog(),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateGroupDialog(),
    );
  }
}

// Mobile search delegate for the search functionality
class MobileSearchDelegate extends SearchDelegate<String> {
  final WidgetRef ref;

  MobileSearchDelegate(this.ref);

  @override
  String get searchFieldLabel => 'Search notes...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: AppTheme.textSecondary),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return const Center(
        child: Text(
          'Start typing to search notes...',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    // Update the search query in the navigation state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navigationStateProvider.notifier).setSearchQuery(query);
    });

    final notes = ref.watch(notesProvider);

    return notes.when(
      data: (notesList) {
        final filteredNotes = notesList.where((note) {
          return note.title.toLowerCase().contains(query.toLowerCase()) || note.content.toLowerCase().contains(query.toLowerCase());
        }).toList();

        if (filteredNotes.isEmpty) {
          return const Center(
            child: Text(
              'No notes found',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredNotes.length,
          itemBuilder: (context, index) {
            final note = filteredNotes[index];
            return ListTile(
              title: Text(
                note.title,
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              subtitle: Text(
                note.content.length > 100 ? '${note.content.substring(0, 100)}...' : note.content,
                style: const TextStyle(color: AppTheme.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                ref.read(navigationStateProvider.notifier).selectNote(note.id);
                close(context, note.title);
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Error: $error',
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}
