import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/markdown_converter.dart';
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
          controller: _createBasicController(),
        )) {
    // Add listener to basic controller
    state.controller.addListener(_onContentChanged);
    _initializeEditor();
    _setupAutosave();
  }

  /// Creates a basic controller with proper document initialization
  static QuillController _createBasicController() {
    final document = Document();
    document.insert(0, '\n'); // Ensure document has content for cursor
    return QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _debounceSubscription?.cancel();
    _contentSubject.close();
    state.controller.removeListener(_onContentChanged);
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
        final document = Document.fromDelta(delta);

        // Ensure document has at least one character for proper cursor positioning
        if (document.length <= 1) {
          document.insert(0, '\n');
        }

        final controller = QuillController(
          document: document,
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

      print('📝 Content changed - Note ID: $noteId, Has changes: $hasChanges');
      print('📝 New content length: ${content.length}');

      if (hasChanges) {
        state = state.copyWith(hasUnsavedChanges: true);
        _contentSubject.add(content);
        print('📝 Added to autosave queue');
      }
    }
  }

  Future<void> _saveContent(String content) async {
    if (noteId == null) return;

    print('💾 Saving content for note $noteId...');
    state = state.copyWith(isSaving: true);

    try {
      final repository = ref.read(notesRepositoryProvider);
      await repository.updateNote(
        id: noteId!,
        content: content,
      );

      print('✅ Content saved successfully for note $noteId');
      state = state.copyWith(
        isSaving: false,
        hasUnsavedChanges: false,
        lastSavedContent: content,
      );
    } catch (e) {
      print('❌ Failed to save content for note $noteId: $e');
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
    final selection = state.controller.selection;
    if (selection.isCollapsed) {
      // If no text is selected, toggle formatting for next typed text
      state.controller.formatSelection(Attribute.bold);
    } else {
      // Format the selected text
      state.controller.formatSelection(Attribute.bold);
    }
  }

  void toggleItalic() {
    final selection = state.controller.selection;
    if (selection.isCollapsed) {
      state.controller.formatSelection(Attribute.italic);
    } else {
      state.controller.formatSelection(Attribute.italic);
    }
  }

  void toggleUnderline() {
    final selection = state.controller.selection;
    if (selection.isCollapsed) {
      state.controller.formatSelection(Attribute.underline);
    } else {
      state.controller.formatSelection(Attribute.underline);
    }
  }

  void toggleStrikethrough() {
    final selection = state.controller.selection;
    if (selection.isCollapsed) {
      state.controller.formatSelection(Attribute.strikeThrough);
    } else {
      state.controller.formatSelection(Attribute.strikeThrough);
    }
  }

  void toggleCodeBlock() {
    final selection = state.controller.selection;
    if (selection.isCollapsed) {
      state.controller.formatSelection(Attribute.codeBlock);
    } else {
      state.controller.formatSelection(Attribute.codeBlock);
    }
  }

  void toggleInlineCode() {
    final selection = state.controller.selection;
    if (selection.isCollapsed) {
      state.controller.formatSelection(Attribute.inlineCode);
    } else {
      state.controller.formatSelection(Attribute.inlineCode);
    }
  }

  void insertCheckList() {
    // Insert checklist at current position
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
      // In production, this would be logged to a proper logging service
      if (AppConstants.enableDebugLogging) {
        debugPrint('Paste failed: $e');
      }
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
