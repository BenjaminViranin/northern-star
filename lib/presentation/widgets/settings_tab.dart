import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';

import '../../core/theme/app_theme.dart';
import '../../core/config/supabase_config.dart';
import '../providers/database_provider.dart';
import '../../core/services/session_persistence_service.dart';

import '../dialogs/auth_dialog.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Account Section
            _buildSection(
              title: 'Account',
              children: [
                ListTile(
                  leading: const Icon(Icons.person, color: AppTheme.primaryTeal),
                  title: const Text(
                    'Authentication',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  subtitle: Consumer(
                    builder: (context, ref, child) {
                      final isAuthenticated = ref.watch(isAuthenticatedProvider);
                      final currentUser = ref.watch(currentUserProvider);
                      return Text(
                        isAuthenticated ? 'Signed in as ${currentUser?.email ?? 'Unknown'}' : 'Not signed in',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      );
                    },
                  ),
                  trailing: Consumer(
                    builder: (context, ref, child) {
                      final isAuthenticated = ref.watch(isAuthenticatedProvider);
                      return ElevatedButton(
                        onPressed: () => _handleAuth(context, ref),
                        child: Text(isAuthenticated ? 'Sign Out' : 'Sign In'),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Sync Section
            _buildSection(
              title: 'Sync',
              children: [
                ListTile(
                  leading: const Icon(Icons.sync, color: AppTheme.primaryTeal),
                  title: const Text(
                    'Manual Sync',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  subtitle: const Text(
                    'Force sync with Supabase',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  trailing: Consumer(
                    builder: (context, ref, child) {
                      final syncStatus = ref.watch(syncStatusProvider);
                      final syncError = ref.watch(syncErrorProvider);
                      final lastSyncTime = ref.watch(lastSyncTimeProvider);

                      return SizedBox(
                        width: 120,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: syncStatus == SyncStatus.syncing
                                  ? null
                                  : () async {
                                      final syncService = ref.read(syncServiceProvider);
                                      await syncService.forceSync();
                                    },
                              child: syncStatus == SyncStatus.syncing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Sync Now'),
                            ),
                            if (syncError != null)
                              Flexible(
                                child: Text(
                                  'Error: $syncError',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            else if (lastSyncTime != null)
                              Flexible(
                                child: Text(
                                  'Last sync: ${_formatSyncTime(lastSyncTime)}',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Debug Section
            _buildSection(
              title: 'Debug Info',
              children: [
                _buildDebugInfo(),
              ],
            ),

            const SizedBox(height: 24),

            // Backup Section
            _buildSection(
              title: 'Backup & Export',
              children: [
                ListTile(
                  leading: const Icon(Icons.download, color: AppTheme.primaryTeal),
                  title: const Text(
                    'Export Data',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  subtitle: const Text(
                    'Export all notes and groups to JSON',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _exportData(context, ref),
                    child: const Text('Export'),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.upload, color: AppTheme.primaryTeal),
                  title: const Text(
                    'Import Data',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  subtitle: const Text(
                    'Import notes and groups from JSON',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _importData(context, ref),
                    child: const Text('Import'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // About Section
            _buildSection(
              title: 'About',
              children: [
                const ListTile(
                  leading: Icon(Icons.info, color: AppTheme.primaryTeal),
                  title: Text(
                    'Northern Star',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  subtitle: Text(
                    'Version 1.0.0\nOffline-first note-taking app',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(children: children),
        ),
      ],
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    try {
      // Get all data
      final notesRepository = ref.read(notesRepositoryProvider);
      final groupsRepository = ref.read(groupsRepositoryProvider);

      final notes = await notesRepository.getAllNotes();
      final groups = await groupsRepository.getAllGroups();

      // Create export data
      final exportData = {
        'version': '1.0.0',
        'exported_at': DateTime.now().toIso8601String(),
        'groups': groups
            .map((g) => {
                  'id': g.id,
                  'name': g.name,
                  'color': g.color,
                  'created_at': g.createdAt.toIso8601String(),
                })
            .toList(),
        'notes': notes
            .map((n) => {
                  'id': n.id,
                  'title': n.title,
                  'content': n.content,
                  'group_id': n.groupId,
                  'created_at': n.createdAt.toIso8601String(),
                  'updated_at': n.updatedAt.toIso8601String(),
                })
            .toList(),
      };

      // Save to file
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Notes',
        fileName: 'northern_star_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(jsonEncode(exportData));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data exported successfully')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final data = jsonDecode(content);

        // Validate the import data structure
        if (!_validateImportData(data)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid import file format')),
            );
          }
          return;
        }

        // Show confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import Data'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This will import:'),
                const SizedBox(height: 8),
                Text('• ${(data['groups'] as List).length} groups'),
                Text('• ${(data['notes'] as List).length} notes'),
                const SizedBox(height: 16),
                const Text(
                  'Existing data will not be deleted. Duplicate groups will be renamed.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Import'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;

        // Perform the import
        await _performImport(data, ref);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data imported successfully')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  bool _validateImportData(Map<String, dynamic> data) {
    return data.containsKey('version') &&
        data.containsKey('groups') &&
        data.containsKey('notes') &&
        data['groups'] is List &&
        data['notes'] is List;
  }

  Future<void> _performImport(Map<String, dynamic> data, WidgetRef ref) async {
    final groupsRepository = ref.read(groupsRepositoryProvider);
    final notesRepository = ref.read(notesRepositoryProvider);

    // Map to track old group IDs to new group IDs
    final groupIdMap = <int, int>{};

    // Import groups first
    final importGroups = data['groups'] as List;
    for (final groupData in importGroups) {
      final oldId = groupData['id'] as int;
      final name = groupData['name'] as String;
      final color = groupData['color'] as String;

      // Check if group with same name already exists
      final existingGroups = await groupsRepository.getAllGroups();
      var finalName = name;
      var counter = 1;

      while (existingGroups.any((g) => g.name == finalName)) {
        finalName = '$name ($counter)';
        counter++;
      }

      // Create the group
      final newGroupId = await groupsRepository.createGroup(
        name: finalName,
        color: color,
      );

      groupIdMap[oldId] = newGroupId;
    }

    // Import notes
    final importNotes = data['notes'] as List;
    for (final noteData in importNotes) {
      final title = noteData['title'] as String;
      final content = noteData['content'] as String;
      final oldGroupId = noteData['group_id'] as int;

      // Map to new group ID
      final newGroupId = groupIdMap[oldGroupId];
      if (newGroupId != null) {
        await notesRepository.createNote(
          title: title,
          content: content,
          groupId: newGroupId,
        );
      }
    }
  }

  void _handleAuth(BuildContext context, WidgetRef ref) async {
    final isAuthenticated = ref.read(isAuthenticatedProvider);

    if (isAuthenticated) {
      // Sign out
      try {
        await SupabaseConfig.client.auth.signOut();
        await SessionPersistenceService.clearLastUserId();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signed out successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign out failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Show sign in dialog
      showDialog(
        context: context,
        builder: (context) => const AuthDialog(),
      );
    }
  }

  String _formatSyncTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Widget _buildDebugInfo() {
    return Consumer(
      builder: (context, ref, child) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _getDebugInfo(ref),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const ListTile(
                leading: CircularProgressIndicator(),
                title: Text('Loading debug info...'),
              );
            }

            final debugInfo = snapshot.data!;
            return Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.queue, color: Colors.orange),
                  title: const Text('Sync Queue'),
                  subtitle: Text('${debugInfo['syncQueueCount']} operations pending'),
                  trailing: Text('${debugInfo['readyOpsCount']} ready'),
                ),
                ListTile(
                  leading: const Icon(Icons.folder, color: Colors.blue),
                  title: const Text('Local Groups'),
                  subtitle: Text('${debugInfo['localGroupsCount']} total'),
                  trailing: Text('${debugInfo['unsyncedGroupsCount']} unsynced'),
                ),
                ListTile(
                  leading: const Icon(Icons.note, color: Colors.green),
                  title: const Text('Local Notes'),
                  subtitle: Text('${debugInfo['localNotesCount']} total'),
                  trailing: Text('${debugInfo['unsyncedNotesCount']} unsynced'),
                ),
                if (debugInfo['syncQueueOps'].isNotEmpty)
                  ExpansionTile(
                    leading: const Icon(Icons.list, color: Colors.red),
                    title: const Text('Queue Details'),
                    children: [
                      for (final op in debugInfo['syncQueueOps'])
                        ListTile(
                          dense: true,
                          title: Text('${op['operation']} ${op['table']}'),
                          subtitle: Text('Local ID: ${op['localId']}'),
                          trailing: Text('Retry: ${op['retryCount']}'),
                        ),
                    ],
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getDebugInfo(WidgetRef ref) async {
    try {
      final syncService = ref.read(syncServiceProvider);
      return await syncService.getDebugInfo();
    } catch (e) {
      return {
        'error': e.toString(),
        'syncQueueCount': 0,
        'readyOpsCount': 0,
        'localGroupsCount': 0,
        'unsyncedGroupsCount': 0,
        'localNotesCount': 0,
        'unsyncedNotesCount': 0,
        'syncQueueOps': [],
      };
    }
  }
}
