import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import 'session_persistence_service.dart';
import 'app_state_service.dart';
import '../../presentation/providers/session_provider.dart';

/// Service for managing window state on desktop platforms
class WindowManagerService {
  static WindowManagerService? _instance;
  static WindowManagerService get instance => _instance ??= WindowManagerService._();

  WindowManagerService._();

  /// Initialize window manager and restore window state
  static Future<void> initialize() async {
    if (!Platform.isWindows) return;

    try {
      // Initialize bitsdojo_window
      doWhenWindowReady(() {
        // Set minimum window size
        appWindow.minSize = const Size(800, 600);

        // Try to restore from AppStateService first, then fallback to SessionPersistenceService
        final appStateSize = AppStateService.getWindowSize();
        final appStatePosition = AppStateService.getWindowPosition();

        if (appStateSize != null && appStatePosition != null) {
          final Size size = (appStateSize.width < 200 || appStateSize.height < 200) ? getDefaultWindowSize() : appStateSize;
          final Offset position = (appStatePosition.dx < 0 || appStatePosition.dy < 0) ? getDefaultWindowPosition() : appStatePosition;

          appWindow.restore();
          appWindow.size = size;
          appWindow.position = position;

          // Update mock state for compatibility
          MockWindowState.currentSize = size;
          MockWindowState.currentPosition = position;
          MockWindowState.isMaximized = false;
        } else {
          // Fallback to session persistence
          final windowState = SessionPersistenceService.restoreWindowState();
          if (windowState != null) {
            final Size size = (windowState.size.width < 200 || windowState.size.height < 200) ? getDefaultWindowSize() : windowState.size;
            final Offset position =
                (windowState.position.dx < 0 || windowState.position.dy < 0) ? getDefaultWindowPosition() : windowState.position;

            appWindow.restore();
            appWindow.size = size;
            appWindow.position = position;

            // Update mock state for compatibility
            MockWindowState.currentSize = size;
            MockWindowState.currentPosition = position;
            MockWindowState.isMaximized = false;
          } else {
            // Set default size and show window
            appWindow.restore();
            appWindow.size = getDefaultWindowSize();
            appWindow.position = getDefaultWindowPosition();

            MockWindowState.currentSize = getDefaultWindowSize();
            MockWindowState.currentPosition = getDefaultWindowPosition();
            MockWindowState.isMaximized = false;
          }
        }

        // Show the window
        appWindow.show();
      });
    } catch (e) {
      // If window manager fails, fall back to mock state
      final appStateSize = AppStateService.getWindowSize();
      final appStatePosition = AppStateService.getWindowPosition();

      if (appStateSize != null && appStatePosition != null) {
        MockWindowState.currentSize = appStateSize;
        MockWindowState.currentPosition = appStatePosition;
      } else {
        final windowState = SessionPersistenceService.restoreWindowState();
        if (windowState != null) {
          MockWindowState.currentSize = windowState.size;
          MockWindowState.currentPosition = windowState.position;
          MockWindowState.isMaximized = false;
        }
      }
    }
  }

  /// Save current window state
  static Future<void> saveWindowState({
    Size? size,
    Offset? position,
    bool? isMaximized,
  }) async {
    if (!Platform.isWindows) return;

    try {
      // Get current window state if not provided
      final currentSize = size ?? appWindow.size;
      final currentPosition = position ?? appWindow.position;
      final currentMaximized = false;

      print('Saving window state:');
      print('  size: $currentSize');
      print('  position: $currentPosition');

      // Save to both services for redundancy
      await AppStateService.saveWindowSize(currentSize);
      await AppStateService.saveWindowPosition(currentPosition);

      await SessionPersistenceService.saveWindowState(
        size: currentSize,
        position: currentPosition,
        isMaximized: currentMaximized,
      );

      // Update mock state for compatibility
      MockWindowState.currentSize = currentSize;
      MockWindowState.currentPosition = currentPosition;
      MockWindowState.isMaximized = currentMaximized;
    } catch (e) {
      // If window manager fails, use provided values or mock state
      final fallbackSize = size ?? MockWindowState.currentSize;
      final fallbackPosition = position ?? MockWindowState.currentPosition;
      final fallbackMaximized = false;

      await AppStateService.saveWindowSize(fallbackSize);
      await AppStateService.saveWindowPosition(fallbackPosition);

      await SessionPersistenceService.saveWindowState(
        size: fallbackSize,
        position: fallbackPosition,
        isMaximized: fallbackMaximized,
      );
    }
  }

  /// Restore window state from session
  static Future<void> restoreWindowState() async {
    if (!Platform.isWindows) return;

    try {
      final windowState = SessionPersistenceService.restoreWindowState();
      if (windowState == null) {
        print('No window state to restore');
        return;
      }

      // Validate and clamp values
      final Size size = (windowState.size.width < 200 || windowState.size.height < 200) ? getDefaultWindowSize() : windowState.size;
      final Offset position =
          (windowState.position.dx < 0 || windowState.position.dy < 0) ? getDefaultWindowPosition() : windowState.position;

      // Apply to real window and ensure it's visible and focused
      appWindow.restore();
      appWindow.size = size;
      appWindow.position = position;

      appWindow.show();

      // Update mock state for compatibility
      MockWindowState.currentSize = size;
      MockWindowState.currentPosition = position;
      MockWindowState.isMaximized = windowState.isMaximized;
    } catch (e) {
      // If bitsdojo_window fails, just update mock state
      final windowState = SessionPersistenceService.restoreWindowState();
      if (windowState != null) {
        MockWindowState.currentSize = windowState.size;
        MockWindowState.currentPosition = windowState.position;
        MockWindowState.isMaximized = windowState.isMaximized;
      }
    }
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
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Window restore handled during WindowManagerService.initialize()

    // Periodically save window state (every 5 seconds)
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (WindowManagerService.shouldSaveWindowState()) {
        print('Periodic window state save');
        WindowManagerService.saveWindowState();
      }
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    print('App lifecycle state changed: $state');

    // Save window state when app is paused or detached
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      print('Saving window state due to lifecycle change');
      _saveCurrentWindowState();
    }
  }

  void _saveCurrentWindowState() {
    if (!WindowManagerService.shouldSaveWindowState()) return;

    // Save current window state (the method will get current state from bitsdojo_window)
    WindowManagerService.saveWindowState();
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
