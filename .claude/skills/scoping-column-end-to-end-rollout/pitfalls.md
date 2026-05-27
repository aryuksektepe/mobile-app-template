# Pitfalls — bugs paid for in production-grade rollout

Each entry: **diagnostic signature** (how it shows up) → **root cause** → **fix** → **prevent-next-time discipline**.

---

## P-1 — Client omits new scope column in INSERT payload → derived VIEW silently drops every new row

**Origin:** Phase-28 SEC-28-01 (BLOCKER).

**Diagnostic signature:**
- Migration added `scope_id TEXT` to event/progress table (nullable, no DEFAULT, no trigger).
- Backfill ran successfully; historical rows have `scope_id` populated.
- App keeps shipping events successfully (`progress_events.submit()` returns 200).
- Derived VIEW (`mastery`, `aggregate`, `completion_pct`) shows **stale** numbers — only historical data, no progress on top.
- `SELECT scope_id FROM child WHERE scope_id IS NULL` → all rows created after deploy day.

**Why it's a sleeper bug:**
- 1-tenant launch hides this entirely (no scope filter discriminates).
- Triggers in production only when second scope is added OR when a query starts filtering by `scope_id`.
- VIEW `WHERE scope_id IS NOT NULL` filter silently drops the NULL rows — no error, no log, no analytics signal.

**Root cause:**
- Client write paths (`*Repository.insert/upsert`, `RemoteDataSource.submit`) never set `scope_id`.
- DB column is nullable + has no `DEFAULT` + has no server-side derivation trigger.
- Result: every new row has `scope_id = NULL`.

**Fix (preferred — server authoritative):**
- Write a `BEFORE INSERT` trigger that derives `NEW.scope_id` from the FK chain.
- See `snippets/server-side-derive-trigger.sql`.
- Client doesn't need to change. Trigger is idempotent (skips if `NEW.scope_id` is already set).

**Fix (alternative — client authoritative):**
- Add `scope_id` to every write payload. Grep across `lib/` for `.insert(` / `.upsert(` calls touching the affected table.
- Risk: incomplete coverage of write paths leaves the bug.

**Prevent next time:**
- Layer 3 of the 8-layer checklist exists for exactly this reason.
- After ADD COLUMN, ALWAYS pair with either: (a) `DEFAULT <expr>`, (b) `BEFORE INSERT` trigger, or (c) backed-by-greppable `WHERE NOT NULL` coverage of every write path.
- Add a CHECK constraint as belt-and-suspenders: `ALTER TABLE child ADD CONSTRAINT scope_id_not_null CHECK (scope_id IS NOT NULL)` — fails fast at write time instead of silently dropping at read time.

---

## P-2 — Derived VIEW `denominator` computed from events table, not canonical table → saturation to 100%

**Origin:** Phase-28 BUG-28-03 / CR-28-02 (MAJOR).

**Diagnostic signature:**
- User completes 1 of 24 lessons correctly → `mastery_pct = 1.0` instead of `0.04`.
- VIEW SQL starts with `FROM progress_events` (or any event/log table).
- `modules_total` (or equivalent denominator) is computed as `COUNT(DISTINCT module_id)` from the event table.

**Why it's wrong:**
- `FROM events` only knows about modules the user has TOUCHED.
- A user who has touched 3 and mastered 3 has `denominator = 3`, `numerator = 3`, `pct = 1.0`.
- The denominator should be **modules-in-the-scope**, not **modules-user-attempted**.

**Fix:**
- Always `FROM canonical_table LEFT JOIN events`.
- See `snippets/derived-view-from-canonical.sql`.
- Use `COUNT(*) FILTER (WHERE event.result = 'pass')` for numerator, plain `COUNT(*)` of canonical for denominator.
- Always guard against zero-divide: `CASE WHEN denominator = 0 THEN 0.0 ELSE numerator::numeric / denominator END`.

**Prevent next time:**
- When writing a derived VIEW for "pct of X completed", ask: **what populates the denominator?** If the answer is "the event log", you have the bug. The denominator should be the canonical-content table OR a stable enumeration, not user activity.

---

## P-3 — DTO `known` set missing the new column → field silently routes to `extras` map → domain layer is scope-blind

**Origin:** Phase-28 BUG-28-02 / CR-28-01 (MAJOR).

**Diagnostic signature:**
- DB column exists. Remote datasource SELECT explicitly includes `scope_id`. DTO compiles fine.
- But `entity.scopeId` is always `null` after decode.
- DTO has a `known` Set and an `extras` Map — pattern used to roundtrip unknown columns.
- The new `scope_id` was added to SELECT but NOT to the `known` set → so `fromJson` puts it in `extras` and skips assignment to the typed field.

**Root cause:**
- DTO fromJson pattern:
  ```dart
  const known = {'id', 'title', 'created_at'};  // <-- 'scope_id' missing here
  final extras = <String, dynamic>{};
  for (final entry in json.entries) {
    if (!known.contains(entry.key)) extras[entry.key] = entry.value;
  }
  return Dto(id: json['id'], scopeId: json['scope_id'], extras: extras);
  ```
- If `'scope_id'` isn't in `known`, the column data is still readable via `json['scope_id']` (so `scopeId:` assignment can work), BUT the issue is the **inverse**: when serializing, `toJson` likely omits anything not in `known`, so the column is dropped on write.
- Real bug shape from Phase-28: DTO didn't even declare the `scopeId` field. It existed only in `extras`. Anyone reading `dto.scopeId` got a compile error or got the field from extras as `dynamic`.

**Fix:**
- Add `'scope_id'` to the `known` set.
- Declare `final String? scopeId;` on the DTO.
- Assign in `fromJson`: `scopeId: json['scope_id'] as String?`.
- Include in `toJson`: `if (scopeId != null) 'scope_id': scopeId`.

**Prevent next time:**
- When adding a DB column, search the codebase for the table's DTO file. Check 3 things: (a) field declaration on the class, (b) `known` set entry, (c) `fromJson` + `toJson` wiring.
- Code review checklist: "every new DB column appears in DTO `known` set + entity field + mapper". Grep proof: `grep -c "<new_column>" lib/.../dto/` should be ≥3.

---

## P-4 — Adding column at DB level isn't enough: domain entity also needs the field, or the scope evaporates between DTO and feature code

**Origin:** Phase-28 BUG-28-04 / CR-28-01 amplification (MAJOR).

**Diagnostic signature:**
- DB column ✓, DTO field ✓, but `Entity.scopeId` doesn't exist.
- Feature code that needs to filter by scope can't, because the domain object lost the field at the mapping boundary.
- Mapper looks like: `Entity(id: dto.id, title: dto.title)` — `scopeId:` simply not passed.

**Root cause:**
- DTO and entity are separate types. Adding to DTO doesn't propagate to entity automatically (unlike codegen sources from a single schema).
- Mapper in `data/mappers/` drops the field.

**Fix:**
- Add `String? scopeId` to the entity (freezed/dataclass).
- Run `dart run build_runner build --delete-conflicting-outputs` for freezed.
- Wire mapper: `Entity(scopeId: dto.scopeId, …)`.

**Prevent next time:**
- The 8-layer checklist (SKILL.md) lists this. Treat DTO→Entity boundary as a known leak point.
- Watch out for **sealed unions**: adding a field to a sealed parent means adding it to every variant. If the entity is a sealed union (e.g. Exercise with 6 subtype variants), this is an architect-level decision — defer if necessary, BUT document the deferral and check whether downstream features actually need the field on every variant or only on the parent reference.

---

## P-5 — Integration test compile error: required-arg added to entity but test fixtures not updated

**Origin:** Phase-28 BUG-28-01 / CR-28-00 (BLOCKER).

**Diagnostic signature:**
- `flutter analyze integration_test/` errors with "The named parameter 'updatedAt' is required, but there's no corresponding argument."
- Production lib code analyzes clean.
- Tests file built before the entity required a new field.

**Root cause:**
- Entity changed from optional `updatedAt` to required `updatedAt` (or analogous field).
- Existing test fixtures didn't get updated.
- CI surfaces this if it runs `analyze` against `integration_test/`. Often missed locally because devs only analyze `lib/`.

**Fix:**
- Update test fixtures with stable values: `updatedAt: DateTime.utc(2026, 1, 1)` (deterministic — never `DateTime.now()` in fixtures).
- While you're there: clean unused imports (`flutter analyze` will flag them).

**Prevent next time:**
- Run `flutter analyze lib/ test/ integration_test/` (not just `lib/`) in CI and pre-commit.
- When making a field required, search test directories for the entity constructor: `grep -rn 'EntityName(' test/ integration_test/`. Update every fixture in the SAME commit.

---

## P-6 — Migration written but not applied → Git has the fix, live DB doesn't

**Origin:** Phase-28 SEC-28-02 (HIGH).

**Diagnostic signature:**
- `supabase/migrations/0027_fix.sql` exists in repo. Commit looks good.
- Live staging/prod DB still has the buggy VIEW or missing column.
- No CI step automates `supabase db push`.
- Coder closes the bug as "fixed" — but it's only fixed on disk, not in any environment.

**Root cause:**
- Coder writes migration. Apply step is operator action (intentional — DB changes shouldn't auto-deploy).
- Coder's hand-off doesn't make the apply step visible enough.

**Fix:**
- Run `supabase db push` against staging.
- Capture verification: `SELECT * FROM <view> WHERE <test_user_id>` — paste output into phase file.
- Mark the operator-apply checkbox done with timestamp + environment + verifier name.

**Prevent next time:**
- Phase file must have an explicit "Operator Action Required" block listing every migration + verification SELECT. Pre-release gate must check this block is fully checked.
- Never let a phase advance to USER_APPROVAL with pending operator actions on critical-path migrations.

---

## P-7 — NOT NULL constraint added BEFORE backfill → migration fails on historical rows

**Origin:** Phase-28 SEC-28-03 (LOW, latent).

**Diagnostic signature:**
- Migration `ALTER COLUMN scope_id SET NOT NULL` fails with: `column "scope_id" contains null values`.
- Migration partially applied (column added) but constraint failed, leaving DB in inconsistent state.

**Root cause:**
- Sequence in SQL matters. NOT NULL constraint can't be enforced while historical rows have NULL.

**Fix:**
- Always sequence:
  1. `ALTER TABLE child ADD COLUMN scope_id TEXT` (nullable, no constraint).
  2. `UPDATE child SET scope_id = (...) WHERE scope_id IS NULL`.
  3. Create trigger (so new INSERTs are safe going forward).
  4. `ALTER COLUMN scope_id SET NOT NULL`.
  5. Optionally `ADD CONSTRAINT ... CHECK (scope_id IS NOT NULL)`.
- Wrap in idempotency guards: `DO $$ BEGIN IF EXISTS (SELECT … attnotnull = false …) THEN ALTER COLUMN … SET NOT NULL; END IF; END $$`.

**Prevent next time:**
- This is in the implementation.md template — follow the exact 5-step ordering, don't reorder.

---

## P-8 (test pattern) — Riverpod family provider override signature: `(ref) =>` NOT `(ref, arg) =>`

**Origin:** Phase-28 test-writer fix round.

**Diagnostic signature:**
- Test compile error:
  ```
  The argument type 'Future<X> Function(Ref, dynamic)' can't be assigned to
  'FutureOr<X> Function(Ref)'.
  ```

**Root cause:**
- When you write `myFamilyProvider('arg-value').overrideWith(...)`, the family argument is **already bound** by selecting `('arg-value')`. The override callback only receives `ref`, not `(ref, arg)`.

**Fix:**
- Before:
  ```dart
  myFamilyProvider('arg-value').overrideWith((ref, arg) async => value)
  ```
- After:
  ```dart
  myFamilyProvider('arg-value').overrideWith((ref) async => value)
  // OR if you want generic:
  myFamilyProvider.overrideWith((ref) async => /* compute from ref.read(...) */)
  ```

---

## P-9 (test pattern) — Pending timer in widget tests when faking "loading forever"

**Origin:** Phase-28 test-writer fix round.

**Diagnostic signature:**
- Test fails with: `A Timer is still pending even after the widget tree was disposed.`
- The faked provider used `Future.delayed(Duration(seconds: 60), () => …)` to simulate "loading state".

**Root cause:**
- `Future.delayed` schedules a real timer that flutter_test's `FakeAsync` tracks. It outlives the test.

**Fix:**
- Use a `Completer<T>().future` that never completes:
  ```dart
  import 'dart:async';
  // ...
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wellsProvider.overrideWith((ref) => Completer<List<Well>>().future),
      ],
      child: const MaterialApp(home: MyScreen()),
    ),
  );
  await tester.pump();
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  ```
- The Completer holds the future open without scheduling any timer.

---

## P-10 (test pattern) — Provider that chains to `currentUserProvider` needs explicit override or test errors with "supabaseClient must be overridden"

**Origin:** Phase-28 test-writer fix round.

**Diagnostic signature:**
- Test fails with: `UnimplementedError: supabaseClientProvider must be overridden in bootstrap() / tests.`
- The provider under test reads `currentUserProvider` (which depends on `supabaseClientProvider`).

**Root cause:**
- `currentUserProvider` chains to Supabase auth state. Tests must short-circuit it.

**Fix:**
```dart
const _fakeUser = AuthUser(id: 'uid-test', email: 'test@example.com');

final container = ProviderContainer(
  overrides: [
    currentUserProvider.overrideWithValue(_fakeUser),
    // ...your other overrides
  ],
);
```

**Prevent next time:**
- When testing any provider that returns scoped data, check if its build function calls `ref.watch(currentUserProvider)` — if yes, override it explicitly. Don't try to mock supabaseClientProvider (that path is intentionally unimplemented in tests).
