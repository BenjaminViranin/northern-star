import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/editor_provider.dart' as editor_provider;
import '../../core/theme/app_theme.dart';

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
}
