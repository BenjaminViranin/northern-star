import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';

import '../providers/database_provider.dart';
import '../providers/editor_provider.dart';
import '../providers/session_provider.dart';
import '../widgets/rich_text_editor.dart';
import '../screens/split_view_screen.dart';
import '../dialogs/create_note_dialog.dart';
import '../dialogs/rename_note_dialog.dart';
import '../dialogs/move_note_dialog.dart';
import '../dialogs/delete_confirmation_dialog.dart';

class NotesTab extends ConsumerWidget {
  const NotesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentNoteId = ref.watch(currentNoteIdProvider);
    print('🔧 NotesTab build - currentNoteId: $currentNoteId');
    final filteredNotes = ref.watch(filteredNotesProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final selectedGroupId = ref.watch(selectedGroupProvider);

    // Restore session state on first build
    ref.listen(sessionProvider, (previous, next) {
      if (next.isInitialized && !next.isRestoring && previous?.isInitialized != true) {
        _restoreSessionState(ref, next);
      }
    });

    return Column(
      children: [
        // Search and Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceDark,
            border: Border(
              bottom: BorderSide(color: AppTheme.border),
            ),
          ),
          child: Row(
            children: [
              // Search Bar
              Expanded(
                flex: 2,
                child: TextField(
                  onChanged: (value) {
                    ref.read(searchQueryProvider.notifier).state = value;
                  },
                  decoration: InputDecoration(
                    hintText: 'Search notes...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                            onPressed: () {
                              ref.read(searchQueryProvider.notifier).state = '';
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Group Filter Dropdown
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final groups = ref.watch(groupsProvider);
                    return groups.when(
                      data: (groupList) => DropdownButtonFormField<int?>(
                        value: selectedGroupId,
                        decoration: InputDecoration(
                          hintText: 'All Groups',
                          prefixIcon: const Icon(Icons.folder, color: AppTheme.textSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All Groups'),
                          ),
                          ...groupList.map((group) => DropdownMenuItem<int?>(
                                value: group.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Color(int.parse(group.color.substring(1), radix: 16) + 0xFF000000),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 1,
                                            offset: const Offset(0, 0.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        group.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                        onChanged: (value) {
                          ref.read(selectedGroupProvider.notifier).state = value;
                        },
                      ),
                      loading: () => const SizedBox(
                        height: 48,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stack) => const SizedBox(height: 48),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Split View Button (Windows only)
              const SplitViewButton(),
              const SizedBox(width: 12),
              // Add Note Button
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => _showCreateNoteDialog(context, ref),
                ),
              ),
            ],
          ),
        ),

        // Notes List and Editor
        Expanded(
          child: Row(
            children: [
              // Notes List Sidebar
              Container(
                width: 300,
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceDark,
                  border: Border(
                    right: BorderSide(color: AppTheme.border),
                  ),
                ),
                child: Column(
                  children: [
                    // Notes Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppTheme.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.note, color: AppTheme.primaryTeal),
                          const SizedBox(width: 8),
                          const Text(
                            'Notes',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (currentNoteId != null) ...[
                            Builder(builder: (context) {
                              print('🔧 PopupMenuButton being rendered for note ID: $currentNoteId');
                              return PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 16),
                                        SizedBox(width: 8),
                                        Text('Rename'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'move',
                                    child: Row(
                                      children: [
                                        Icon(Icons.folder, size: 16),
                                        SizedBox(width: 8),
                                        Text('Move to Group'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, size: 16, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  print('🔧 PopupMenuButton onSelected called with value: $value');
                                  _handleNoteAction(context, ref, value);
                                },
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                    // Notes List
                    Expanded(
                      child: filteredNotes.when(
                        data: (notes) {
                          if (notes.isEmpty) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.note_add,
                                    size: 48,
                                    color: AppTheme.textSecondary,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No notes found',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: notes.length,
                            itemBuilder: (context, index) {
                              final note = notes[index];
                              final isSelected = note.id == currentNoteId;

                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.primaryTeal.withOpacity(0.1) : null,
                                  borderRadius: BorderRadius.circular(8),
                                  border: isSelected ? Border.all(color: AppTheme.primaryTeal.withOpacity(0.3)) : null,
                                ),
                                child: ListTile(
                                  title: Text(
                                    note.title,
                                    style: TextStyle(
                                      color: isSelected ? AppTheme.primaryTeal : AppTheme.textPrimary,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    note.plainText.isEmpty ? 'Empty note' : note.plainText,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    print('🔧 Note selected: ${note.title} (ID: ${note.id})');
                                    ref.read(currentNoteIdProvider.notifier).state = note.id;
                                    print('🔧 currentNoteIdProvider set to: ${note.id}');
                                  },
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (error, stack) => Center(
                          child: Text(
                            'Error loading notes: $error',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Editor Area
              Expanded(
                child: RichTextEditor(noteId: currentNoteId),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCreateNoteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const CreateNoteDialog(),
    );
  }

  void _handleNoteAction(BuildContext context, WidgetRef ref, String action) async {
    print('🔧 _handleNoteAction called with action: $action');
    final currentNoteId = ref.read(currentNoteIdProvider);
    print('🔧 Current note ID: $currentNoteId');
    if (currentNoteId == null) return;

    final notesRepository = ref.read(notesRepositoryProvider);
    final note = await notesRepository.getNoteById(currentNoteId);
    print('🔧 Found note: ${note?.title} (ID: ${note?.id})');

    if (note == null) return;

    switch (action) {
      case 'rename':
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => RenameNoteDialog(note: note),
          );
        }
        break;
      case 'move':
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => MoveNoteDialog(note: note),
          );
        }
        break;
      case 'delete':
        print('🗑️ Delete action triggered for note: ${note.title} (ID: ${note.id})');
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => DeleteConfirmationDialog(
              title: 'Delete Note',
              message: 'Are you sure you want to delete "${note.title}"?',
              onConfirm: () async {
                print('🗑️ Delete confirmed, calling repository.deleteNote(${note.id})');
                await notesRepository.deleteNote(note.id);
                ref.read(currentNoteIdProvider.notifier).state = null;
                print('🗑️ Note deletion completed');
              },
            ),
          );
        }
        break;
    }
  }

  void _restoreSessionState(WidgetRef ref, SessionState sessionState) {
    final uiState = sessionState.uiState;
    final lastOpenedNotes = sessionState.lastOpenedNotes;

    if (uiState != null) {
      // Restore search query
      if (uiState.searchQuery != null && uiState.searchQuery!.isNotEmpty) {
        ref.read(searchQueryProvider.notifier).state = uiState.searchQuery!;
      }

      // Restore selected group
      if (uiState.selectedGroupId != null) {
        ref.read(selectedGroupProvider.notifier).state = uiState.selectedGroupId;
      }
    }

    if (lastOpenedNotes != null) {
      // Restore last opened note
      if (lastOpenedNotes.mainEditorNoteId != null) {
        ref.read(currentNoteIdProvider.notifier).state = lastOpenedNotes.mainEditorNoteId;
      }
    }
  }
}
