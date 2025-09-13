import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:northern_star/core/services/session_persistence_service.dart';

void main() {
  group('Session Persistence Tests', () {
    setUp(() async {
      // Clear any existing preferences
      SharedPreferences.setMockInitialValues({});
      await SessionPersistenceService.initialize();
    });

    group('Window State Persistence', () {
      test('should save and restore window state', () async {
        const size = Size(1200, 800);
        const position = Offset(100, 100);
        const isMaximized = false;

        // Save window state
        await SessionPersistenceService.saveWindowState(
          size: size,
          position: position,
          isMaximized: isMaximized,
        );

        // Restore window state
        final restoredState = SessionPersistenceService.restoreWindowState();

        expect(restoredState, isNotNull);
        expect(restoredState!.size, equals(size));
        expect(restoredState.position, equals(position));
        expect(restoredState.isMaximized, equals(isMaximized));
      });

      test('should return null when no window state exists', () {
        final restoredState = SessionPersistenceService.restoreWindowState();
        expect(restoredState, isNull);
      });
    });

    group('Notes State Persistence', () {
      test('should save and restore last opened notes', () async {
        const mainEditorNoteId = 123;
        const cursorPosition = 45;
        final splitViewNotes = {0: 456, 1: 789};
        final splitViewCursorPositions = {456: 10, 789: 20};

        // Save notes state
        await SessionPersistenceService.saveLastOpenedNotes(
          mainEditorNoteId: mainEditorNoteId,
          cursorPosition: cursorPosition,
          splitViewNotes: splitViewNotes,
          splitViewCursorPositions: splitViewCursorPositions,
        );

        // Restore notes state
        final restoredState = SessionPersistenceService.restoreLastOpenedNotes();

        expect(restoredState, isNotNull);
        expect(restoredState!.mainEditorNoteId, equals(mainEditorNoteId));
        expect(restoredState.cursorPosition, equals(cursorPosition));
        expect(restoredState.splitViewNotes, equals(splitViewNotes));
        expect(restoredState.splitViewCursorPositions, equals(splitViewCursorPositions));
      });

      test('should return null when no notes state exists', () {
        final restoredState = SessionPersistenceService.restoreLastOpenedNotes();
        expect(restoredState, isNull);
      });
    });

    group('UI State Persistence', () {
      test('should save and restore UI state', () async {
        const selectedTabIndex = 1;
        const searchQuery = 'test search';
        const selectedGroupId = 42;

        // Save UI state
        await SessionPersistenceService.saveUIState(
          selectedTabIndex: selectedTabIndex,
          searchQuery: searchQuery,
          selectedGroupId: selectedGroupId,
        );

        // Restore UI state
        final restoredState = SessionPersistenceService.restoreUIState();

        expect(restoredState, isNotNull);
        expect(restoredState!.selectedTabIndex, equals(selectedTabIndex));
        expect(restoredState.searchQuery, equals(searchQuery));
        expect(restoredState.selectedGroupId, equals(selectedGroupId));
      });

      test('should return null when no UI state exists', () {
        final restoredState = SessionPersistenceService.restoreUIState();
        expect(restoredState, isNull);
      });
    });

    group('Split View State Persistence', () {
      test('should save and restore split view state', () async {
        const isActive = true;
        const paneCount = 3;
        final noteIds = [123, 456, null];

        // Save split view state
        await SessionPersistenceService.saveSplitViewState(
          isActive: isActive,
          paneCount: paneCount,
          noteIds: noteIds,
        );

        // Restore split view state
        final restoredState = SessionPersistenceService.restoreSplitViewState();

        expect(restoredState, isNotNull);
        expect(restoredState!.isActive, equals(isActive));
        expect(restoredState.paneCount, equals(paneCount));
        expect(restoredState.noteIds, equals(noteIds));
      });

      test('should return null when no split view state exists', () {
        final restoredState = SessionPersistenceService.restoreSplitViewState();
        expect(restoredState, isNull);
      });
    });

    group('Session Data Management', () {
      test('should detect when session data exists', () async {
        // Initially no session data
        expect(SessionPersistenceService.hasSessionData(), isFalse);

        // Save some UI state
        await SessionPersistenceService.saveUIState(
          selectedTabIndex: 0,
        );

        // Now session data should exist
        expect(SessionPersistenceService.hasSessionData(), isTrue);
      });

      test('should clear all session data', () async {
        // Save various types of session data
        await SessionPersistenceService.saveUIState(selectedTabIndex: 1);
        await SessionPersistenceService.saveLastOpenedNotes(mainEditorNoteId: 123);
        await SessionPersistenceService.saveSplitViewState(
          isActive: true,
          paneCount: 2,
          noteIds: [1, 2],
        );

        // Verify data exists
        expect(SessionPersistenceService.hasSessionData(), isTrue);

        // Clear all session data
        await SessionPersistenceService.clearSession();

        // Verify all data is cleared
        expect(SessionPersistenceService.hasSessionData(), isFalse);
        expect(SessionPersistenceService.restoreUIState(), isNull);
        expect(SessionPersistenceService.restoreLastOpenedNotes(), isNull);
        expect(SessionPersistenceService.restoreSplitViewState(), isNull);
      });
    });

    group('Data Validation', () {
      test('should handle corrupted session data gracefully', () async {
        // Manually set corrupted data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ui_state', 'invalid json');

        // Should return null instead of throwing
        final restoredState = SessionPersistenceService.restoreUIState();
        expect(restoredState, isNull);
      });

      test('should handle missing fields in session data', () async {
        // Manually set incomplete data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ui_state', '{"selectedTabIndex": 1}'); // Missing other fields

        // Should still restore what's available
        final restoredState = SessionPersistenceService.restoreUIState();
        expect(restoredState, isNotNull);
        expect(restoredState!.selectedTabIndex, equals(1));
        expect(restoredState.searchQuery, isNull);
        expect(restoredState.selectedGroupId, isNull);
      });
    });
  });
}
