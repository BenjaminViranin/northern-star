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

// Internal action descriptor for checklist strike enforcement
class _StrikeAction {
  final int start;
  final int length;
  final bool apply;
  const _StrikeAction({required this.start, required this.length, required this.apply});
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
  bool _isApplyingChecklistFormatting = false; // guard to avoid recursive listeners

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

  // Apply or remove strike-through automatically based on checklist state
  void _enforceChecklistStrikethrough() {
    if (_isApplyingChecklistFormatting) return;

    final controller = state.controller;
    final doc = controller.document;

    // Fast path: skip if document is empty
    if (doc.length <= 1) return;

    final delta = doc.toDelta();
    final actions = <_StrikeAction>[];

    int globalOffset = 0; // offset within document
    int lineStart = 0;

    for (final op in delta.toList()) {
      final data = op.data;
      final attributes = op.attributes ?? const <String, dynamic>{};
      int opLength = 0;

      if (data is String) {
        opLength = data.length;
        int localIndex = 0;
        while (localIndex < data.length) {
          final nextNl = data.indexOf('\n', localIndex);
          if (nextNl == -1) {
            // No newline in the remaining segment
            globalOffset += data.length - localIndex;
            break;
          }

          final lineEndExclusive = globalOffset + (nextNl - localIndex);
          final listValue = attributes['list']; // 'checked' | 'unchecked' | null

          if (lineEndExclusive > lineStart) {
            if (listValue == 'checked') {
              actions.add(_StrikeAction(start: lineStart, length: lineEndExclusive - lineStart, apply: true));
            } else if (listValue == 'unchecked') {
              actions.add(_StrikeAction(start: lineStart, length: lineEndExclusive - lineStart, apply: false));
            }
          }

          // Advance past the newline
          globalOffset += (nextNl - localIndex) + 1;
          localIndex = nextNl + 1;
          lineStart = globalOffset;
        }
      } else {
        // Treat embeds as length 1 for offset accounting
        opLength = 1;
        globalOffset += opLength;
      }
    }

    if (actions.isEmpty) return;

    _isApplyingChecklistFormatting = true;
    final previousSelection = controller.selection;
    final bool hadCollapsed = previousSelection.isCollapsed;
    final List<Attribute> pendingToggled =
        hadCollapsed ? controller.toggledStyle.attributes.values.whereType<Attribute>().toList() : const <Attribute>[];
    try {
      for (final a in actions) {
        if (a.length <= 0) continue;
        // Select the line content (excluding trailing newline) and inspect style
        controller.updateSelection(
          TextSelection(baseOffset: a.start, extentOffset: a.start + a.length),
          ChangeSource.local,
        );
        final style = controller.getSelectionStyle();
        final hasStrike = style.attributes.containsKey(Attribute.strikeThrough.key);
        if (a.apply && !hasStrike) {
          controller.formatSelection(Attribute.strikeThrough);
        } else if (!a.apply && hasStrike) {
          controller.formatSelection(Attribute.clone(Attribute.strikeThrough, null));
        }
      }
    } finally {
      // Restore original selection
      controller.updateSelection(previousSelection, ChangeSource.local);
      // Re-apply pending toggled styles for collapsed caret so toolbar state and
      // subsequent typing are preserved after our programmatic formatting.
      if (hadCollapsed && pendingToggled.isNotEmpty) {
        for (final attr in pendingToggled) {
          controller.formatSelection(attr);
        }
      }
      _isApplyingChecklistFormatting = false;
    }
  }

  void _onContentChanged() {
    // Avoid re-entrancy while we adjust formatting programmatically
    if (_isApplyingChecklistFormatting) return;

    if (!state.isLoading && !state.isSaving && !_isUpdatingFromDatabase) {
      // Enforce checklist strike-through before computing content changes
      _enforceChecklistStrikethrough();

      final content = jsonEncode(state.controller.document.toDelta().toJson());
      final hasChanges = content != state.lastSavedContent;

      if (AppConstants.enableDebugLogging) {
        debugPrint('📝 Content changed - Note ID: $noteId, Has changes: $hasChanges');
        debugPrint('📝 New content length: ${content.length}');
      }

      if (hasChanges) {
        state = state.copyWith(hasUnsavedChanges: true);
        _contentSubject.add(content);
        if (AppConstants.enableDebugLogging) debugPrint('📝 Added to autosave queue');
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

  // Formatting methods (toggle on/off for both collapsed and range selections)
  void _toggleAttribute(Attribute attribute) {
    final controller = state.controller;
    final selection = controller.selection;

    bool isActive;
    try {
      if (selection.isCollapsed) {
        final toggled = controller.toggledStyle;
        isActive = toggled.attributes.containsKey(attribute.key) || controller.getSelectionStyle().attributes.containsKey(attribute.key);
      } else {
        isActive = controller.getSelectionStyle().attributes.containsKey(attribute.key);
      }
    } catch (_) {
      isActive = false;
    }

    if (isActive) {
      controller.formatSelection(Attribute.clone(attribute, null));
    } else {
      controller.formatSelection(attribute);
    }

    // Keep selection as-is so user sees the result and keeps typing
    controller.updateSelection(selection, ChangeSource.local);
  }

  void toggleBold() => _toggleAttribute(Attribute.bold);
  void toggleItalic() => _toggleAttribute(Attribute.italic);
  void toggleUnderline() => _toggleAttribute(Attribute.underline);
  void toggleStrikethrough() => _toggleAttribute(Attribute.strikeThrough);
  void toggleCodeBlock() => _toggleAttribute(Attribute.codeBlock);
  void toggleInlineCode() => _toggleAttribute(Attribute.inlineCode);

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
