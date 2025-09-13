import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/keyboard_shortcuts_service.dart';
import '../providers/session_provider.dart';
import '../widgets/notes_tab.dart';
import '../widgets/groups_tab.dart';
import '../widgets/settings_tab.dart';
import '../providers/database_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Listen to tab changes to save UI state
    _tabController.addListener(_onTabChanged);

    // Initialize services and restore session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  void _initializeServices() async {
    // Initialize sync service
    final syncService = ref.read(syncServiceProvider);
    syncService.initialize().catchError((error) {
      print('Failed to initialize sync service: $error');
    });

    // Initialize and restore session
    final sessionNotifier = ref.read(sessionProvider.notifier);
    await sessionNotifier.initializeSession();

    // Restore UI state if available
    final sessionState = ref.read(sessionProvider);
    if (sessionState.uiState != null) {
      final uiState = sessionState.uiState!;

      // Restore tab selection
      if (uiState.selectedTabIndex >= 0 && uiState.selectedTabIndex < 3) {
        _tabController.animateTo(uiState.selectedTabIndex);
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      // Save UI state when tab changes
      final sessionNotifier = ref.read(sessionProvider.notifier);
      sessionNotifier.saveUIState(
        selectedTabIndex: _tabController.index,
        searchQuery: null, // Will be updated by individual tabs
        selectedGroupId: null, // Will be updated by individual tabs
      );
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
            body: Column(
              children: [
                // Tab Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  decoration: const BoxDecoration(
                    color: AppTheme.surfaceDark,
                    border: Border(
                      bottom: BorderSide(color: AppTheme.border),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(icon: Icon(Icons.note, size: 28)),
                      Tab(icon: Icon(Icons.folder, size: 28)),
                      Tab(icon: Icon(Icons.settings, size: 28)),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      const NotesTab(),
                      GroupsTab(tabController: _tabController),
                      const SettingsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
