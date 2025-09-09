import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/editor_provider.dart' as editor_provider;
import '../../core/theme/app_theme.dart';
import '../providers/database_provider.dart';
import '../dialogs/rename_note_dialog.dart';
import '../dialogs/move_note_dialog.dart';
import '../dialogs/delete_confirmation_dialog.dart';
import '../../data/database/database.dart';

class RichTextEditor extends ConsumerWidget {
  final int? noteId;
  final bool readOnly;

  const RichTextEditor({
    super.key,
    this.noteId,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (noteId == null) {
      return Container(
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
                'Create a new note to start writing',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final editorState = ref.watch(editor_provider.editorProvider(noteId));

    if (editorState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (editorState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error: ${editorState.error}',
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (!readOnly) _buildToolbar(context, ref),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: QuillProvider(
                configurations: QuillConfigurations(
                  controller: editorState.controller,
                ),
                child: QuillEditor.basic(
                  configurations: const QuillEditorConfigurations(
                    scrollable: true,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (editorState.isSaving || editorState.hasUnsavedChanges) _buildStatusBar(editorState),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceVariant,
        border: Border(
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(
        children: [
          // Note Management Menu
          PopupMenuButton<String>(
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
            onSelected: (value) => _handleNoteAction(context, ref, value),
          ),
          const SizedBox(width: 8),
          _buildToolbarButton(
            icon: Icons.format_bold,
            onPressed: () => ref.read(editor_provider.editorProvider(noteId).notifier).toggleBold(),
          ),
          _buildToolbarButton(
            icon: Icons.format_italic,
            onPressed: () => ref.read(editor_provider.editorProvider(noteId).notifier).toggleItalic(),
          ),
          _buildToolbarButton(
            icon: Icons.format_underlined,
            onPressed: () => ref.read(editor_provider.editorProvider(noteId).notifier).toggleUnderline(),
          ),
          _buildToolbarButton(
            icon: Icons.format_strikethrough,
            onPressed: () => ref.read(editor_provider.editorProvider(noteId).notifier).toggleStrikethrough(),
          ),
          const VerticalDivider(color: AppTheme.border),
          _buildToolbarButton(
            icon: Icons.code,
            onPressed: () => ref.read(editor_provider.editorProvider(noteId).notifier).toggleCodeBlock(),
          ),
          _buildToolbarButton(
            icon: Icons.checklist,
            onPressed: () => ref.read(editor_provider.editorProvider(noteId).notifier).insertCheckList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      color: AppTheme.textPrimary,
      splashRadius: 20,
    );
  }

  Widget _buildStatusBar(editor_provider.EditorState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceVariant,
        border: Border(
          top: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(
        children: [
          if (state.isSaving) ...[
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryTeal,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Saving...',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ] else if (state.hasUnsavedChanges) ...[
            const Icon(
              Icons.edit,
              size: 12,
              color: AppTheme.primaryTeal,
            ),
            const SizedBox(width: 8),
            const Text(
              'Unsaved changes',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ] else ...[
            const Icon(
              Icons.check_circle,
              size: 12,
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            const Text(
              'Saved',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleNoteAction(BuildContext context, WidgetRef ref, String action) async {
    if (noteId == null) return;

    final notesRepository = ref.read(notesRepositoryProvider);
    final note = await notesRepository.getNoteById(noteId!);

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
