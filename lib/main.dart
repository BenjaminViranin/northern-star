import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';

import 'core/theme/app_theme.dart';
import 'core/config/supabase_config.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set window size for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(800, 800), // Square window
      minimumSize: Size(600, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Initialize Supabase
  await SupabaseConfig.initialize();

  runApp(const ProviderScope(child: NorthernStarApp()));
}

class NorthernStarApp extends StatelessWidget {
  const NorthernStarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Northern Star',
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
