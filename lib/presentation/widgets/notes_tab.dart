import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../providers/database_provider.dart';
import '../providers/editor_provider.dart';
import '../widgets/rich_text_editor.dart';
import '../dialogs/create_note_dialog.dart';

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
                  data: (notes) => DropdownButtonFormField<int?>(
                    value: notes.any((note) => note.id == currentNoteId) ? currentNoteId : null,
                    decoration: const InputDecoration(
                      hintText: 'Select a note...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Select a note...'),
                      ),
                      ...notes.map((note) => DropdownMenuItem<int?>(
                            value: note.id,
                            child: Text(
                              note.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                    ],
                    onChanged: (value) {
                      ref.read(currentNoteIdProvider.notifier).state = value;
                    },
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stack) => Text('Error: $error'),
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
}
