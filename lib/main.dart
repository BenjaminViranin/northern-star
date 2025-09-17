import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import 'core/theme/app_theme.dart';
import 'core/config/supabase_config.dart';
import 'core/services/session_persistence_service.dart';
import 'core/services/window_manager_service.dart';
import 'core/services/app_state_service.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/providers/database_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager first (Windows only)
  await WindowManagerService.initialize();

  // Initialize Supabase
  await SupabaseConfig.initialize();

  // Initialize session persistence
  await SessionPersistenceService.initialize();

  // Initialize app state service
  await AppStateService.initialize();

  runApp(const ProviderScope(child: NorthernStarApp()));

  // Configure window for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    doWhenWindowReady(() {
      // Window configuration is handled in WindowManagerService.initialize()
    });
  }
}

class NorthernStarApp extends ConsumerWidget {
  const NorthernStarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize user session manager
    ref.watch(userSessionManagerProvider);

    return MaterialApp(
      title: 'Northern Star',
      theme: AppTheme.darkTheme,
      home: const WindowStateManager(
        child: HomeScreen(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
