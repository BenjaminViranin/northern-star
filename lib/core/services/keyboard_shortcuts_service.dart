import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/providers/database_provider.dart';
import '../../presentation/dialogs/create_note_dialog.dart';

/// Service for handling keyboard shortcuts throughout the app
class KeyboardShortcutsService {
  static final _shortcuts = <LogicalKeySet, Intent>{
    // Create new note: Ctrl+N (Windows) / Cmd+N (macOS)
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const CreateNoteIntent(),
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyN): const CreateNoteIntent(),

    // Save note: Ctrl+S (Windows) / Cmd+S (macOS)
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): const SaveNoteIntent(),
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS): const SaveNoteIntent(),

    // Search: Ctrl+F (Windows) / Cmd+F (macOS)
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF): const SearchIntent(),
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyF): const SearchIntent(),

    // Quick group switch: Ctrl+G (Windows) / Cmd+G (macOS)
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyG): const GroupSwitchIntent(),
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyG): const GroupSwitchIntent(),
  };

  static Map<Type, Action<Intent>> getActions(BuildContext context, WidgetRef ref) {
    return <Type, Action<Intent>>{
      CreateNoteIntent: CreateNoteAction(context, ref),
      SaveNoteIntent: SaveNoteAction(context, ref),
      SearchIntent: SearchAction(context, ref),
      GroupSwitchIntent: GroupSwitchAction(context, ref),
    };
  }

  static Map<LogicalKeySet, Intent> get shortcuts => _shortcuts;
}

/// Intent classes for keyboard shortcuts
class CreateNoteIntent extends Intent {
  const CreateNoteIntent();
}

class SaveNoteIntent extends Intent {
  const SaveNoteIntent();
}

class SearchIntent extends Intent {
  const SearchIntent();
}

class GroupSwitchIntent extends Intent {
  const GroupSwitchIntent();
}

/// Action classes for keyboard shortcuts
class CreateNoteAction extends Action<CreateNoteIntent> {
  final BuildContext context;
  final WidgetRef ref;

  CreateNoteAction(this.context, this.ref);

  @override
  Object? invoke(CreateNoteIntent intent) {
    showDialog(
      context: context,
      builder: (context) => const CreateNoteDialog(),
    );
    return null;
  }
}

class SaveNoteAction extends Action<SaveNoteIntent> {
  final BuildContext context;
  final WidgetRef ref;

  SaveNoteAction(this.context, this.ref);

  @override
  Object? invoke(SaveNoteIntent intent) {
    // The auto-save functionality handles saving automatically
    // This could trigger an immediate save if needed
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Auto-save is enabled'),
        duration: Duration(seconds: 1),
      ),
    );
    return null;
  }
}

class SearchAction extends Action<SearchIntent> {
  final BuildContext context;
  final WidgetRef ref;

  SearchAction(this.context, this.ref);

  @override
  Object? invoke(SearchIntent intent) {
    // Focus on search field if it exists
    // This would need to be implemented with a focus node
    return null;
  }
}

class GroupSwitchAction extends Action<GroupSwitchIntent> {
  final BuildContext context;
  final WidgetRef ref;

  GroupSwitchAction(this.context, this.ref);

  @override
  Object? invoke(GroupSwitchIntent intent) {
    // Cycle through groups
    final groups = ref.read(groupsProvider).value;
    final currentGroupId = ref.read(selectedGroupProvider);

    if (groups != null && groups.isNotEmpty) {
      final currentIndex = currentGroupId == null ? -1 : groups.indexWhere((g) => g.id == currentGroupId);

      final nextIndex = (currentIndex + 1) % (groups.length + 1);
      final nextGroupId = nextIndex == 0 ? null : groups[nextIndex - 1].id;

      ref.read(selectedGroupProvider.notifier).state = nextGroupId;

      final groupName = nextGroupId == null ? 'All Groups' : groups.firstWhere((g) => g.id == nextGroupId).name;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to: $groupName'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
    return null;
  }
}
