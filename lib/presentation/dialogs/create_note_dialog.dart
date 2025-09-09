import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../providers/database_provider.dart';
import '../providers/editor_provider.dart';

class CreateNoteDialog extends ConsumerStatefulWidget {
  const CreateNoteDialog({super.key});

  @override
  ConsumerState<CreateNoteDialog> createState() => _CreateNoteDialogState();
}

class _CreateNoteDialogState extends ConsumerState<CreateNoteDialog> {
  final _titleController = TextEditingController();
  int? _selectedGroupId;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);

    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      title: const Text(
        'Create New Note',
        style: TextStyle(color: AppTheme.textPrimary),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Note Title',
                hintText: 'Enter note title...',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            groups.when(
              data: (groupList) => DropdownButtonFormField<int>(
                value: _selectedGroupId,
                decoration: const InputDecoration(
                  labelText: 'Group',
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
                validator: (value) {
                  if (value == null) {
                    return 'Please select a group';
                  }
                  return null;
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
          onPressed: _isLoading ? null : _createNote,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createNote() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a note title')),
      );
      return;
    }

    if (_selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a group')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(notesRepositoryProvider);
      final noteId = await repository.createNote(
        title: _titleController.text.trim(),
        content: '[{"insert":"\\n"}]', // Valid Quill Delta with newline
        groupId: _selectedGroupId!,
      );

      // Set as current note
      ref.read(currentNoteIdProvider.notifier).state = noteId;

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating note: $e')),
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
