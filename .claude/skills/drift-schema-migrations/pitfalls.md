# Drift Migrations — Pitfalls Catalog

| # | Symptom | Cause | Fix | Source |
|---|---|---|---|---|
| 1 | Production users crash on app update with "no such column X" | Migration step edited after release; users on older version expected the OLD path | NEVER edit shipped migrations. Append a new step (bump schemaVersion); each step idempotent | [Drift migrations](https://drift.simonbinder.eu/migrations/) |
| 2 | Foreign key violations build up silently | SQLite FK enforcement OFF by default | `PRAGMA foreign_keys = ON` in `beforeOpen` (per snippet) | [SQLite FK pragma](https://www.sqlite.org/foreignkeys.html) |
| 3 | App boots fine in debug, crashes in release with `MissingPluginException: drift` | R8/ProGuard stripped Drift's generated code | Add `-keep class drift.** { *; }` (per `ios-android-hardening`) | drift docs |
| 4 | Data lost on schema "fix" via dropTable+createTable | User data gone | Use `ALTER TABLE ... ADD COLUMN ...` via `customStatement` OR multi-step migration with INSERT INTO copy | SQLite ALTER TABLE docs |
| 5 | Schema dump never run; CI doesn't catch a broken migration | `dart run drift_dev schema dump` + `schema generate` not in workflow | Add to CI: dump → generate tests → run tests. The auto-generated tests cover every upgrade path | [drift_dev schema](https://drift.simonbinder.eu/migrations/tests/) |
| 6 | `onUpgrade` partial failure → next run crashes because half-applied | Step not idempotent (e.g., CREATE INDEX without IF NOT EXISTS) | Use `IF NOT EXISTS` for indexes/tables; for column adds, check schema first | drift migration patterns |
| 7 | DateTime stored in local TZ → analytics queries wrong | Drift's `dateTime()` column type stores whatever you give — TZ confusion | Discipline: ALL `DateTime` values in domain layer are UTC; convert at presentation layer | this skill's own pattern |
| 8 | JSON column reads back as String, not Map | Forgot to attach TypeConverter | `text().map(const JsonColumnConverter()).nullable()()` (per snippet) | drift type converters |
| 9 | iOS app uses system SQLite (older), Android uses bundled — query divergence | `sqlite3_flutter_libs` not added | Add the package; it ships a consistent SQLite on both platforms | sqlite3_flutter_libs |
| 10 | After `flutter clean`, `*.g.dart` files missing → build fails | drift codegen not re-run | `dart run build_runner build --delete-conflicting-outputs` after every clean | drift codegen docs |
