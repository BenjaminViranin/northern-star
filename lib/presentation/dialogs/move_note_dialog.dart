import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/database/database.dart';
import '../providers/database_provider.dart';

class MoveNoteDialog extends ConsumerStatefulWidget {
  final Note note;

  const MoveNoteDialog({super.key, required this.note});

  @override
  ConsumerState<MoveNoteDialog> createState() => _MoveNoteDialogState();
}

class _MoveNoteDialogState extends ConsumerState<MoveNoteDialog> {
  int? _selectedGroupId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.note.groupId;
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);

    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      title: const Text(
        'Move Note',
        style: TextStyle(color: AppTheme.textPrimary),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Move "${widget.note.title}" to:',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            groups.when(
              data: (groupList) => DropdownButtonFormField<int>(
                value: _selectedGroupId,
                decoration: const InputDecoration(
                  labelText: 'Group',
                  border: OutlineInputBorder(),
                ),
                items: groupList
                    .map((group) => DropdownMenuItem<int>(
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
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGroupId = value;
                  });
                },
              ),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error loading groups: $error'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _moveNote,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Move'),
        ),
      ],
    );
  }

  Future<void> _moveNote() async {
    if (_selectedGroupId == null || _selectedGroupId == widget.note.groupId) {
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
        groupId: _selectedGroupId!,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note moved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error moving note: $e')),
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
