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
  static const Duration syncRetryDelay = Duration(seconds: 1);
  static const int maxSyncRetries = 5;
  static const Duration syncBackoffMultiplier = Duration(seconds: 2);
  
  // Soft Delete
  static const int softDeleteDays = 30;
  
  // UI
  static const double borderRadius = 12.0;
  static const double spacing = 16.0;
  static const double smallSpacing = 8.0;
  
  // Default Groups
  static const List<String> defaultGroups = [
    'Work',
    'Personal', 
    'Ideas',
    'Tasks',
    'Uncategorized',
  ];
  
  // Group Colors (Teal variations)
  static const List<String> groupColors = [
    '#14b8a6', // teal-500
    '#0d9488', // teal-600
    '#0f766e', // teal-700
    '#115e59', // teal-800
    '#134e4a', // teal-900
  ];
}
