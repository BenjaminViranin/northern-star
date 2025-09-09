import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../providers/database_provider.dart';
import '../providers/editor_provider.dart';
import '../dialogs/create_group_dialog.dart';
import '../dialogs/rename_note_dialog.dart';
import '../dialogs/move_note_dialog.dart';
import '../dialogs/delete_confirmation_dialog.dart';
import '../dialogs/edit_group_dialog.dart';

// Provider for tracking which group's notes are being viewed
final viewingGroupNotesProvider = StateProvider<int?>((ref) => null);

class GroupsTab extends ConsumerWidget {
  final TabController? tabController;

  const GroupsTab({super.key, this.tabController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewingGroupId = ref.watch(viewingGroupNotesProvider);

    if (viewingGroupId != null) {
      return _buildGroupNotesView(context, ref, viewingGroupId);
    }

    return _buildGroupsGridView(context, ref);
  }

  Widget _buildGroupsGridView(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 80, 16), // Extra right padding for button
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8), // Minimal space for floating button
              Expanded(
                child: groups.when(
                  data: (groupList) => GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 2,
                    ),
                    itemCount: groupList.length,
                    itemBuilder: (context, index) {
                      final group = groupList[index];
                      final noteCount = ref.watch(notesByGroupProvider(group.id));

                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            // Show notes for this group
                            ref.read(viewingGroupNotesProvider.notifier).state = group.id;
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Color(int.parse(group.color.substring(1), radix: 16) + 0xFF000000),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        group.name,
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (group.name != 'Uncategorized')
                                      PopupMenuButton(
                                        icon: const Icon(
                                          Icons.more_vert,
                                          color: AppTheme.textSecondary,
                                          size: 16,
                                        ),
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, size: 16),
                                                SizedBox(width: 8),
                                                Text('Edit'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
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
                                        onSelected: (value) {
                                          switch (value) {
                                            case 'edit':
                                              _showEditGroupDialog(context, group);
                                              break;
                                            case 'delete':
                                              _showDeleteGroupDialog(context, ref, group);
                                              break;
                                          }
                                        },
                                      ),
                                  ],
                                ),
                                const Spacer(),
                                noteCount.when(
                                  data: (notes) => Text(
                                    '${notes.length} note${notes.length == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  loading: () => const Text(
                                    'Loading...',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  error: (error, stack) => const Text(
                                    'Error',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
        ),

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
              onPressed: () => _showCreateGroupDialog(context),
            ),
          ),
        ),
      ],
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateGroupDialog(),
    );
  }

  void _showEditGroupDialog(BuildContext context, group) {
    showDialog(
      context: context,
      builder: (context) => EditGroupDialog(group: group),
    );
  }

  void _showDeleteGroupDialog(BuildContext context, WidgetRef ref, group) {
    showDialog(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        title: 'Delete Group',
        message: 'Are you sure you want to delete "${group.name}"? All notes in this group will be moved to Uncategorized.',
        onConfirm: () async {
          final repository = ref.read(groupsRepositoryProvider);
          await repository.deleteGroup(group.id);
        },
      ),
    );
  }

  Widget _buildGroupNotesView(BuildContext context, WidgetRef ref, int groupId) {
    final groupNotes = ref.watch(notesByGroupProvider(groupId));
    final groups = ref.watch(groupsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Column(
        children: [
          // Header with back button and group info
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceDark,
              border: Border(
                bottom: BorderSide(color: AppTheme.border),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                  onPressed: () {
                    ref.read(viewingGroupNotesProvider.notifier).state = null;
                  },
                ),
                const SizedBox(width: 8),
                groups.when(
                  data: (groupList) {
                    final group = groupList.firstWhere((g) => g.id == groupId);
                    return Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Color(int.parse(group.color.substring(1), radix: 16) + 0xFF000000),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          group.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (error, stack) => const SizedBox(),
                ),
              ],
            ),
          ),
          // Notes list
          Expanded(
            child: groupNotes.when(
              data: (notes) {
                if (notes.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.note_outlined,
                          size: 64,
                          color: AppTheme.textSecondary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No notes in this group',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          note.title,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          note.plainText.length > 100 ? '${note.plainText.substring(0, 100)}...' : note.plainText,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
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
                          onSelected: (value) => _handleNoteAction(context, ref, note, value),
                        ),
                        onTap: () {
                          // Set the note as current and switch to notes tab
                          ref.read(currentNoteIdProvider.notifier).state = note.id;
                          tabController?.animateTo(0);
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
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNoteAction(BuildContext context, WidgetRef ref, note, String action) async {
    final notesRepository = ref.read(notesRepositoryProvider);

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
              },
            ),
          );
        }
        break;
    }
  }
}
