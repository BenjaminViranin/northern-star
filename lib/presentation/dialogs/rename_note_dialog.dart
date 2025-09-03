import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/database/database.dart';
import '../providers/database_provider.dart';

class RenameNoteDialog extends ConsumerStatefulWidget {
  final Note note;

  const RenameNoteDialog({
    super.key,
    required this.note,
  });

  @override
  ConsumerState<RenameNoteDialog> createState() => _RenameNoteDialogState();
}

class _RenameNoteDialogState extends ConsumerState<RenameNoteDialog> {
  late final TextEditingController _titleController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      title: const Text(
        'Rename Note',
        style: TextStyle(color: AppTheme.textPrimary),
      ),
      content: TextField(
        controller: _titleController,
        decoration: const InputDecoration(
          labelText: 'Note Title',
          hintText: 'Enter new title...',
        ),
        autofocus: true,
        onSubmitted: (_) => _renameNote(),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _renameNote,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Rename'),
        ),
      ],
    );
  }

  Future<void> _renameNote() async {
    final newTitle = _titleController.text.trim();
    
    if (newTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    if (newTitle == widget.note.title) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(notesRepositoryProvider);
      await repository.updateNote(
        id: widget.note.id,
        title: newTitle,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error renaming note: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
