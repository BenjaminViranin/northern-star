import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/session_persistence_service.dart';
import 'database_provider.dart';

/// Provider for managing session state
final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier(ref);
});

/// Session state class
class SessionState {
  final bool isInitialized;
  final WindowState? windowState;
  final LastOpenedNotesState? lastOpenedNotes;
  final UIState? uiState;
  final SplitViewState? splitViewState;
  final bool isRestoring;

  const SessionState({
    this.isInitialized = false,
    this.windowState,
    this.lastOpenedNotes,
    this.uiState,
    this.splitViewState,
    this.isRestoring = false,
  });

  SessionState copyWith({
    bool? isInitialized,
    WindowState? windowState,
    LastOpenedNotesState? lastOpenedNotes,
    UIState? uiState,
    SplitViewState? splitViewState,
    bool? isRestoring,
  }) {
    return SessionState(
      isInitialized: isInitialized ?? this.isInitialized,
      windowState: windowState ?? this.windowState,
      lastOpenedNotes: lastOpenedNotes ?? this.lastOpenedNotes,
      uiState: uiState ?? this.uiState,
      splitViewState: splitViewState ?? this.splitViewState,
      isRestoring: isRestoring ?? this.isRestoring,
    );
  }
}

/// Session state notifier
class SessionNotifier extends StateNotifier<SessionState> {
  final Ref ref;

  SessionNotifier(this.ref) : super(const SessionState());

  /// Initialize session and restore previous state
  Future<void> initializeSession() async {
    if (state.isInitialized) return;

    state = state.copyWith(isRestoring: true);

    try {
      await SessionPersistenceService.initialize();

      // Restore all session states
      final windowState = SessionPersistenceService.restoreWindowState();
      final lastOpenedNotes = SessionPersistenceService.restoreLastOpenedNotes();
      final uiState = SessionPersistenceService.restoreUIState();
      final splitViewState = SessionPersistenceService.restoreSplitViewState();

      // Validate restored notes exist
      final validatedNotesState = await _validateNotesState(lastOpenedNotes);
      final validatedSplitViewState = await _validateSplitViewState(splitViewState);

      state = state.copyWith(
        isInitialized: true,
        isRestoring: false,
        windowState: windowState,
        lastOpenedNotes: validatedNotesState,
        uiState: uiState,
        splitViewState: validatedSplitViewState,
      );
    } catch (e) {
      // If restoration fails, start with clean state
      state = state.copyWith(
        isInitialized: true,
        isRestoring: false,
      );
    }
  }

  /// Validate that restored notes still exist
  Future<LastOpenedNotesState?> _validateNotesState(LastOpenedNotesState? notesState) async {
    if (notesState == null) return null;

    try {
      final notesRepository = ref.read(notesRepositoryProvider);

      // Validate main editor note
      int? validMainNoteId;
      if (notesState.mainEditorNoteId != null) {
        final note = await notesRepository.getNoteById(notesState.mainEditorNoteId!);
        if (note != null && !note.isDeleted) {
          validMainNoteId = notesState.mainEditorNoteId;
        }
      }

      // Validate split view notes
      Map<int, int>? validSplitViewNotes;
      if (notesState.splitViewNotes != null) {
        validSplitViewNotes = <int, int>{};
        for (final entry in notesState.splitViewNotes!.entries) {
          final note = await notesRepository.getNoteById(entry.value);
          if (note != null && !note.isDeleted) {
            validSplitViewNotes[entry.key] = entry.value;
          }
        }
        if (validSplitViewNotes.isEmpty) {
          validSplitViewNotes = null;
        }
      }

      return LastOpenedNotesState(
        mainEditorNoteId: validMainNoteId,
        cursorPosition: validMainNoteId != null ? notesState.cursorPosition : null,
        splitViewNotes: validSplitViewNotes,
        splitViewCursorPositions: validSplitViewNotes != null 
            ? notesState.splitViewCursorPositions 
            : null,
      );
    } catch (e) {
      return null;
    }
  }

  /// Validate split view state
  Future<SplitViewState?> _validateSplitViewState(SplitViewState? splitViewState) async {
    if (splitViewState == null || !splitViewState.isActive) return splitViewState;

    try {
      final notesRepository = ref.read(notesRepositoryProvider);
      final validNoteIds = <int?>[];

      for (final noteId in splitViewState.noteIds) {
        if (noteId != null) {
          final note = await notesRepository.getNoteById(noteId);
          if (note != null && !note.isDeleted) {
            validNoteIds.add(noteId);
          } else {
            validNoteIds.add(null);
          }
        } else {
          validNoteIds.add(null);
        }
      }

      return SplitViewState(
        isActive: splitViewState.isActive,
        paneCount: splitViewState.paneCount,
        noteIds: validNoteIds,
      );
    } catch (e) {
      return null;
    }
  }

  /// Save window state
  Future<void> saveWindowState({
    required Size size,
    required Offset position,
    required bool isMaximized,
  }) async {
    await SessionPersistenceService.saveWindowState(
      size: size,
      position: position,
      isMaximized: isMaximized,
    );

    state = state.copyWith(
      windowState: WindowState(
        size: size,
        position: position,
        isMaximized: isMaximized,
      ),
    );
  }

  /// Save last opened notes
  Future<void> saveLastOpenedNotes({
    int? mainEditorNoteId,
    int? cursorPosition,
    Map<int, int>? splitViewNotes,
    Map<int, int>? splitViewCursorPositions,
  }) async {
    await SessionPersistenceService.saveLastOpenedNotes(
      mainEditorNoteId: mainEditorNoteId,
      cursorPosition: cursorPosition,
      splitViewNotes: splitViewNotes,
      splitViewCursorPositions: splitViewCursorPositions,
    );

    state = state.copyWith(
      lastOpenedNotes: LastOpenedNotesState(
        mainEditorNoteId: mainEditorNoteId,
        cursorPosition: cursorPosition,
        splitViewNotes: splitViewNotes,
        splitViewCursorPositions: splitViewCursorPositions,
      ),
    );
  }

  /// Save UI state
  Future<void> saveUIState({
    required int selectedTabIndex,
    String? searchQuery,
    int? selectedGroupId,
  }) async {
    await SessionPersistenceService.saveUIState(
      selectedTabIndex: selectedTabIndex,
      searchQuery: searchQuery,
      selectedGroupId: selectedGroupId,
    );

    state = state.copyWith(
      uiState: UIState(
        selectedTabIndex: selectedTabIndex,
        searchQuery: searchQuery,
        selectedGroupId: selectedGroupId,
      ),
    );
  }

  /// Save split view state
  Future<void> saveSplitViewState({
    required bool isActive,
    required int paneCount,
    required List<int?> noteIds,
  }) async {
    await SessionPersistenceService.saveSplitViewState(
      isActive: isActive,
      paneCount: paneCount,
      noteIds: noteIds,
    );

    state = state.copyWith(
      splitViewState: SplitViewState(
        isActive: isActive,
        paneCount: paneCount,
        noteIds: noteIds,
      ),
    );
  }

  /// Clear session data
  Future<void> clearSession() async {
    await SessionPersistenceService.clearSession();
    state = const SessionState(isInitialized: true);
  }

  /// Update cursor position for a note
  Future<void> updateCursorPosition(int noteId, int position) async {
    final currentState = state.lastOpenedNotes;
    if (currentState == null) return;

    // Update main editor cursor position
    if (currentState.mainEditorNoteId == noteId) {
      await saveLastOpenedNotes(
        mainEditorNoteId: currentState.mainEditorNoteId,
        cursorPosition: position,
        splitViewNotes: currentState.splitViewNotes,
        splitViewCursorPositions: currentState.splitViewCursorPositions,
      );
    }

    // Update split view cursor positions
    if (currentState.splitViewCursorPositions != null) {
      final updatedPositions = Map<int, int>.from(currentState.splitViewCursorPositions!);
      updatedPositions[noteId] = position;

      await saveLastOpenedNotes(
        mainEditorNoteId: currentState.mainEditorNoteId,
        cursorPosition: currentState.cursorPosition,
        splitViewNotes: currentState.splitViewNotes,
        splitViewCursorPositions: updatedPositions,
      );
    }
  }
}

/// Provider for checking if session has data to restore
final hasSessionDataProvider = Provider<bool>((ref) {
  return SessionPersistenceService.hasSessionData();
});
