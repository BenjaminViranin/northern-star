import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/keyboard_shortcuts_service.dart';
import '../../core/services/app_state_service.dart';
import '../providers/database_provider.dart';
import '../providers/session_provider.dart';
import '../widgets/rich_text_editor.dart';
import '../dialogs/create_note_dialog.dart';

/// Provider for managing split view state
final splitViewNotesProvider = StateProvider<List<int?>>((ref) => [null, null]);
final splitViewCountProvider = StateProvider<int>((ref) => 2);

class SplitViewScreen extends ConsumerStatefulWidget {
  const SplitViewScreen({super.key});

  @override
  ConsumerState<SplitViewScreen> createState() => _SplitViewScreenState();
}

class _SplitViewScreenState extends ConsumerState<SplitViewScreen> {
  @override
  void initState() {
    super.initState();

    // Restore split view state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreSplitViewState();
    });
  }

  @override
  void dispose() {
    // Save split view state when closing
    _saveSplitViewState();
    super.dispose();
  }

  void _restoreSplitViewState() {
    // Try to restore from app state service first
    final appStatePaneCount = AppStateService.getSplitViewPaneCount();
    final appStateNoteIds = AppStateService.getSplitViewNoteIds();

    if (appStateNoteIds.isNotEmpty) {
      ref.read(splitViewCountProvider.notifier).state = appStatePaneCount;
      ref.read(splitViewNotesProvider.notifier).state = appStateNoteIds;
    } else {
      // Fallback to session state
      final sessionState = ref.read(sessionProvider);
      if (sessionState.splitViewState != null) {
        final splitViewState = sessionState.splitViewState!;

        // Restore pane count
        ref.read(splitViewCountProvider.notifier).state = splitViewState.paneCount;

        // Restore note assignments
        ref.read(splitViewNotesProvider.notifier).state = splitViewState.noteIds;
      }
    }
  }

  void _saveSplitViewState() {
    final splitNotes = ref.read(splitViewNotesProvider);
    final splitCount = ref.read(splitViewCountProvider);

    // Save to both session provider and app state service
    ref.read(sessionProvider.notifier).saveSplitViewState(
          isActive: true,
          paneCount: splitCount,
          noteIds: splitNotes,
        );

    // Also save to app state service for persistence
    AppStateService.saveSplitViewEnabled(true);
    AppStateService.saveSplitViewPaneCount(splitCount);
    AppStateService.saveSplitViewNoteIds(splitNotes);
  }

  @override
  Widget build(BuildContext context) {
    // Only show split view on Windows
    if (!Platform.isWindows) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Split View'),
        ),
        body: const Center(
          child: Text(
            'Split view is only available on Windows',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    final splitNotes = ref.watch(splitViewNotesProvider);
    final splitCount = ref.watch(splitViewCountProvider);

    return Shortcuts(
      shortcuts: KeyboardShortcutsService.shortcuts,
      child: Actions(
        actions: KeyboardShortcutsService.getActions(context, ref),
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: AppTheme.backgroundDark,
            appBar: AppBar(
              title: const Text('Split View'),
              backgroundColor: AppTheme.surfaceDark,
              actions: [
                // Split count selector
                PopupMenuButton<int>(
                  icon: const Icon(Icons.view_column),
                  tooltip: 'Number of panes',
                  onSelected: (count) {
                    ref.read(splitViewCountProvider.notifier).state = count;
                    // Adjust the notes list to match the new count
                    final currentNotes = ref.read(splitViewNotesProvider);
                    final newNotes = List<int?>.filled(count, null);
                    for (int i = 0; i < count && i < currentNotes.length; i++) {
                      newNotes[i] = currentNotes[i];
                    }
                    ref.read(splitViewNotesProvider.notifier).state = newNotes;
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 2, child: Text('2 Panes')),
                    const PopupMenuItem(value: 3, child: Text('3 Panes')),
                    const PopupMenuItem(value: 4, child: Text('4 Panes')),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Create New Note',
                  onPressed: () => _showCreateNoteDialog(context),
                ),
              ],
            ),
            body: _buildSplitView(splitNotes, splitCount),
          ),
        ),
      ),
    );
  }

  Widget _buildSplitView(List<int?> splitNotes, int splitCount) {
    return Row(
      children: List.generate(splitCount, (index) {
        return Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: index < splitCount - 1 ? const Border(right: BorderSide(color: AppTheme.border)) : null,
            ),
            child: _buildPane(index, splitNotes[index]),
          ),
        );
      }),
    );
  }

  Widget _buildPane(int paneIndex, int? noteId) {
    return Column(
      children: [
        // Pane header with note selector
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceDark,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              Text(
                'Pane ${paneIndex + 1}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildNoteSelector(paneIndex, noteId),
              ),
            ],
          ),
        ),
        // Editor area
        Expanded(
          child: noteId != null
              ? RichTextEditor(noteId: noteId)
              : Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.note_add,
                          size: 64,
                          color: AppTheme.textSecondary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Select a note to edit',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildNoteSelector(int paneIndex, int? selectedNoteId) {
    final notes = ref.watch(filteredNotesProvider);

    return notes.when(
      data: (notesList) {
        return DropdownButtonFormField<int?>(
          value: selectedNoteId,
          decoration: const InputDecoration(
            hintText: 'Select a note...',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('No note selected'),
            ),
            ...notesList.map((note) => DropdownMenuItem<int?>(
                  value: note.id,
                  child: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
          ],
          onChanged: (value) {
            final currentNotes = ref.read(splitViewNotesProvider);
            final newNotes = List<int?>.from(currentNotes);
            newNotes[paneIndex] = value;
            ref.read(splitViewNotesProvider.notifier).state = newNotes;

            // Save split view state when notes change
            _saveSplitViewState();
          },
        );
      },
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Container(
        height: 48,
        padding: const EdgeInsets.all(8),
        child: Text(
          'Error loading notes: $error',
          style: const TextStyle(color: Colors.red, fontSize: 12),
        ),
      ),
    );
  }

  void _showCreateNoteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateNoteDialog(),
    );
  }
}

/// Extension to add split view navigation to the main app
extension SplitViewNavigation on BuildContext {
  void openSplitView() {
    if (Platform.isWindows) {
      Navigator.of(this).push(
        MaterialPageRoute(
          builder: (context) => const SplitViewScreen(),
        ),
      );
    }
  }
}

/// Provider for checking if split view is available
final isSplitViewAvailableProvider = Provider<bool>((ref) {
  return Platform.isWindows;
});

/// Widget for split view button in the main app
class SplitViewButton extends ConsumerWidget {
  const SplitViewButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAvailable = ref.watch(isSplitViewAvailableProvider);

    if (!isAvailable) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: const Icon(Icons.view_column),
      tooltip: 'Open Split View',
      onPressed: () => context.openSplitView(),
    );
  }
}

/// Responsive layout helper for split view
class SplitViewLayoutHelper {
  static int getOptimalPaneCount(double screenWidth) {
    if (screenWidth < 800) return 1;
    if (screenWidth < 1200) return 2;
    if (screenWidth < 1600) return 3;
    return 4;
  }

  static double getMinPaneWidth() => 300.0;

  static bool canFitPanes(double screenWidth, int paneCount) {
    return screenWidth >= (getMinPaneWidth() * paneCount);
  }
}
