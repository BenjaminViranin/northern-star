import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/keyboard_shortcuts_service.dart';
import '../providers/session_provider.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/main_content_area.dart';
import '../providers/database_provider.dart';

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
  }) {
    return NavigationState(
      selectedSection: selectedSection ?? this.selectedSection,
      groupExpandedState: groupExpandedState ?? this.groupExpandedState,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedGroupId: selectedGroupId ?? this.selectedGroupId,
      selectedNoteId: selectedNoteId ?? this.selectedNoteId,
    );
  }
}

class NavigationStateNotifier extends StateNotifier<NavigationState> {
  NavigationStateNotifier() : super(const NavigationState());

  void selectSection(NavigationSection section) {
    state = state.copyWith(selectedSection: section);
  }

  void toggleGroupExpanded(int groupId) {
    final newExpandedState = Map<int, bool>.from(state.groupExpandedState);
    newExpandedState[groupId] = !(newExpandedState[groupId] ?? true);
    state = state.copyWith(groupExpandedState: newExpandedState);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void selectGroup(int? groupId) {
    state = state.copyWith(selectedGroupId: groupId);
  }

  void selectNote(int? noteId) {
    state = state.copyWith(selectedNoteId: noteId);
  }

  bool isGroupExpanded(int groupId) {
    return state.groupExpandedState[groupId] ?? true;
  }

  void restoreFromSession(NavigationState sessionState) {
    state = sessionState;
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();

    // Initialize services and restore session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  void _initializeServices() async {
    // Initialize sync service
    final syncService = ref.read(syncServiceProvider);
    syncService.initialize().catchError((error) {
      if (mounted) {
        debugPrint('Failed to initialize sync service: $error');
      }
    });

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
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: KeyboardShortcutsService.shortcuts,
      child: Actions(
        actions: KeyboardShortcutsService.getActions(context, ref),
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: AppTheme.backgroundDark,
            body: Row(
              children: [
                // Left Sidebar
                const SidebarNavigation(),

                // Main Content Area
                const Expanded(
                  child: MainContentArea(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
