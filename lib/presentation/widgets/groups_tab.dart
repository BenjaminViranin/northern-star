import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../providers/database_provider.dart';
import '../dialogs/create_group_dialog.dart';
import '../dialogs/edit_group_dialog.dart';
import '../dialogs/delete_confirmation_dialog.dart';

class GroupsTab extends ConsumerWidget {
  const GroupsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Groups',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCreateGroupDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('New Group'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Organize your notes into groups for better management.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
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
                        // Set filter to this group and switch to notes tab
                        ref.read(selectedGroupProvider.notifier).state = group.id;
                        // TODO: Switch to notes tab
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
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: const Row(
                                          children: [
                                            Icon(Icons.edit, size: 16),
                                            SizedBox(width: 8),
                                            Text('Edit'),
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
}
