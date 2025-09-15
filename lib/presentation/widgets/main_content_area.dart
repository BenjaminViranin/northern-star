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
              onTap: () async {
                Navigator.pop(context);
                print('🗑️ Delete action triggered for note: ${note.title} (ID: ${note.id})');

                // Show delete confirmation dialog
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppTheme.surfaceDark,
                    title: const Text('Delete Note', style: TextStyle(color: AppTheme.textPrimary)),
                    content: Text(
                      'Are you sure you want to delete "${note.title.isEmpty ? 'Untitled' : note.title}"?',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  print('🗑️ Delete confirmed, calling repository.deleteNote(${note.id})');
                  final notesRepository = ref.read(notesRepositoryProvider);
                  await notesRepository.deleteNote(note.id);

                  // Clear the selected note since it's been deleted
                  ref.read(navigationStateProvider.notifier).selectNote(null);
                  print('🗑️ Note deletion completed');
                }
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
                      subtitle: Consumer(
                        builder: (context, ref, child) {
                          final notes = ref.watch(notesProvider);
                          return notes.when(
                            data: (notesList) {
                              final groupNotes = notesList.where((note) => note.groupId == group.id).length;
                              return Text(
                                '$groupNotes notes',
                                style: const TextStyle(color: AppTheme.textSecondary),
                              );
                            },
                            loading: () => const Text('Loading...', style: TextStyle(color: AppTheme.textSecondary)),
                            error: (_, __) => const Text('Error', style: TextStyle(color: AppTheme.textSecondary)),
                          );
                        },
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                        onPressed: () => _showGroupActions(context, ref, group),
                      ),
                      onTap: () => _showGroupDetailView(context, ref, group),
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

  void _showGroupDetailView(BuildContext context, WidgetRef ref, dynamic group) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.surfaceDark,
        child: Container(
          width: 500,
          height: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Color(int.parse(group.color.substring(1), radix: 16) + 0xFF000000),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showRenameGroupDialog(context, ref, group);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Rename'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showChangeColorDialog(context, ref, group);
                      },
                      icon: const Icon(Icons.palette),
                      label: const Text('Color'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showDeleteGroupDialog(context, ref, group);
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Notes in group
              const Text(
                'Notes in this group:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Notes list
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final notes = ref.watch(notesProvider);
                    return notes.when(
                      data: (notesList) {
                        final groupNotes = notesList.where((note) => note.groupId == group.id).toList();

                        if (groupNotes.isEmpty) {
                          return const Center(
                            child: Text(
                              'No notes in this group yet',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: groupNotes.length,
                          itemBuilder: (context, index) {
                            final note = groupNotes[index];
                            return Card(
                              color: AppTheme.surfaceVariant,
                              child: ListTile(
                                leading: const Icon(Icons.description, color: AppTheme.textSecondary),
                                title: Text(
                                  note.title.isEmpty ? 'Untitled' : note.title,
                                  style: const TextStyle(color: AppTheme.textPrimary),
                                ),
                                subtitle: Text(
                                  note.plainText.length > 100 ? '${note.plainText.substring(0, 100)}...' : note.plainText,
                                  style: const TextStyle(color: AppTheme.textSecondary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  ref.read(navigationStateProvider.notifier).selectNote(note.id);
                                  ref.read(navigationStateProvider.notifier).selectSection(NavigationSection.notes);
                                },
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Center(
                        child: Text(
                          'Error loading notes: $error',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangeColorDialog(BuildContext context, WidgetRef ref, dynamic group) {
    final List<String> colors = [
      '#FF6B6B', // Red
      '#4ECDC4', // Teal (current primary)
      '#45B7D1', // Blue
      '#96CEB4', // Green
      '#FFEAA7', // Yellow
      '#DDA0DD', // Plum
      '#98D8C8', // Mint
      '#F7DC6F', // Light Yellow
      '#BB8FCE', // Light Purple
      '#85C1E9', // Light Blue
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Choose Group Color', style: TextStyle(color: AppTheme.textPrimary)),
        content: SizedBox(
          width: 300,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: colors.length,
            itemBuilder: (context, index) {
              final color = colors[index];
              final isSelected = group.color == color;

              return GestureDetector(
                onTap: () async {
                  try {
                    final repository = ref.read(groupsRepositoryProvider);
                    await repository.updateGroup(
                      id: group.id,
                      name: group.name,
                      color: color,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Group color updated successfully'),
                          backgroundColor: AppTheme.primaryTeal,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating color: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(int.parse(color.substring(1), radix: 16) + 0xFF000000),
                    shape: BoxShape.circle,
                    border: isSelected ? Border.all(color: AppTheme.textPrimary, width: 3) : Border.all(color: AppTheme.border, width: 1),
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
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
