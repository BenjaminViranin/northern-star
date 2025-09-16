import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/editor_provider.dart' as editor_provider;
import '../providers/session_provider.dart';
import '../../core/theme/app_theme.dart';

class RichTextEditor extends ConsumerStatefulWidget {
  final int? noteId;
  final bool readOnly;

  const RichTextEditor({
    super.key,
    this.noteId,
    this.readOnly = false,
  });

  @override
  ConsumerState<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends ConsumerState<RichTextEditor> with WidgetsBindingObserver {
  QuillController? _lastController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // Add app lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Setup focus listener
    _focusNode.addListener(_onFocusChanged);

    // Setup session state management
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSessionManagement();
      // Auto-focus if not read-only
      if (!widget.readOnly) {
        _focusNode.requestFocus();
      }
      // Initial refresh when editor is created
      _refreshEditorContent();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lastController?.removeListener(_onSelectionChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Refresh editor content when app becomes active
    if (state == AppLifecycleState.resumed) {
      _refreshEditorContent();
    }
  }

  void _onFocusChanged() {
    if (widget.noteId != null) {
      // Notify the editor provider about focus changes
      ref.read(editor_provider.editorProvider(widget.noteId).notifier).onEditorFocusChanged(_focusNode.hasFocus);

      // If editor gained focus, refresh content
      if (_focusNode.hasFocus) {
        _refreshEditorContent();
      }
    }
  }

  void _refreshEditorContent() {
    if (widget.noteId != null) {
      // Trigger a refresh from the database
      ref.read(editor_provider.editorProvider(widget.noteId).notifier).refreshFromDatabase();
    }
  }

  void _setupSessionManagement() {
    if (widget.noteId == null) return;

    // Save note change to session
    ref.read(sessionProvider.notifier).saveLastOpenedNotes(
          mainEditorNoteId: widget.noteId,
        );
  }

  void _onSelectionChanged() {
    // Force rebuild when selection changes to update toolbar states
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(RichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If note ID changed, refresh the content
    if (oldWidget.noteId != widget.noteId) {
      // Remove focus listener from old focus node if needed
      if (oldWidget.noteId != null) {
        ref.read(editor_provider.editorProvider(oldWidget.noteId).notifier).onEditorFocusChanged(false);
      }

      // Setup for new note
      if (widget.noteId != null) {
        _refreshEditorContent();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    if (widget.noteId == null) {
      return Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.note_add,
                size: 64,
                color: AppTheme.textSecondary,
              ),
              SizedBox(height: 16),
              Text(
                'Create a new note to start writing',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final editorState = ref.watch(editor_provider.editorProvider(widget.noteId));

    if (editorState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (editorState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error: ${editorState.error}',
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      );
    }

    // Set up selection listener for toolbar updates
    final controller = editorState.controller;
    if (_lastController != controller) {
      _lastController?.removeListener(_onSelectionChanged);
      _lastController = controller;
      controller.addListener(_onSelectionChanged);
    }

    return Column(
      children: [
        if (!widget.readOnly) _buildToolbar(context, ref),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: GestureDetector(
              onTapDown: (details) {
                if (!widget.readOnly) {
                  _focusNode.requestFocus();
                  // Move cursor to end if document is empty or very short
                  final doc = editorState.controller.document;
                  if (doc.length <= 1) {
                    editorState.controller.moveCursorToEnd();
                  }
                }
              },
              child: QuillProvider(
                configurations: QuillConfigurations(
                  controller: editorState.controller,
                ),
                child: QuillEditor.basic(
                  focusNode: _focusNode,
                  configurations: QuillEditorConfigurations(
                    scrollable: true,
                    padding: const EdgeInsets.all(16),
                    autoFocus: !widget.readOnly,
                    placeholder: 'Start writing...',
                    readOnly: widget.readOnly,
                    showCursor: true,
                    enableInteractiveSelection: true,
                    expands: false,
                    keyboardAppearance: Brightness.light,
                    onTapUp: (details, p1) {
                      // Always ensure focus when tapping
                      if (!widget.readOnly) {
                        _focusNode.requestFocus();
                      }
                      return false;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editor_provider.editorProvider(widget.noteId));
    final controller = editorState.controller;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceVariant,
        border: Border(
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(
        children: [
          _buildToolbarButton(
            icon: Icons.format_bold,
            isActive: _isFormatActive(controller, Attribute.bold),
            onPressed: () => ref.read(editor_provider.editorProvider(widget.noteId).notifier).toggleBold(),
          ),
          _buildToolbarButton(
            icon: Icons.format_italic,
            isActive: _isFormatActive(controller, Attribute.italic),
            onPressed: () => ref.read(editor_provider.editorProvider(widget.noteId).notifier).toggleItalic(),
          ),
          _buildToolbarButton(
            icon: Icons.format_underlined,
            isActive: _isFormatActive(controller, Attribute.underline),
            onPressed: () => ref.read(editor_provider.editorProvider(widget.noteId).notifier).toggleUnderline(),
          ),
          _buildToolbarButton(
            icon: Icons.format_strikethrough,
            isActive: _isFormatActive(controller, Attribute.strikeThrough),
            onPressed: () => ref.read(editor_provider.editorProvider(widget.noteId).notifier).toggleStrikethrough(),
          ),
          const VerticalDivider(color: AppTheme.border),
          _buildToolbarButton(
            icon: Icons.code,
            isActive: _isFormatActive(controller, Attribute.inlineCode),
            onPressed: () => ref.read(editor_provider.editorProvider(widget.noteId).notifier).toggleInlineCode(),
          ),
          _buildToolbarButton(
            icon: Icons.checklist,
            isActive: false, // Checklist doesn't have an active state
            onPressed: () => ref.read(editor_provider.editorProvider(widget.noteId).notifier).insertCheckList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      color: isActive ? AppTheme.primaryTeal : AppTheme.textPrimary,
      style: IconButton.styleFrom(
        backgroundColor: isActive ? AppTheme.primaryTeal.withOpacity(0.1) : null,
      ),
      splashRadius: 20,
    );
  }

  bool _isFormatActive(QuillController controller, Attribute attribute) {
    try {
      final selection = controller.selection;
      if (selection.isCollapsed) {
        // For collapsed selection, check the style at the cursor position
        final style = controller.getSelectionStyle();
        return style.attributes.containsKey(attribute.key);
      } else {
        // For text selection, check if the attribute is applied to the selection
        final style = controller.getSelectionStyle();
        return style.attributes.containsKey(attribute.key);
      }
    } catch (e) {
      // If there's any error checking the format, assume it's not active
      return false;
    }
  }
}
