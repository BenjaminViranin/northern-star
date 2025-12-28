import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/note_history_entry.dart';
import '../providers/database_provider.dart';

class NoteHistoryDialog extends ConsumerStatefulWidget {
  final int noteId;

  const NoteHistoryDialog({
    super.key,
    required this.noteId,
  });

  @override
  ConsumerState<NoteHistoryDialog> createState() => _NoteHistoryDialogState();
}

class _NoteHistoryDialogState extends ConsumerState<NoteHistoryDialog> {
  NoteHistoryEntry? _selected;
  bool _isRestoring = false;
  late Future<List<NoteHistoryEntry>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = ref.read(syncServiceProvider).getNoteHistory(widget.noteId);
  }

  @override
  Widget build(BuildContext context) {
    final syncService = ref.read(syncServiceProvider);

    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      title: const Text('Note History', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: 720,
        height: 420,
        child: FutureBuilder<List<NoteHistoryEntry>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Unable to load history',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return const Center(
                child: Text(
                  'No history entries found for this note.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              );
            }

            final selected = _selected ?? entries.first;
            if (_selected == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _selected = selected;
                  });
                }
              });
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final leftWidth = (constraints.maxWidth * 0.28).clamp(120.0, 200.0);
                return Row(
                  children: [
                    SizedBox(
                      width: leftWidth,
                      child: Material(
                        color: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: AppTheme.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: entries.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final isSelected = selected.id == entry.id;
                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              selectedColor: AppTheme.textPrimary,
                              selectedTileColor: AppTheme.primaryTeal.withOpacity(0.12),
                              title: Text(
                                _formatTimestamp(entry.changedAt),
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                              ),
                              onTap: () {
                                setState(() {
                                  _selected = entry;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildPreview(selected),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isRestoring ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: _selected == null || _isRestoring
              ? null
              : () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppTheme.surfaceDark,
                      title: const Text('Restore Note', style: TextStyle(color: AppTheme.textPrimary)),
                      content: const Text(
                        'Restore this version? Current content will be replaced.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Restore'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed != true) {
                    return;
                  }

                  setState(() {
                    _isRestoring = true;
                  });

                  try {
                    final result = await syncService.restoreNoteHistory(widget.noteId, _selected!);
                    if (!mounted) return;
                    setState(() {
                      _isRestoring = false;
                    });

                    final message = result.applied ? 'Note restored' : 'No changes to apply';
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

                    if (result.applied) {
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    if (!mounted) return;
                    setState(() {
                      _isRestoring = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Restore failed: $e')),
                    );
                  }
                },
          child: _isRestoring
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Restore'),
        ),
      ],
    );
  }

  Widget _buildPreview(NoteHistoryEntry entry) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
        color: AppTheme.surfaceDark,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.title.isEmpty ? 'Untitled' : entry.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTimestamp(entry.changedAt),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                entry.content,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) {
      return 'Just now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    }
    return '${time.day}/${time.month}/${time.year}';
  }
}
