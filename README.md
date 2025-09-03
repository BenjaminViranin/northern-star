# Northern Star - Flutter Note-Taking App

A powerful, offline-first note-taking application built with Flutter for Android and Windows platforms. Features rich text editing, real-time sync with Supabase, and a beautiful dark theme interface.

## Features

### 🚀 Core Features

-   **Rich Text Editor**: WYSIWYG editor powered by flutter_quill with Quill Delta model
-   **Offline-First Architecture**: All operations work without internet connection
-   **Real-time Sync**: Background synchronization with Supabase when online
-   **Group Organization**: Organize notes into customizable colored groups
-   **Advanced Search**: Full-text search across note titles and content
-   **Auto-save**: 300ms debounced auto-save with visual indicators

### 📱 Platform Support

-   **Android**: Full mobile experience
-   **Windows**: Desktop experience with split-view support (2-4 notes side-by-side)

### 🎨 User Interface

-   **Dark Theme**: Beautiful gray-950 to gray-900 gradient background
-   **Glassy Surfaces**: Translucent surfaces with rounded corners
-   **Three-Section Layout**: Header, Controls, and Content areas
-   **Tabbed Interface**: Notes, Groups, and Settings tabs
-   **Responsive Design**: Adapts to different screen sizes

### 💾 Data Management

-   **Local SQLite Database**: Powered by Drift ORM
-   **Conflict Resolution**: Last-write-wins with local history backup
-   **Soft Delete**: 30-day retention before permanent deletion
-   **Export/Import**: JSON backup and restore functionality

## Prerequisites

-   Flutter SDK (3.16.9 or higher)
-   Dart SDK (3.2.6 or higher)
-   Android Studio / VS Code with Flutter extensions
-   For Windows: Visual Studio 2022 with C++ development tools

## Setup Instructions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd northern_star
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Generate Code

```bash
dart run build_runner build
```

### 4. Configure Supabase (Optional)

1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Run the SQL scripts in `supabase/` folder:
    - `schema.sql` - Creates tables and RLS policies
    - `cleanup_function.sql` - Sets up automated cleanup
3. Update `lib/core/config/supabase_config.dart` with your credentials:

```dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### 5. Run the Application

#### For Windows:

```bash
flutter run -d windows
```

#### For Android:

```bash
flutter run -d android
```

## Project Structure

```
lib/
├── core/
│   ├── constants/          # App-wide constants
│   ├── config/            # Configuration files
│   └── theme/             # Theme and styling
├── data/
│   ├── database/          # Drift database and tables
│   ├── models/            # Data models
│   ├── repositories/      # Data access layer
│   └── services/          # Business logic services
└── presentation/
    ├── providers/         # Riverpod state management
    ├── screens/           # Main app screens
    ├── widgets/           # Reusable UI components
    └── dialogs/           # Modal dialogs
```

## Key Technologies

-   **Flutter**: Cross-platform UI framework
-   **Drift**: Type-safe SQL database ORM
-   **Riverpod**: State management solution
-   **flutter_quill**: Rich text editor
-   **Supabase**: Backend-as-a-Service for sync
-   **SQLite**: Local database storage

## Testing

Run the test suite:

```bash
flutter test
```

Run specific test files:

```bash
flutter test test/repositories/notes_repository_test.dart
```

## Building for Production

### Android APK:

```bash
flutter build apk --release
```

### Windows Executable:

```bash
flutter build windows --release
```

## Architecture Highlights

### Offline-First Design

-   All read/write operations go to local SQLite
-   Network operations never block the UI
-   Background sync queue with exponential backoff
-   Conflict resolution with local history preservation

### Rich Text Editing

-   Quill Delta JSON storage for structured content
-   Derived Markdown and plain text for export/search
-   Auto-save with 300ms debounce
-   Visual save status indicators

### State Management

-   Riverpod providers for reactive state
-   Stream-based data flow
-   Family providers for parameterized state
-   Proper disposal and cleanup

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions, please create an issue in the GitHub repository.
