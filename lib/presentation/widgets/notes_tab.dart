import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/database/database.dart';
import '../providers/database_provider.dart';
import '../providers/editor_provider.dart';
import '../widgets/rich_text_editor.dart';
import '../dialogs/create_note_dialog.dart';
import '../dialogs/rename_note_dialog.dart';
import '../dialogs/move_note_dialog.dart';
import '../dialogs/delete_confirmation_dialog.dart';

class NotesTab extends ConsumerWidget {
  const NotesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentNoteId = ref.watch(currentNoteIdProvider);
    final filteredNotes = ref.watch(filteredNotesProvider);

    return Column(
      children: [
        // Notes Dropdown and Add Button
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
              Expanded(
                child: filteredNotes.when(
                  data: (notes) {
                    // Ensure unique notes by ID to prevent dropdown errors
                    final uniqueNotes = <int, Note>{};
                    for (final note in notes) {
                      uniqueNotes[note.id] = note;
                    }
                    final notesList = uniqueNotes.values.toList();

                    return DropdownButtonFormField<int?>(
                      value: notesList.isEmpty ? null : (notesList.any((note) => note.id == currentNoteId) ? currentNoteId : null),
                      decoration: const InputDecoration(
                        hintText: 'Select a note...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: notesList.isEmpty
                          ? [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('No notes available'),
                              )
                            ]
                          : notesList
                              .map((note) => DropdownMenuItem<int?>(
                                    value: note.id,
                                    child: Text(
                                      note.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                      onChanged: (value) {
                        ref.read(currentNoteIdProvider.notifier).state = value;
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stack) => Text('Error: $error'),
                ),
              ),
              const SizedBox(width: 12),
              // Note Management Button
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.settings, color: AppTheme.textSecondary),
                  enabled: currentNoteId != null,
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
                  onSelected: (value) => _handleNoteAction(context, ref, value),
                ),
              ),
              const SizedBox(width: 12),
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

        // Main Content
        Expanded(
          child: RichTextEditor(noteId: currentNoteId),
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
    final currentNoteId = ref.read(currentNoteIdProvider);
    if (currentNoteId == null) return;

    final notesRepository = ref.read(notesRepositoryProvider);
    final note = await notesRepository.getNoteById(currentNoteId);

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
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => DeleteConfirmationDialog(
              title: 'Delete Note',
              message: 'Are you sure you want to delete "${note.title}"?',
              onConfirm: () async {
                await notesRepository.deleteNote(note.id);
                ref.read(currentNoteIdProvider.notifier).state = null;
              },
            ),
          );
        }
        break;
    }
  }
}
