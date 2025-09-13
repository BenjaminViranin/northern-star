import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';

import '../../core/theme/app_theme.dart';
import '../../core/config/supabase_config.dart';
import '../providers/database_provider.dart';
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
                  trailing: ElevatedButton(
                    onPressed: () async {
                      final syncService = ref.read(syncServiceProvider);
                      await syncService.forcSync();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sync completed')),
                        );
                      }
                    },
                    child: const Text('Sync Now'),
                  ),
                ),
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
                  'markdown': n.markdown,
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

        // TODO: Implement import logic
        // This would involve creating groups and notes from the imported data

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Import feature coming soon')),
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

  void _handleAuth(BuildContext context, WidgetRef ref) async {
    final isAuthenticated = ref.read(isAuthenticatedProvider);

    if (isAuthenticated) {
      // Sign out
      try {
        await SupabaseConfig.client.auth.signOut();
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
}
