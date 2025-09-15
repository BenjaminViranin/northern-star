import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../screens/home_screen.dart';
import '../widgets/rich_text_editor.dart';
import '../widgets/settings_tab.dart';
import '../providers/database_provider.dart';

class MainContentArea extends ConsumerWidget {
  const MainContentArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationState = ref.watch(navigationStateProvider);

    return Container(
      color: AppTheme.backgroundDark,
      child: _buildContent(context, ref, navigationState),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, NavigationState navigationState) {
    switch (navigationState.selectedSection) {
      case NavigationSection.notes:
        return _buildNotesContent(context, ref, navigationState);
      case NavigationSection.groups:
        return _buildGroupsContent(context, ref);
      case NavigationSection.settings:
        return _buildSettingsContent(context, ref);
    }
  }

  Widget _buildNotesContent(BuildContext context, WidgetRef ref, NavigationState navigationState) {
    if (navigationState.selectedNoteId == null) {
      return _buildEmptyNoteState(context);
    }

    return Column(
      children: [
        // Note header with title and actions
        _buildNoteHeader(context, ref, navigationState),

        // Note editor
        Expanded(
          child: RichTextEditor(
            noteId: navigationState.selectedNoteId,
            readOnly: false,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyNoteState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add,
            size: 64,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a note to start editing',
            style: TextStyle(
              fontSize: 18,
              color: AppTheme.textSecondary.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a note from the sidebar or create a new one',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteHeader(BuildContext context, WidgetRef ref, NavigationState navigationState) {
    final noteId = navigationState.selectedNoteId!;
    final noteAsync = ref.watch(noteByIdProvider(noteId));

    return noteAsync.when(
      data: (note) {
        if (note == null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceDark,
              border: Border(
                bottom: BorderSide(color: AppTheme.border),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Note not found',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceDark,
            border: Border(
              bottom: BorderSide(color: AppTheme.border),
            ),
          ),
          child: Row(
            children: [
              // Note icon and title
              const Icon(
                Icons.description,
                size: 20,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.isEmpty ? 'Untitled' : note.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Last modified: ${_formatDate(note.updatedAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onPressed: () => _showNoteActions(context, ref, note),
                    tooltip: 'Note actions',
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          border: Border(
            bottom: BorderSide(color: AppTheme.border),
          ),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Loading note...',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
      error: (error, stack) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          border: Border(
            bottom: BorderSide(color: AppTheme.border),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              'Error loading note: $error',
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsContent(BuildContext context, WidgetRef ref) {
    // Use the existing GroupsTab but without the tab controller dependency
    return const GroupsManagementView();
  }

  Widget _buildSettingsContent(BuildContext context, WidgetRef ref) {
    // Use the existing SettingsTab
    return const SettingsTab();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  void _showNoteActions(BuildContext context, WidgetRef ref, dynamic note) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.textPrimary),
              title: const Text('Rename', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show rename dialog
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder, color: AppTheme.textPrimary),
              title: const Text('Move to Group', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show move dialog
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show delete confirmation
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Simplified groups management view without tab controller dependency
class GroupsManagementView extends ConsumerWidget {
  const GroupsManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Groups Management',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: groups.when(
              data: (groupsList) => ListView.builder(
                itemCount: groupsList.length,
                itemBuilder: (context, index) {
                  final group = groupsList[index];
                  return Card(
                    color: AppTheme.surfaceDark,
                    child: ListTile(
                      leading: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Color(int.parse(group.color.substring(1), radix: 16) + 0xFF000000),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(
                        group.name,
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                        onPressed: () => _showGroupActions(context, ref, group),
                      ),
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'Error loading groups: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupActions(BuildContext context, WidgetRef ref, dynamic group) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.textPrimary),
              title: const Text('Rename Group', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _showRenameGroupDialog(context, ref, group);
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette, color: AppTheme.textPrimary),
              title: const Text('Change Color', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _showChangeColorDialog(context, ref, group);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Group', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteGroupDialog(context, ref, group);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameGroupDialog(BuildContext context, WidgetRef ref, dynamic group) {
    final controller = TextEditingController(text: group.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Rename Group', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Group Name',
            labelStyle: TextStyle(color: AppTheme.textSecondary),
          ),
          style: const TextStyle(color: AppTheme.textPrimary),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                try {
                  final repository = ref.read(groupsRepositoryProvider);
                  await repository.updateGroup(
                    id: group.id,
                    name: controller.text.trim(),
                    color: group.color,
                  );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showChangeColorDialog(BuildContext context, WidgetRef ref, dynamic group) {
    // TODO: Implement color change dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Color change feature coming soon')),
    );
  }

  void _showDeleteGroupDialog(BuildContext context, WidgetRef ref, dynamic group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Delete Group', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${group.name}"? This action cannot be undone.',
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final repository = ref.read(groupsRepositoryProvider);
                await repository.deleteGroup(group.id);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
