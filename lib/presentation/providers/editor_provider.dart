import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/markdown_converter.dart';
// import '../../data/database/database.dart'; // TODO: Use when implementing database operations
import 'database_provider.dart';

// Editor state for a specific note
class EditorState {
  final QuillController controller;
  final bool isLoading;
  final bool isSaving;
  final bool hasUnsavedChanges;
  final String? error;
  final String? lastSavedContent;

  EditorState({
    required this.controller,
    this.isLoading = false,
    this.isSaving = false,
    this.hasUnsavedChanges = false,
    this.error,
    this.lastSavedContent,
  });

  EditorState copyWith({
    QuillController? controller,
    bool? isLoading,
    bool? isSaving,
    bool? hasUnsavedChanges,
    String? error,
    String? lastSavedContent,
  }) {
    return EditorState(
      controller: controller ?? this.controller,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      error: error ?? this.error,
      lastSavedContent: lastSavedContent ?? this.lastSavedContent,
    );
  }
}

// Editor provider for a specific note
class EditorNotifier extends StateNotifier<EditorState> {
  final Ref ref;
  final int? noteId;

  StreamSubscription? _debounceSubscription;
  final _contentSubject = BehaviorSubject<String>();

  EditorNotifier(this.ref, this.noteId)
      : super(EditorState(
          controller: QuillController.basic(),
        )) {
    _initializeEditor();
    _setupAutosave();
  }

  @override
  void dispose() {
    _debounceSubscription?.cancel();
    _contentSubject.close();
    state.controller.dispose();
    super.dispose();
  }

  Future<void> _initializeEditor() async {
    if (noteId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final repository = ref.read(notesRepositoryProvider);
      final note = await repository.getNoteById(noteId!);

      if (note != null) {
        // Parse the content - handle both formats
        final contentJson = jsonDecode(note.content);
        final List<dynamic> deltaOps;

        if (contentJson is Map<String, dynamic> && contentJson.containsKey('ops')) {
          // Content is in format: {"ops": [...]}
          deltaOps = contentJson['ops'] as List<dynamic>;
        } else if (contentJson is List<dynamic>) {
          // Content is already in format: [...]
          deltaOps = contentJson;
        } else {
          // Fallback - create a simple text delta
          deltaOps = [
            {'insert': note.plainText + '\n'}
          ];
        }

        final delta = Delta.fromJson(deltaOps);
        final controller = QuillController(
          document: Document.fromDelta(delta),
          selection: const TextSelection.collapsed(offset: 0),
        );

        // Listen to content changes
        controller.addListener(_onContentChanged);

        state = state.copyWith(
          controller: controller,
          isLoading: false,
          lastSavedContent: note.content,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void _setupAutosave() {
    _debounceSubscription = _contentSubject.debounceTime(AppConstants.autosaveDebounce).listen(_saveContent);
  }

  void _onContentChanged() {
    if (!state.isLoading && !state.isSaving) {
      final content = jsonEncode(state.controller.document.toDelta().toJson());
      final hasChanges = content != state.lastSavedContent;

      if (hasChanges) {
        state = state.copyWith(hasUnsavedChanges: true);
        _contentSubject.add(content);
      }
    }
  }

  Future<void> _saveContent(String content) async {
    if (noteId == null) return;

    state = state.copyWith(isSaving: true);

    try {
      final repository = ref.read(notesRepositoryProvider);
      await repository.updateNote(
        id: noteId!,
        content: content,
      );

      state = state.copyWith(
        isSaving: false,
        hasUnsavedChanges: false,
        lastSavedContent: content,
      );
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: e.toString(),
      );
    }
  }

  Future<void> updateTitle(String title) async {
    if (noteId == null) return;

    try {
      final repository = ref.read(notesRepositoryProvider);
      await repository.updateNote(
        id: noteId!,
        title: title,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> forceSync() async {
    if (state.hasUnsavedChanges) {
      final content = jsonEncode(state.controller.document.toDelta().toJson());
      await _saveContent(content);
    }
  }

  // Formatting methods
  void toggleBold() {
    // final selection = state.controller.selection; // TODO: Use when implementing selection-based formatting
    state.controller.formatSelection(Attribute.bold);
  }

  void toggleItalic() {
    // final selection = state.controller.selection; // TODO: Use when implementing selection-based formatting
    state.controller.formatSelection(Attribute.italic);
  }

  void toggleUnderline() {
    // final selection = state.controller.selection; // TODO: Use when implementing selection-based formatting
    state.controller.formatSelection(Attribute.underline);
  }

  void toggleStrikethrough() {
    // final selection = state.controller.selection; // TODO: Use when implementing selection-based formatting
    state.controller.formatSelection(Attribute.strikeThrough);
  }

  void toggleCodeBlock() {
    // final selection = state.controller.selection; // TODO: Use when implementing selection-based formatting
    state.controller.formatSelection(Attribute.codeBlock);
  }

  void toggleInlineCode() {
    // final selection = state.controller.selection; // TODO: Use when implementing selection-based formatting
    state.controller.formatSelection(Attribute.inlineCode);
  }

  void insertCheckList() {
    // final selection = state.controller.selection; // TODO: Use when implementing selection-based formatting
    state.controller.formatSelection(Attribute.unchecked);
  }

  /// Handles paste events with Markdown auto-parsing
  Future<void> handlePaste() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        final pastedText = clipboardData!.text!;

        // Check if the pasted content is Markdown
        if (MarkdownConverter.isMarkdown(pastedText)) {
          // Convert Markdown to Delta and insert
          final delta = MarkdownConverter.markdownToDelta(pastedText);
          final selection = state.controller.selection;

          // Replace the current selection with the converted content
          state.controller.replaceText(
            selection.start,
            selection.end - selection.start,
            delta,
            TextSelection.collapsed(offset: selection.start + delta.length),
          );
        } else {
          // Insert as plain text
          final selection = state.controller.selection;
          state.controller.replaceText(
            selection.start,
            selection.end - selection.start,
            pastedText,
            TextSelection.collapsed(offset: selection.start + pastedText.length),
          );
        }
      }
    } catch (e) {
      // If paste fails, fall back to default behavior
      print('Paste failed: $e');
    }
  }
}

// Provider for editor instances
final editorProvider = StateNotifierProvider.family<EditorNotifier, EditorState, int?>((ref, noteId) {
  return EditorNotifier(ref, noteId);
});

// Current note ID provider
final currentNoteIdProvider = StateProvider<int?>((ref) => null);

// Current editor provider
final currentEditorProvider = Provider<EditorState?>((ref) {
  final noteId = ref.watch(currentNoteIdProvider);
  if (noteId == null) return null;
  return ref.watch(editorProvider(noteId));
});
