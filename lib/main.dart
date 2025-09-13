import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/config/supabase_config.dart';
import 'core/services/session_persistence_service.dart';
import 'core/services/window_manager_service.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseConfig.initialize();

  // Initialize session persistence
  await SessionPersistenceService.initialize();

  // Initialize window manager
  await WindowManagerService.initialize();

  runApp(const ProviderScope(child: NorthernStarApp()));
}

class NorthernStarApp extends StatelessWidget {
  const NorthernStarApp({super.key});

  @override
  Widget build(BuildContext context) {
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
