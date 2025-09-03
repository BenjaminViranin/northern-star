import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../providers/database_provider.dart';
import '../providers/editor_provider.dart';
import '../widgets/rich_text_editor.dart';
import '../dialogs/create_note_dialog.dart';
import '../dialogs/rename_note_dialog.dart';
import '../dialogs/delete_confirmation_dialog.dart';

class NotesTab extends ConsumerWidget {
  const NotesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredNotes = ref.watch(filteredNotesProvider);
    final groups = ref.watch(groupsProvider);
    final selectedGroupId = ref.watch(selectedGroupProvider);
    final currentNoteId = ref.watch(currentNoteIdProvider);

    return Row(
      children: [
        // Left Panel - Notes List
        Expanded(
          flex: 1,
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.surfaceDark,
              border: Border(
                right: BorderSide(color: AppTheme.border),
              ),
            ),
            child: Column(
              children: [
                // Controls
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search notes...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          ref.read(searchQueryProvider.notifier).state = value;
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      // Group Filter
                      groups.when(
                        data: (groupList) => DropdownButtonFormField<int?>(
                          value: selectedGroupId,
                          decoration: const InputDecoration(
                            labelText: 'Filter by group',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All groups'),
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
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(group.name),
                                ],
                              ),
                            )),
                          ],
                          onChanged: (value) {
                            ref.read(selectedGroupProvider.notifier).state = value;
                          },
                        ),
                        loading: () => const CircularProgressIndicator(),
                        error: (error, stack) => Text('Error: $error'),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Create Note Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showCreateNoteDialog(context, ref),
                          icon: const Icon(Icons.add),
                          label: const Text('New Note'),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Notes List
                Expanded(
                  child: filteredNotes.when(
                    data: (notes) => ListView.builder(
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        final isSelected = note.id == currentNoteId;
                        
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryTeal.withOpacity(0.1) : null,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected ? Border.all(color: AppTheme.primaryTeal) : null,
                          ),
                          child: ListTile(
                            title: Text(
                              note.title,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              note.plainText,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: PopupMenuButton(
                              icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: const Row(
                                    children: [
                                      Icon(Icons.edit, size: 16),
                                      SizedBox(width: 8),
                                      Text('Rename'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: const Row(
                                    children: [
                                      Icon(Icons.delete, size: 16, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                switch (value) {
                                  case 'rename':
                                    _showRenameDialog(context, ref, note);
                                    break;
                                  case 'delete':
                                    _showDeleteDialog(context, ref, note);
                                    break;
                                }
                              },
                            ),
                            onTap: () {
                              ref.read(currentNoteIdProvider.notifier).state = note.id;
                            },
                          ),
                        );
                      },
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(child: Text('Error: $error')),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Right Panel - Editor
        Expanded(
          flex: 2,
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

  void _showRenameDialog(BuildContext context, WidgetRef ref, note) {
    showDialog(
      context: context,
      builder: (context) => RenameNoteDialog(note: note),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, note) {
    showDialog(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        title: 'Delete Note',
        message: 'Are you sure you want to delete "${note.title}"?',
        onConfirm: () async {
          final repository = ref.read(notesRepositoryProvider);
          await repository.deleteNote(note.id);
          
          // Clear selection if deleted note was selected
          if (ref.read(currentNoteIdProvider) == note.id) {
            ref.read(currentNoteIdProvider.notifier).state = null;
          }
        },
      ),
    );
  }
}
