/// Application-wide constants
class AppConstants {
  // App Info
  static const String appName = 'Northern Star';
  static const String appVersion = '1.0.0';

  // Database
  static const String databaseName = 'northern_star.db';
  static const int databaseVersion = 1;

  // Autosave
  static const Duration autosaveDebounce = Duration(milliseconds: 300);

  // Sync
  static const Duration syncRetryDelay = Duration(seconds: 30);
  static const int maxSyncRetries = 5;
  static const Duration syncBackoffMultiplier = Duration(seconds: 2);
  static const Duration syncInterval = Duration(minutes: 5);
  static const int syncBatchSize = 50;
  static const Duration syncTimeout = Duration(seconds: 30);

  // Soft Delete
  static const int softDeleteDays = 30;

  // UI
  static const double borderRadius = 12.0;
  static const double spacing = 16.0;
  static const double smallSpacing = 8.0;
  static const Duration animationDuration = Duration(milliseconds: 200);
  static const Duration debounceDelay = Duration(milliseconds: 300);

  // Search
  static const int searchMinLength = 2;
  static const Duration searchDelay = Duration(milliseconds: 500);

  // Window configuration (Windows platform)
  static const double defaultWindowWidth = 1200;
  static const double defaultWindowHeight = 800;
  static const double minWindowWidth = 800;
  static const double minWindowHeight = 600;

  // Split view configuration
  static const int maxSplitPanes = 4;
  static const int minSplitPanes = 2;
  static const double minPaneWidth = 300;

  // Responsive design breakpoints
  static const double mobileBreakpoint = 768;
  static const double tabletBreakpoint = 1024;
  static const double desktopBreakpoint = 1200;

  // Default Groups
  static const List<String> defaultGroups = [
    'Work',
    'Personal',
    'Ideas',
    'Tasks',
    'Uncategorized',
  ];

  // Group Colors (12 diverse colors)
  static const List<String> groupColors = [
    '#14b8a6', // Teal
    '#3b82f6', // Blue
    '#8b5cf6', // Purple
    '#ec4899', // Pink
    '#ef4444', // Red
    '#f97316', // Orange
    '#eab308', // Yellow
    '#22c55e', // Green
    '#06b6d4', // Cyan
    '#6366f1', // Indigo
    '#84cc16', // Lime
    '#f59e0b', // Amber
  ];

  // Development and debugging
  static const bool enableDebugLogging = true;
  static const bool enablePerformanceMonitoring = false;
}
