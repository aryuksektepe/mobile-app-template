---
name: drift-schema-migrations
description: Drift local DB schema + migration patterns — append-only migration discipline (NEVER edit shipped migrations), schema dump per version + generated upgrade tests, type converters (Enum/DateTime/JSON), FK PRAGMA enabled, atomic transactions, async queries, custom indexes, JSON columns. Use whenever the app adds a Drift table / column / type change / index.
triggers: [drift, schema migration, drift migration, schemaVersion, onUpgrade, type converter, custom statement, FK pragma, foreign keys pragma, drift json column, drift transaction, drift companion]
platforms: [ios, android]
last_verified: 2026-05-26
flutter_min: "3.22.0"
package_versions:
  drift: "^2.21.0"
  drift_dev: "^2.21.0"
  sqlite3_flutter_libs: "^0.5.24"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# Drift Schema + Migrations

## What this skill does

- Append-only migration discipline — once a migration ships, never edit it; new migration on top.
- Schema dump at each version (`tool/drift_schema_dump.dart`) → `drift_dev` generates upgrade tests automatically.
- `onUpgrade` block: deterministic, idempotent, ONE step per version bump.
- `PRAGMA foreign_keys = ON` (Drift defaults OFF — silent FK violations otherwise).
- Type converters: Enum, DateTime (UTC discipline), `Map<String, dynamic>` JSON column.
- Transactions for multi-table atomic writes.
- Custom indexes via `customStatement` in `onCreate` / per-migration step.

## What this skill does NOT do

- Does NOT replace Riverpod repository pattern (Drift = data layer; repository wraps).
- Does NOT handle Supabase mirror (that's `supabase-read-through-cache-mirror`).

## Decision tree

**Q1: Edit existing migration or append new?**
- **ALWAYS APPEND.** Shipped migrations are part of users' upgrade history. Editing = data corruption for anyone who ran the old version.

**Q2: Schema dump testing?**
- YES (mandatory) — run `dart run drift_dev schema dump lib/src/data/app_database.dart drift_schemas/` after each version bump. Generated tests verify every upgrade path.

**Q3: FK enforcement?**
- ON (default in this skill) — SQLite ships with FK OFF; you MUST enable in `LazyDatabase` setup or stale rows accumulate silently.

## Quick start

```bash
flutter pub add drift sqlite3_flutter_libs
flutter pub add --dev drift_dev build_runner
```

Apply [snippets/app_database.dart](snippets/app_database.dart). Run `dart run build_runner build`.

For every schema change:
1. Bump `schemaVersion`.
2. Add an `onUpgrade` step (NEVER edit prior steps).
3. Dump the new schema: `dart run drift_dev schema dump lib/src/data/app_database.dart drift_schemas/`.
4. Generate upgrade tests: `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/`.
5. Run tests: `flutter test test/generated_migrations/`.

## Code patterns

| Need | File |
|---|---|
| AppDatabase skeleton + onUpgrade + type converters + FK | [snippets/app_database.dart](snippets/app_database.dart) |
| JSON column converter | [snippets/json_column_converter.dart](snippets/json_column_converter.dart) |

## Known pitfalls

→ [pitfalls.md](pitfalls.md). Top 5:
1. Editing a shipped migration → users on older versions corrupt on upgrade.
2. FK PRAGMA off (default) → stale orphan rows silently accumulate.
3. `onUpgrade` not idempotent — partial upgrade midway through, retry crashes.
4. `dropTable` then `createTable` to "fix" a column type → user data lost; use `ALTER TABLE` via `customStatement`.
5. Schema dump skipped → no upgrade test → migration ship-bug silently slips past CI.

## Verification

→ [checklist.md](checklist.md).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-26
- Depends on: (none)
