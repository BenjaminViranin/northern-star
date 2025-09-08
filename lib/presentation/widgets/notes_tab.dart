import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../providers/editor_provider.dart';
import '../widgets/rich_text_editor.dart';
import '../dialogs/create_note_dialog.dart';

class NotesTab extends ConsumerWidget {
  const NotesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentNoteId = ref.watch(currentNoteIdProvider);

    return Stack(
      children: [
        // Main Editor
        RichTextEditor(noteId: currentNoteId),

        // Floating Add Button
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () => _showCreateNoteDialog(context, ref),
            ),
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
}
