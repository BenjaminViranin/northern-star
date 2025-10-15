import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/markdown_converter.dart';
import '../../data/database/database.dart';
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
  StreamSubscription? _noteUpdateSubscription;
  final _contentSubject = BehaviorSubject<String>();
  bool _isUpdatingFromDatabase = false;
  bool _hasEditorFocus = false;
  DateTime? _lastRefreshTime;
  String? _lastKnownContent;

  EditorNotifier(this.ref, this.noteId)
      : super(EditorState(
          controller: _createBasicController(),
        )) {
    // Add listener to basic controller
    state.controller.addListener(_onContentChanged);
    _initializeEditor();
    _setupAutosave();
    _setupDatabaseListener();
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
    _noteUpdateSubscription?.cancel();
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

        // Initialize known content tracking to avoid immediate forced refresh resetting selection
        _lastKnownContent = note.content;
        _lastRefreshTime = DateTime.now();
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

  void _setupDatabaseListener() {
    if (noteId == null) return;

    // Listen to database changes for this specific note
    // Use a longer interval when editor has focus to avoid interrupting typing
    _noteUpdateSubscription = Stream.periodic(const Duration(seconds: 2)).asyncMap((_) async {
      try {
        final repository = ref.read(notesRepositoryProvider);
        return await repository.getNoteById(noteId!);
      } catch (e) {
        return null;
      }
    }).distinct((previous, next) {
      // Only emit when content actually changes
      if (previous?.content != next?.content) {
        return false; // Different content, emit
      }
      return true; // Same content, don't emit
    }).listen((note) {
      if (note != null && !_isUpdatingFromDatabase && !state.isSaving) {
        // Only update if editor doesn't have focus or if content is significantly different
        final shouldUpdate = !_hasEditorFocus || _shouldForceUpdate(note.content);
        if (shouldUpdate) {
          _updateEditorFromDatabase(note);
        }
      }
    });
  }

  bool _shouldForceUpdate(String newContent) {
    // Force update if content is very different or if it's been a while since last refresh
    if (_lastKnownContent == null) return true;

    final now = DateTime.now();
    final timeSinceLastRefresh = _lastRefreshTime != null ? now.difference(_lastRefreshTime!) : const Duration(hours: 1);

    // Force update if it's been more than 30 seconds since last refresh
    if (timeSinceLastRefresh.inSeconds > 30) return true;

    // Force update if content length difference is significant (more than 50 characters)
    final lengthDiff = (newContent.length - _lastKnownContent!.length).abs();
    return lengthDiff > 50;
  }

  void _updateEditorFromDatabase(Note note) {
    _isUpdatingFromDatabase = true;

    try {
      // Parse the content from the database
      List<dynamic> deltaOps;
      if (note.content.isNotEmpty) {
        try {
          final deltaJson = jsonDecode(note.content);
          if (deltaJson is Map<String, dynamic> && deltaJson.containsKey('ops')) {
            deltaOps = deltaJson['ops'] as List<dynamic>;
          } else if (deltaJson is List<dynamic>) {
            deltaOps = deltaJson;
          } else {
            deltaOps = [
              {'insert': '${note.plainText}\n'}
            ];
          }
        } catch (e) {
          // Fallback - create a simple text delta
          deltaOps = [
            {'insert': '${note.plainText}\n'}
          ];
        }
      } else {
        deltaOps = [
          {'insert': '\n'}
        ];
      }

      // Create new delta and update the controller, preserving current selection
      final delta = Delta.fromJson(deltaOps);
      final oldSelection = state.controller.selection;

      state.controller.document = Document.fromDelta(delta);

      // Restore selection (caret) and clamp to new document length
      final newDocLength = state.controller.document.length;
      int desiredBase = oldSelection.baseOffset;
      int desiredExtent = oldSelection.extentOffset;
      if (desiredBase < 0) desiredBase = 0;
      if (desiredExtent < 0) desiredExtent = 0;
      if (desiredBase >= newDocLength) desiredBase = newDocLength - 1;
      if (desiredExtent >= newDocLength) desiredExtent = newDocLength - 1;
      state.controller.updateSelection(
        TextSelection(baseOffset: desiredBase, extentOffset: desiredExtent),
        ChangeSource.local,
      );

      // Update tracking variables
      _lastKnownContent = note.content;
      _lastRefreshTime = DateTime.now();

      // Update the saved content state
      state = state.copyWith(
        lastSavedContent: note.content,
        hasUnsavedChanges: false,
      );

      print('🔄 Updated editor from database for note ${note.id}');
    } catch (e) {
      print('❌ Error updating editor from database: $e');
    } finally {
      _isUpdatingFromDatabase = false;
    }
  }

  void _onContentChanged() {
    if (!state.isLoading && !state.isSaving && !_isUpdatingFromDatabase) {
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

  // Focus management methods
  void onEditorFocusChanged(bool hasFocus) {
    _hasEditorFocus = hasFocus;

    // If editor lost focus, check for updates immediately
    if (!hasFocus) {
      _checkForUpdatesImmediately();
    }
  }

  // Manual refresh method for lifecycle events
  Future<void> refreshFromDatabase() async {
    if (noteId == null) return;

    try {
      final repository = ref.read(notesRepositoryProvider);
      final note = await repository.getNoteById(noteId!);

      if (note != null) {
        // Force update regardless of focus state
        final currentContent = jsonEncode(state.controller.document.toDelta().toJson());
        if (note.content != currentContent && note.content != state.lastSavedContent) {
          _updateEditorFromDatabase(note);
        }
      }
    } catch (e) {
      print('❌ Error refreshing from database: $e');
    }
  }

  void _checkForUpdatesImmediately() {
    if (noteId == null) return;

    // Cancel current subscription and create a new one that checks immediately
    _noteUpdateSubscription?.cancel();

    // Check once immediately, then resume normal polling
    Future.delayed(const Duration(milliseconds: 100), () async {
      try {
        final repository = ref.read(notesRepositoryProvider);
        final note = await repository.getNoteById(noteId!);

        if (note != null && !_isUpdatingFromDatabase && !state.isSaving) {
          _updateEditorFromDatabase(note);
        }
      } catch (e) {
        print('❌ Error in immediate check: $e');
      }

      // Resume normal database listener
      _setupDatabaseListener();
    });
  }

  // Formatting methods
  void toggleBold() {
    final selection = state.controller.selection;
    state.controller.formatSelection(Attribute.bold);
    // Restore selection so it remains highlighted after applying format
    state.controller.updateSelection(selection, ChangeSource.local);
  }

  void toggleItalic() {
    final selection = state.controller.selection;
    state.controller.formatSelection(Attribute.italic);
    state.controller.updateSelection(selection, ChangeSource.local);
  }

  void toggleUnderline() {
    final selection = state.controller.selection;
    state.controller.formatSelection(Attribute.underline);
    state.controller.updateSelection(selection, ChangeSource.local);
  }

  void toggleStrikethrough() {
    final selection = state.controller.selection;
    state.controller.formatSelection(Attribute.strikeThrough);
    state.controller.updateSelection(selection, ChangeSource.local);
  }

  void toggleCodeBlock() {
    final selection = state.controller.selection;
    state.controller.formatSelection(Attribute.codeBlock);
    state.controller.updateSelection(selection, ChangeSource.local);
  }

  void toggleInlineCode() {
    final selection = state.controller.selection;
    state.controller.formatSelection(Attribute.inlineCode);
    state.controller.updateSelection(selection, ChangeSource.local);
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
