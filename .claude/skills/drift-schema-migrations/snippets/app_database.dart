// lib/src/data/app_database.dart
// AppDatabase skeleton with:
//   - LazyDatabase + FK PRAGMA ON
//   - onCreate / onUpgrade with APPEND-ONLY migrations
//   - Type converters (Enum, DateTime UTC, JSON)
//   - Sample table

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'json_column_converter.dart';

part 'app_database.g.dart';

// ---- Tables ----

enum UserRole { user, admin, guest }

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get email => text().unique()();
  IntColumn get role => intEnum<UserRole>()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get metadata => text().map(const JsonColumnConverter()).nullable()();
}

class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startedAt => dateTime()();
}

// ---- Database ----

@DriftDatabase(tables: [Users, Sessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Indexes (use customStatement so they're reproducible across schemas)
          await customStatement('CREATE INDEX idx_sessions_user ON sessions(user_id)');
        },
        onUpgrade: (m, from, to) async {
          // APPEND-ONLY. Never edit older steps.
          // Each step is idempotent (uses IF NOT EXISTS where possible).
          if (from < 2) {
            // v1 → v2 migration goes here when needed
            // await m.addColumn(users, users.something);
          }
          if (from < 3) {
            // v2 → v3
          }
          // Re-create indexes that depend on changed schema:
          // await customStatement('CREATE INDEX IF NOT EXISTS ...');
        },
        beforeOpen: (details) async {
          // CRITICAL: SQLite ships with FK OFF. Enable per connection.
          await customStatement('PRAGMA foreign_keys = ON');
          if (details.wasCreated) {
            // First-time seed data
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.sqlite'));

    // Android NDK fix
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    // iOS: ensure we use the bundled SQLite (newer than system's)
    sqlite3.tempDirectory = (await getTemporaryDirectory()).path;

    return NativeDatabase.createInBackground(file, logStatements: false);
  });
}
