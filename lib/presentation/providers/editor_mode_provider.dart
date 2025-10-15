import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/app_state_service.dart';

/// Global editor mode provider: false = Edit Mode (default), true = View Mode (read-only)
final editorModeProvider = StateNotifierProvider<EditorModeNotifier, bool>((ref) {
  return EditorModeNotifier();
});

class EditorModeNotifier extends StateNotifier<bool> {
  EditorModeNotifier() : super(AppStateService.getEditorReadOnly()) {
    _init();
  }

  Future<void> _init() async {
    await AppStateService.initialize();
    state = AppStateService.getEditorReadOnly();
  }

  void toggle() {
    final next = !state;
    state = next;
    AppStateService.saveEditorReadOnly(next);
  }

  void set(bool value) {
    state = value;
    AppStateService.saveEditorReadOnly(value);
  }
}
