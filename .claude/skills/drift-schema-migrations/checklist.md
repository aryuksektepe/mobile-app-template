# Drift Schema + Migrations — Verification Checklist

Owned by `db-migration` agent at every schema-change phase.

## Schema discipline
- [ ] `schemaVersion` bumped (`v1 → v2 → ...`)
- [ ] New migration step appended (NEVER edited prior step)
- [ ] Each step is idempotent (`IF NOT EXISTS`, conditional adds)
- [ ] Multi-table mutations wrapped in `transaction(() async { ... })`

## PRAGMAs + setup
- [ ] `PRAGMA foreign_keys = ON` in `beforeOpen`
- [ ] `sqlite3_flutter_libs` added (consistent SQLite across iOS + Android)
- [ ] Android workaround `applyWorkaroundToOpenSqlite3OnOldAndroidVersions()` called

## Codegen + tests
- [ ] `dart run build_runner build` ran clean
- [ ] `dart run drift_dev schema dump lib/src/data/app_database.dart drift_schemas/` produced new snapshot
- [ ] `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/` produced tests
- [ ] `flutter test test/generated_migrations/` all PASS
- [ ] CI runs both dump + generate + test as a gate

## Hardening
- [ ] ProGuard/R8 keep rules present for `drift.**` (per `ios-android-hardening`)
- [ ] Drift queries use `transaction(...)` for multi-step atomic writes
- [ ] JSON columns use `JsonColumnConverter` (no raw String storage)
- [ ] DateTime values are UTC throughout the domain layer

## Migration testing on real device
- [ ] Install OLD version with seeded data
- [ ] Upgrade to NEW version (don't uninstall)
- [ ] Verify data preserved + new schema in place
- [ ] No `no such column` / FK violations in logcat
