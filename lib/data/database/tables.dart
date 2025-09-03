import 'package:drift/drift.dart';

/// Groups table for organizing notes
class Groups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get color => text().withLength(min: 7, max: 7)(); // Hex color
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  // Supabase sync fields
  TextColumn get supabaseId => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
}

/// Notes table for storing note content
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get content => text()(); // Quill Delta JSON
  TextColumn get markdown => text()(); // Derived markdown for export
  TextColumn get plainText => text()(); // For search
  IntColumn get groupId => integer().references(Groups, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  // Supabase sync fields
  TextColumn get supabaseId => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
}

/// Sync queue for offline operations
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get operation => text()(); // 'create', 'update', 'delete'
  TextColumn get entityTable => text()(); // 'notes' or 'groups'
  IntColumn get localId => integer()();
  TextColumn get data => text()(); // JSON data
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
}

/// Local history for conflict resolution
class LocalHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityTable => text()(); // 'notes' or 'groups'
  IntColumn get recordId => integer()();
  TextColumn get data => text()(); // JSON snapshot
  TextColumn get operation => text()(); // 'conflict_backup', 'manual_backup'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// App settings and preferences
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
