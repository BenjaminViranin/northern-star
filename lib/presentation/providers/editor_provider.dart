import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/constants/app_constants.dart';
import '../../data/database/database.dart';
import 'database_provider.dart';

// Editor state for a specific note
class EditorState {
  final TextEditingController controller;
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
    TextEditingController? controller,
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
  String? _lastKnownContent;
  bool _isSaving = false; // Lock to prevent concurrent saves

  EditorNotifier(this.ref, this.noteId)
      : super(EditorState(
          controller: TextEditingController(),
        )) {
    state.controller.addListener(_onContentChanged);
    _initializeEditor();
    _setupAutosave();
    _setupDatabaseListener();
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
        final controller = TextEditingController(text: note.content);
        controller.addListener(_onContentChanged);

        state = state.copyWith(
          controller: controller,
          isLoading: false,
          lastSavedContent: note.content,
        );

        _lastKnownContent = note.content;
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

    final database = ref.read(databaseProvider);
    _noteUpdateSubscription = database.watchNoteById(noteId!).listen((note) {
      if (note == null || _isUpdatingFromDatabase) return;

      if (!_hasEditorFocus && note.content != _lastKnownContent) {
        _updateEditorFromDatabase(note);
      }
    });
  }

  void _updateEditorFromDatabase(Note note) {
    _isUpdatingFromDatabase = true;

    final currentSelection = state.controller.selection;
    state.controller.text = note.content;

    if (currentSelection.isValid && currentSelection.end <= note.content.length) {
      state.controller.selection = currentSelection;
    }

    _lastKnownContent = note.content;
    state = state.copyWith(lastSavedContent: note.content);

    _isUpdatingFromDatabase = false;
  }

  void _onContentChanged() {
    if (_isUpdatingFromDatabase) return;

    final content = state.controller.text;
    final hasChanges = content != state.lastSavedContent;

    state = state.copyWith(hasUnsavedChanges: hasChanges);

    if (hasChanges) {
      _contentSubject.add(content);
    }
  }

  Future<void> _saveContent(String content) async {
    if (noteId == null || _isUpdatingFromDatabase || _isSaving) return;

    // Acquire lock to prevent concurrent saves
    _isSaving = true;
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

      _lastKnownContent = content;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: e.toString(),
      );
    } finally {
      // Release lock
      _isSaving = false;
    }
  }

  void onEditorFocusChanged(bool hasFocus) {
    _hasEditorFocus = hasFocus;
  }

  Future<void> refreshFromDatabase() async {
    if (noteId == null) return;

    try {
      final repository = ref.read(notesRepositoryProvider);
      final note = await repository.getNoteById(noteId!);

      if (note != null && note.content != _lastKnownContent) {
        _updateEditorFromDatabase(note);
      }
    } catch (e) {
      // Silently fail refresh
    }
  }
}

final editorProvider = StateNotifierProvider.family<EditorNotifier, EditorState, int?>(
  (ref, noteId) => EditorNotifier(ref, noteId),
);
