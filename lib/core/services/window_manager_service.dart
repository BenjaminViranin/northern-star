import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_persistence_service.dart';
import '../../presentation/providers/session_provider.dart';

/// Service for managing window state on desktop platforms
class WindowManagerService {
  static WindowManagerService? _instance;
  static WindowManagerService get instance => _instance ??= WindowManagerService._();

  WindowManagerService._();

  /// Initialize window manager and restore window state
  static Future<void> initialize() async {
    if (!Platform.isWindows) return;

    // For now, we'll use a simple approach since window_manager package
    // would require additional setup. In a real implementation, you would
    // use the window_manager package to control window properties.

    // This is a placeholder for window management functionality
    // In a production app, you would:
    // 1. Add window_manager dependency
    // 2. Initialize window manager
    // 3. Restore window size, position, and state
  }

  /// Save current window state
  static Future<void> saveWindowState({
    required Size size,
    required Offset position,
    required bool isMaximized,
  }) async {
    if (!Platform.isWindows) return;

    await SessionPersistenceService.saveWindowState(
      size: size,
      position: position,
      isMaximized: isMaximized,
    );
  }

  /// Restore window state from session
  static Future<void> restoreWindowState() async {
    if (!Platform.isWindows) return;

    final windowState = SessionPersistenceService.restoreWindowState();
    if (windowState == null) return;

    // In a real implementation with window_manager package:
    // await windowManager.setSize(windowState.size);
    // await windowManager.setPosition(windowState.position);
    // if (windowState.isMaximized) {
    //   await windowManager.maximize();
    // }
  }

  /// Get default window size
  static Size getDefaultWindowSize() {
    return const Size(1200, 800);
  }

  /// Get default window position
  static Offset getDefaultWindowPosition() {
    return const Offset(100, 100);
  }

  /// Check if window state should be saved
  static bool shouldSaveWindowState() {
    return Platform.isWindows;
  }
}

/// Provider for window manager service
final windowManagerProvider = Provider<WindowManagerService>((ref) {
  return WindowManagerService.instance;
});

/// Widget that manages window state persistence
class WindowStateManager extends ConsumerStatefulWidget {
  final Widget child;

  const WindowStateManager({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<WindowStateManager> createState() => _WindowStateManagerState();
}

class _WindowStateManagerState extends ConsumerState<WindowStateManager> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Restore window state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WindowManagerService.restoreWindowState();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Save window state when app is paused or detached
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _saveCurrentWindowState();
    }
  }

  void _saveCurrentWindowState() {
    if (!WindowManagerService.shouldSaveWindowState()) return;

    // In a real implementation, you would get the actual window properties
    // For now, we'll save default values
    final size = WindowManagerService.getDefaultWindowSize();
    final position = WindowManagerService.getDefaultWindowPosition();
    const isMaximized = false;

    WindowManagerService.saveWindowState(
      size: size,
      position: position,
      isMaximized: isMaximized,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Extension for easy window state management
extension WindowStateExtension on WidgetRef {
  /// Save window state through session provider
  Future<void> saveWindowState({
    required Size size,
    required Offset position,
    required bool isMaximized,
  }) async {
    await read(sessionProvider.notifier).saveWindowState(
      size: size,
      position: position,
      isMaximized: isMaximized,
    );
  }
}

/// Mock window state for development
class MockWindowState {
  static Size currentSize = const Size(1200, 800);
  static Offset currentPosition = const Offset(100, 100);
  static bool isMaximized = false;

  static void updateSize(Size size) {
    currentSize = size;
  }

  static void updatePosition(Offset position) {
    currentPosition = position;
  }

  static void setMaximized(bool maximized) {
    isMaximized = maximized;
  }
}

/// Provider for mock window state (for development)
final mockWindowStateProvider = StateNotifierProvider<MockWindowStateNotifier, MockWindowStateData>((ref) {
  return MockWindowStateNotifier();
});

class MockWindowStateData {
  final Size size;
  final Offset position;
  final bool isMaximized;

  const MockWindowStateData({
    required this.size,
    required this.position,
    required this.isMaximized,
  });

  MockWindowStateData copyWith({
    Size? size,
    Offset? position,
    bool? isMaximized,
  }) {
    return MockWindowStateData(
      size: size ?? this.size,
      position: position ?? this.position,
      isMaximized: isMaximized ?? this.isMaximized,
    );
  }
}

class MockWindowStateNotifier extends StateNotifier<MockWindowStateData> {
  MockWindowStateNotifier()
      : super(const MockWindowStateData(
          size: Size(1200, 800),
          position: Offset(100, 100),
          isMaximized: false,
        ));

  void updateSize(Size size) {
    state = state.copyWith(size: size);
    _saveState();
  }

  void updatePosition(Offset position) {
    state = state.copyWith(position: position);
    _saveState();
  }

  void setMaximized(bool maximized) {
    state = state.copyWith(isMaximized: maximized);
    _saveState();
  }

  void _saveState() {
    WindowManagerService.saveWindowState(
      size: state.size,
      position: state.position,
      isMaximized: state.isMaximized,
    );
  }
}
