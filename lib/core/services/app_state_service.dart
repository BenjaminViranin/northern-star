import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class AppStateService {
  static const String _lastNoteIdKey = 'last_note_id';
  static const String _splitViewEnabledKey = 'split_view_enabled';
  static const String _windowSizeKey = 'window_size';
  static const String _windowPositionKey = 'window_position';
  static const String _selectedSectionKey = 'selected_section';
  static const String _selectedGroupIdKey = 'selected_group_id';
  static const String _searchQueryKey = 'search_query';
  static const String _expandedGroupsKey = 'expanded_groups';
  static const String _splitViewPaneCountKey = 'split_view_pane_count';
  static const String _splitViewNoteIdsKey = 'split_view_note_ids';

  static const String _editorReadOnlyKey = 'editor_read_only';

  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Last opened note
  static Future<void> saveLastNoteId(int? noteId) async {
    if (_prefs == null) await initialize();
    if (noteId != null) {
      await _prefs!.setInt(_lastNoteIdKey, noteId);
    } else {
      await _prefs!.remove(_lastNoteIdKey);
    }
  }

  static int? getLastNoteId() {
    return _prefs?.getInt(_lastNoteIdKey);
  }

  // Split view state (desktop)
  static Future<void> saveSplitViewEnabled(bool enabled) async {
    if (_prefs == null) await initialize();
    await _prefs!.setBool(_splitViewEnabledKey, enabled);
  }

  static bool getSplitViewEnabled() {
    return _prefs?.getBool(_splitViewEnabledKey) ?? false; // Default to disabled
  }

  // Split view pane count
  static Future<void> saveSplitViewPaneCount(int paneCount) async {
    if (_prefs == null) await initialize();
    await _prefs!.setInt(_splitViewPaneCountKey, paneCount);
  }

  static int getSplitViewPaneCount() {
    return _prefs?.getInt(_splitViewPaneCountKey) ?? 2; // Default to 2 panes
  }

  // Split view note IDs
  static Future<void> saveSplitViewNoteIds(List<int?> noteIds) async {
    if (_prefs == null) await initialize();
    final noteIdsString = noteIds.map((id) => id?.toString() ?? 'null').toList();
    await _prefs!.setStringList(_splitViewNoteIdsKey, noteIdsString);
  }

  static List<int?> getSplitViewNoteIds() {
    final noteIdsString = _prefs?.getStringList(_splitViewNoteIdsKey) ?? [];
    return noteIdsString.map((idString) => idString == 'null' ? null : int.tryParse(idString)).toList();
  }

  // Window size (desktop)
  static Future<void> saveWindowSize(Size size) async {
    if (_prefs == null) await initialize();
    final sizeData = {'width': size.width, 'height': size.height};
    await _prefs!.setString(_windowSizeKey, jsonEncode(sizeData));
  }

  static Size? getWindowSize() {
    final sizeString = _prefs?.getString(_windowSizeKey);
    if (sizeString != null) {
      try {
        final sizeData = jsonDecode(sizeString) as Map<String, dynamic>;
        return Size(sizeData['width']?.toDouble() ?? 1200, sizeData['height']?.toDouble() ?? 800);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Window position (desktop)
  static Future<void> saveWindowPosition(Offset position) async {
    if (_prefs == null) await initialize();
    final positionData = {'x': position.dx, 'y': position.dy};
    await _prefs!.setString(_windowPositionKey, jsonEncode(positionData));
  }

  static Offset? getWindowPosition() {
    final positionString = _prefs?.getString(_windowPositionKey);
    if (positionString != null) {
      try {
        final positionData = jsonDecode(positionString) as Map<String, dynamic>;
        return Offset(positionData['x']?.toDouble() ?? 100, positionData['y']?.toDouble() ?? 100);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Selected navigation section
  static Future<void> saveSelectedSection(String section) async {
    if (_prefs == null) await initialize();
    await _prefs!.setString(_selectedSectionKey, section);
  }

  static String? getSelectedSection() {
    return _prefs?.getString(_selectedSectionKey);
  }

  // Selected group ID
  static Future<void> saveSelectedGroupId(int? groupId) async {
    if (_prefs == null) await initialize();
    if (groupId != null) {
      await _prefs!.setInt(_selectedGroupIdKey, groupId);
    } else {
      await _prefs!.remove(_selectedGroupIdKey);
    }
  }

  static int? getSelectedGroupId() {
    return _prefs?.getInt(_selectedGroupIdKey);
  }

  // Search query
  static Future<void> saveSearchQuery(String query) async {
    if (_prefs == null) await initialize();
    await _prefs!.setString(_searchQueryKey, query);
  }

  static String getSearchQuery() {
    return _prefs?.getString(_searchQueryKey) ?? '';
  }

  // Editor read-only (View Mode)
  static Future<void> saveEditorReadOnly(bool readOnly) async {
    if (_prefs == null) await initialize();
    await _prefs!.setBool(_editorReadOnlyKey, readOnly);
  }

  static bool getEditorReadOnly() {
    return _prefs?.getBool(_editorReadOnlyKey) ?? false; // Default to Edit Mode
  }

  // Expanded groups (for hierarchy view)
  static Future<void> saveExpandedGroups(Set<int> expandedGroups) async {
    if (_prefs == null) await initialize();
    final groupsList = expandedGroups.toList();
    await _prefs!.setStringList(_expandedGroupsKey, groupsList.map((id) => id.toString()).toList());
  }

  static Set<int> getExpandedGroups() {
    final groupsStringList = _prefs?.getStringList(_expandedGroupsKey) ?? [];
    return groupsStringList.map((id) => int.tryParse(id)).where((id) => id != null).cast<int>().toSet();
  }

  // Clear all app state (for logout or reset)
  static Future<void> clearAppState() async {
    if (_prefs == null) await initialize();
    await _prefs!.remove(_lastNoteIdKey);
    await _prefs!.remove(_splitViewEnabledKey);
    await _prefs!.remove(_splitViewPaneCountKey);
    await _prefs!.remove(_splitViewNoteIdsKey);
    await _prefs!.remove(_windowSizeKey);
    await _prefs!.remove(_windowPositionKey);
    await _prefs!.remove(_selectedSectionKey);
    await _prefs!.remove(_selectedGroupIdKey);
    await _prefs!.remove(_searchQueryKey);
    await _prefs!.remove(_expandedGroupsKey);
  }
}
