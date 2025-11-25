import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/editor_provider.dart' as editor_provider;
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

class _RichTextEditorState extends ConsumerState<RichTextEditor> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(RichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-focus when a note is opened
    if (widget.noteId != null && oldWidget.noteId != widget.noteId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.readOnly) {
          _focusNode.requestFocus();
          // Move cursor to end of text
          final controller = ref.read(editor_provider.editorProvider(widget.noteId)).controller;
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (widget.noteId != null) {
      ref.read(editor_provider.editorProvider(widget.noteId).notifier).onEditorFocusChanged(_focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.noteId == null) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.zero,
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
        child: Text(
          'Error: ${editorState.error}',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    final controller = editorState.controller;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.zero,
      ),
      child: TextField(
        controller: controller,
        focusNode: _focusNode,
        readOnly: widget.readOnly,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
          height: 1.5,
          fontFamily: 'Courier New',
          fontFamilyFallback: ['Courier', 'monospace'],
        ),
        decoration: const InputDecoration(
          hintText: 'Start writing...',
          hintStyle: TextStyle(
            color: AppTheme.textSecondary,
            fontFamily: 'Courier New',
            fontFamilyFallback: ['Courier', 'monospace'],
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
          filled: false,
          hoverColor: Colors.transparent,
        ),
      ),
    );
  }
}
