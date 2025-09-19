import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for persisting and restoring app session state
class SessionPersistenceService {
  static const String _windowStateKey = 'window_state';
  static const String _lastOpenedNotesKey = 'last_opened_notes';
  static const String _uiStateKey = 'ui_state';
  static const String _splitViewStateKey = 'split_view_state';

  static SharedPreferences? _prefs;

  /// Initialize the service
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Save window state (Windows only)
  static Future<void> saveWindowState({
    required Size size,
    required Offset position,
    required bool isMaximized,
  }) async {
    if (!Platform.isWindows) return;

    final windowState = {
      'width': size.width,
      'height': size.height,
      'x': position.dx,
      'y': position.dy,
      // Drop maximize/minimize persistence
      'isMaximized': false,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    await _prefs?.setString(_windowStateKey, jsonEncode(windowState));
  }

  /// Restore window state (Windows only)
  static WindowState? restoreWindowState() {
    if (!Platform.isWindows) return null;

    final stateJson = _prefs?.getString(_windowStateKey);
    if (stateJson == null) return null;

    try {
      final state = jsonDecode(stateJson) as Map<String, dynamic>;
      return WindowState(
        size: Size(state['width']?.toDouble() ?? 800.0, state['height']?.toDouble() ?? 600.0),
        position: Offset(state['x']?.toDouble() ?? 100.0, state['y']?.toDouble() ?? 100.0),
        // Ignore stored maximize/minimize state
        isMaximized: false,
      );
    } catch (e) {
      return null;
    }
  }

  /// Save last opened notes state
  static Future<void> saveLastOpenedNotes({
    int? mainEditorNoteId,
    int? cursorPosition,
    Map<int, int>? splitViewNotes, // pane index -> note id
    Map<int, int>? splitViewCursorPositions, // note id -> cursor position
  }) async {
    final notesState = {
      'mainEditorNoteId': mainEditorNoteId,
      'cursorPosition': cursorPosition,
      'splitViewNotes': splitViewNotes?.map((k, v) => MapEntry(k.toString(), v)),
      'splitViewCursorPositions': splitViewCursorPositions?.map((k, v) => MapEntry(k.toString(), v)),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    await _prefs?.setString(_lastOpenedNotesKey, jsonEncode(notesState));
  }

  /// Restore last opened notes state
  static LastOpenedNotesState? restoreLastOpenedNotes() {
    final stateJson = _prefs?.getString(_lastOpenedNotesKey);
    if (stateJson == null) return null;

    try {
      final state = jsonDecode(stateJson) as Map<String, dynamic>;
      return LastOpenedNotesState(
        mainEditorNoteId: state['mainEditorNoteId'],
        cursorPosition: state['cursorPosition'],
        splitViewNotes: state['splitViewNotes'] != null
            ? Map<int, int>.fromEntries(
                (state['splitViewNotes'] as Map<String, dynamic>).entries.map((e) => MapEntry(int.parse(e.key), e.value as int)))
            : null,
        splitViewCursorPositions: state['splitViewCursorPositions'] != null
            ? Map<int, int>.fromEntries(
                (state['splitViewCursorPositions'] as Map<String, dynamic>).entries.map((e) => MapEntry(int.parse(e.key), e.value as int)))
            : null,
      );
    } catch (e) {
      return null;
    }
  }

  /// Save UI state
  static Future<void> saveUIState({
    required int selectedTabIndex,
    String? searchQuery,
    int? selectedGroupId,
  }) async {
    final uiState = {
      'selectedTabIndex': selectedTabIndex,
      'searchQuery': searchQuery,
      'selectedGroupId': selectedGroupId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    await _prefs?.setString(_uiStateKey, jsonEncode(uiState));
  }

  /// Restore UI state
  static UIState? restoreUIState() {
    final stateJson = _prefs?.getString(_uiStateKey);
    if (stateJson == null) return null;

    try {
      final state = jsonDecode(stateJson) as Map<String, dynamic>;
      return UIState(
        selectedTabIndex: state['selectedTabIndex'] ?? 0,
        searchQuery: state['searchQuery'],
        selectedGroupId: state['selectedGroupId'],
      );
    } catch (e) {
      return null;
    }
  }

  /// Save split view state
  static Future<void> saveSplitViewState({
    required bool isActive,
    required int paneCount,
    required List<int?> noteIds,
  }) async {
    final splitViewState = {
      'isActive': isActive,
      'paneCount': paneCount,
      'noteIds': noteIds,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    await _prefs?.setString(_splitViewStateKey, jsonEncode(splitViewState));
  }

  /// Restore split view state
  static SplitViewState? restoreSplitViewState() {
    final stateJson = _prefs?.getString(_splitViewStateKey);
    if (stateJson == null) return null;

    try {
      final state = jsonDecode(stateJson) as Map<String, dynamic>;
      return SplitViewState(
        isActive: state['isActive'] ?? false,
        paneCount: state['paneCount'] ?? 2,
        noteIds: List<int?>.from(state['noteIds'] ?? []),
      );
    } catch (e) {
      return null;
    }
  }

  /// Clear all session data
  static Future<void> clearSession() async {
    await _prefs?.remove(_windowStateKey);
    await _prefs?.remove(_lastOpenedNotesKey);
    await _prefs?.remove(_uiStateKey);
    await _prefs?.remove(_splitViewStateKey);
  }

  /// Check if session data exists
  static bool hasSessionData() {
    final prefs = _prefs;
    if (prefs == null) return false;
    return prefs.containsKey(_lastOpenedNotesKey) || prefs.containsKey(_uiStateKey);
  }
}

/// Data classes for session state
class WindowState {
  final Size size;
  final Offset position;
  final bool isMaximized;

  const WindowState({
    required this.size,
    required this.position,
    required this.isMaximized,
  });
}

class LastOpenedNotesState {
  final int? mainEditorNoteId;
  final int? cursorPosition;
  final Map<int, int>? splitViewNotes;
  final Map<int, int>? splitViewCursorPositions;

  const LastOpenedNotesState({
    this.mainEditorNoteId,
    this.cursorPosition,
    this.splitViewNotes,
    this.splitViewCursorPositions,
  });
}

class UIState {
  final int selectedTabIndex;
  final String? searchQuery;
  final int? selectedGroupId;

  const UIState({
    required this.selectedTabIndex,
    this.searchQuery,
    this.selectedGroupId,
  });
}

class SplitViewState {
  final bool isActive;
  final int paneCount;
  final List<int?> noteIds;

  const SplitViewState({
    required this.isActive,
    required this.paneCount,
    required this.noteIds,
  });
}

/// Extension methods for easy session persistence
extension SessionPersistence on SessionPersistenceService {
  /// Save complete app state
  static Future<void> saveCompleteState({
    Size? windowSize,
    Offset? windowPosition,
    bool? isMaximized,
    int? mainEditorNoteId,
    int? cursorPosition,
    Map<int, int>? splitViewNotes,
    Map<int, int>? splitViewCursorPositions,
    required int selectedTabIndex,
    String? searchQuery,
    int? selectedGroupId,
    bool? splitViewActive,
    int? splitViewPaneCount,
    List<int?>? splitViewNoteIds,
  }) async {
    // Save window state if provided
    if (windowSize != null && windowPosition != null && isMaximized != null) {
      await SessionPersistenceService.saveWindowState(
        size: windowSize,
        position: windowPosition,
        isMaximized: isMaximized,
      );
    }

    // Save notes state
    await SessionPersistenceService.saveLastOpenedNotes(
      mainEditorNoteId: mainEditorNoteId,
      cursorPosition: cursorPosition,
      splitViewNotes: splitViewNotes,
      splitViewCursorPositions: splitViewCursorPositions,
    );

    // Save UI state
    await SessionPersistenceService.saveUIState(
      selectedTabIndex: selectedTabIndex,
      searchQuery: searchQuery,
      selectedGroupId: selectedGroupId,
    );

    // Save split view state if provided
    if (splitViewActive != null && splitViewPaneCount != null && splitViewNoteIds != null) {
      await SessionPersistenceService.saveSplitViewState(
        isActive: splitViewActive,
        paneCount: splitViewPaneCount,
        noteIds: splitViewNoteIds,
      );
    }
  }
}
