# Implementation — Step-by-Step

Concrete order of operations for rolling out a new scoping/tenant FK column. Follow VERBATIM. Each step has a verification gate before moving on.

> **Vocabulary used below:**
> - `child` = the table that gets the new column (e.g. `progress_events`, `posts`, `assets`).
> - `parent` = the table the column references (e.g. `modules`, `wells`, `tenants`, `orgs`).
> - `scope_id` = the new column name. Replace with the real name (`well_id`, `tenant_id`, etc.).

---

## Step 1 — Supabase: ADD COLUMN (idempotent, nullable initially)

`supabase/migrations/NNNN_add_scope_id_to_<child>.sql`:

```sql
-- Layer 1 of the 8-layer scoping-column rollout
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = '<child>' AND column_name = 'scope_id'
  ) THEN
    ALTER TABLE <child> ADD COLUMN scope_id TEXT REFERENCES <parent>(id);
    CREATE INDEX IF NOT EXISTS idx_<child>_scope_id ON <child>(scope_id);
  END IF;
END $$;
```

Gate: re-runnable. Apply twice → no error.

---

## Step 2 — Supabase: BACKFILL

Continuing same migration (or a new file — depends on volume):

```sql
-- Layer 2: backfill historical rows by deriving from existing FK chain
UPDATE <child> c
SET scope_id = (
  SELECT p.id
  FROM <parent> p
  -- ...JOIN chain that links c → p; e.g. for progress_events:
  --   JOIN modules m ON m.id = c.module_id  → p = wells, m.well_id = p.id
)
WHERE c.scope_id IS NULL;
```

Gate: `SELECT COUNT(*) FROM <child> WHERE scope_id IS NULL` → 0.

---

## Step 3 — Supabase: BEFORE INSERT trigger (server-authoritative derivation)

`supabase/migrations/NNNN_<child>_scope_id_trigger.sql`:

```sql
-- Layer 3: server-side derivation so client doesn't need to send scope_id
CREATE OR REPLACE FUNCTION derive_scope_id_on_<child>()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.scope_id IS NULL THEN
    NEW.scope_id := (
      SELECT p.id
      FROM <parent> p
      -- ...JOIN chain
      WHERE -- ...predicate that links NEW.* to p
    );
    IF NEW.scope_id IS NULL THEN
      RAISE EXCEPTION 'Cannot derive scope_id for <child>: row %', NEW.id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_<child>_derive_scope_id ON <child>;
CREATE TRIGGER trg_<child>_derive_scope_id
  BEFORE INSERT ON <child>
  FOR EACH ROW EXECUTE FUNCTION derive_scope_id_on_<child>();
```

Gate: insert ONE row through the client (with `scope_id` absent from payload) → `SELECT scope_id FROM <child> ORDER BY created_at DESC LIMIT 1` → non-NULL, correct value.

---

## Step 4 — Supabase: NOT NULL + CHECK

Same migration as Step 3 (after the trigger is created):

```sql
-- Layer 4: enforce. Order matters: trigger first, THEN constraint.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = '<child>' AND column_name = 'scope_id' AND is_nullable = 'YES'
  ) THEN
    -- One last sweep for any stragglers (race with concurrent writes):
    UPDATE <child> c SET scope_id = (...JOIN chain...) WHERE scope_id IS NULL;
    ALTER TABLE <child> ALTER COLUMN scope_id SET NOT NULL;
  END IF;
END $$;
```

Gate: a deliberate `INSERT` that bypasses the trigger (`SET session_replication_role = replica` in psql) and omits `scope_id` → must fail with `null value in column "scope_id"` error.

---

## Step 5 — Dart: DTO field + `known` set + JSON wiring

For each `*Dto` that maps from the affected table:

```dart
// lib/.../data/dtos/child_dto.dart
class ChildDto {
  final String id;
  final String? scopeId;   // <-- NEW
  // ...other fields
  final Map<String, dynamic> extras;

  static const _known = <String>{
    'id', 'scope_id', /* <-- NEW */ /* …other known cols */
  };

  factory ChildDto.fromJson(Map<String, dynamic> json) {
    final extras = <String, dynamic>{};
    for (final entry in json.entries) {
      if (!_known.contains(entry.key)) extras[entry.key] = entry.value;
    }
    return ChildDto(
      id: json['id'] as String,
      scopeId: json['scope_id'] as String?,   // <-- NEW
      // ...other fields
      extras: extras,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (scopeId != null) 'scope_id': scopeId,   // <-- NEW
    // ...other fields
    ...extras,
  };
}
```

Gate: `grep -c "'scope_id'" lib/.../data/dtos/` → ≥1 per DTO file affected.

---

## Step 6 — Dart: Domain entity gets `scopeId` field

Freezed:

```dart
@freezed
class Child with _$Child {
  const factory Child({
    required String id,
    String? scopeId,   // <-- NEW
    // ...other fields
  }) = _Child;
}
```

Then: `dart run build_runner build --delete-conflicting-outputs`.

Gate: `grep -c 'scopeId' lib/.../domain/entities/` → ≥1.

---

## Step 7 — Dart: Mapper pass-through

```dart
// lib/.../data/mappers/child_mappers.dart
extension ChildDtoX on ChildDto {
  Child toDomain() => Child(
    id: id,
    scopeId: scopeId,   // <-- NEW (silent drop happens here if forgotten)
    // ...other fields
  );
}
```

Gate: end-to-end: write a row through the client → read it back via the repository → assert `entity.scopeId != null`.

---

## Step 8 — Dart: Drift cache table + schema migration

```dart
// lib/.../core/database/tables/child_table.dart
class ChildTable extends Table {
  TextColumn get id => text()();
  TextColumn get scopeId => text().nullable()();   // <-- NEW
  // ...other columns
}
```

Bump schema version:

```dart
// lib/.../core/database/app_database.dart
@override
int get schemaVersion => 7;   // was 6, +1 for this rollout

@override
MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (m, from, to) async {
    if (from < 7) {
      // APPEND-ONLY — never edit shipped migrations
      await m.addColumn(childTable, childTable.scopeId);
    }
  },
);
```

Also update the local datasource's upsert + row-to-DTO mapping:

```dart
await into(childTable).insert(
  ChildTableCompanion.insert(
    id: dto.id,
    scopeId: Value(dto.scopeId),   // <-- NEW
    // ...
  ),
  mode: InsertMode.insertOrReplace,
);
```

Gate: cold-start install on a fresh DB + cold-start install on the OLD schema and watch the migration run → no exception, no data loss.

---

## Step 9 — Operator apply

This is NOT a coder action. Coder hands off:

```markdown
## Open Questions / Blockers

### OPERATOR ACTION REQUIRED — Migration Apply
- [ ] `supabase db push` to apply 0027 + 0028 to staging
- [ ] Run verification SELECT (see Step 3 gate) and paste output
- [ ] After verify: tick this checkbox, signal pipeline to advance
```

The release-manager / human operator runs the command and verifies. Pre-release gate must check this is done.

---

## Step 10 — Derived VIEW (only if applicable)

If a derived VIEW reads the new column, use the `FROM canonical LEFT JOIN events` pattern.

See `snippets/derived-view-from-canonical.sql`. Make this its own migration (e.g. `NNNN_<view_name>_fix.sql`) so it's append-only.

Common gotcha — the WRONG shape:

```sql
-- ❌ WRONG: denominator saturates because we only see attempted rows
CREATE VIEW mastery AS
SELECT
  user_id,
  scope_id,
  COUNT(DISTINCT child_id) AS total,   -- BUG: counts only attempted
  COUNT(DISTINCT child_id) FILTER (WHERE result = 'pass') AS mastered
FROM events
GROUP BY user_id, scope_id;
```

The RIGHT shape:

```sql
-- ✅ RIGHT: denominator from canonical, numerator filtered from events
CREATE VIEW mastery AS
SELECT
  u.user_id,
  c.scope_id,
  COUNT(DISTINCT c.id) AS total,
  COUNT(DISTINCT e.child_id) FILTER (WHERE e.result = 'pass') AS mastered,
  CASE
    WHEN COUNT(DISTINCT c.id) = 0 THEN 0.0
    ELSE COUNT(DISTINCT e.child_id) FILTER (WHERE e.result = 'pass')::numeric
       / COUNT(DISTINCT c.id)
  END AS pct
FROM canonical_table c
LEFT JOIN events e ON e.child_id = c.id AND e.user_id = u.user_id
CROSS JOIN (SELECT DISTINCT user_id FROM events) u
GROUP BY u.user_id, c.scope_id;
```

Add `WITH (security_invoker = on)` if you want base-table RLS to apply to the VIEW.

Gate: insert 1 child + insert 1 passing event → query the VIEW for that user → `total = COUNT(*) FROM canonical WHERE scope_id = ...`, not 1.

---

## Verification matrix (run before declaring done)

```bash
# 1. Code wired through all 4 Dart layers
grep -rn 'scope_id\|scopeId' lib/.../data/dtos/ lib/.../domain/entities/ lib/.../data/mappers/ lib/.../core/database/
# Expect ≥4 distinct files

# 2. Tests cover new field
flutter test test/unit/.../child_test.dart

# 3. Static analysis green
flutter analyze lib/ test/ integration_test/

# 4. Drift migration tested
flutter test test/unit/.../database/migration_test.dart

# 5. Integration test: write a row, read it back, scope_id non-null
flutter test integration_test/scope_id_rollout_test.dart

# 6. Operator: applied to staging + ≥1 real-call verified (NOT coder action)
```

Don't sign off until the operator-apply gate is closed.
