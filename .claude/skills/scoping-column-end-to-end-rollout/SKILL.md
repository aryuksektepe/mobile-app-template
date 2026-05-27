---
name: scoping-column-end-to-end-rollout
description: How to add a new scoping/tenant FK column (well_id, tenant_id, org_id, workspace_id, family_id, household_id) to an existing event-driven Flutter+Supabase+Drift stack WITHOUT silent NULL writes, silent DTO drops, or saturated derived-VIEW aggregates. Use whenever a phase introduces a parent/scope column on a child table that already has event/progress data flowing through it.
triggers:
  - scoping column
  - tenant column
  - well_id
  - tenant_id
  - org_id
  - workspace_id
  - household_id
  - family_id
  - multi-tenant migration
  - add fk column
  - parent scoping
  - add scoping fk
  - retrofit scoping
  - rollout column
  - derived view aggregate
  - mastery view
  - aggregate view modules_total
platforms: [ios, android]
last_verified: 2026-05-26
flutter_min: "3.27.0"
extracted_from_phase: phase-28-multi-well-foundation
recurrence_count: 1
validation_status: battle-tested   # Phase-28 produced 7 distinct bug findings across CR + SEC; every layer in the checklist below was discovered by paying for it. Use VERBATIM in next project.
# depends_on intentionally empty — companion skills (drift-watermark-sync-pattern,
# supabase-server-artifact-must-be-applied-migration) not present in this template yet.
# The 8-layer checklist below is self-contained; meta-layer 9 (Operator-apply) is described inline.
depends_on: []
---

# Scoping Column End-to-End Rollout

Cross-cutting playbook for adding a new parent FK column (e.g. `well_id`, `tenant_id`, `org_id`) to an already-deployed event-driven schema. The column has to be carried through **8 layers** or you get silent data loss in production.

## The 8-layer checklist (BINDING — skip none)

A new scoping column **must** be wired through ALL of these. Skipping ANY layer produces a specific bug class (see pitfalls.md):

| # | Layer | What to do | Failure mode if skipped |
|---|---|---|---|
| 1 | **Supabase column migration** | `ALTER TABLE child ADD COLUMN scope_id TEXT REFERENCES parent(id)` + idempotent (`IF NOT EXISTS`) | Migration not re-runnable |
| 2 | **Backfill** | `UPDATE child SET scope_id = (SELECT … FROM parent) WHERE scope_id IS NULL` BEFORE constraint | NOT NULL constraint fails on historical rows |
| 3 | **Server-side trigger** | `BEFORE INSERT` trigger that derives `NEW.scope_id` from FK chain if NULL | Client forgets → silent NULL writes → derived aggregates drop new rows |
| 4 | **NOT NULL + CHECK** | `ALTER COLUMN scope_id SET NOT NULL` AFTER backfill + trigger | NULL re-appears via any insert path you forgot |
| 5 | **DTO `known` set** | Add `'scope_id'` to the DTO's `known` Set used by `fromJson`; map to `String? scopeId` field | DTO silently routes the column into the `extras` map → domain layer never sees it |
| 6 | **Domain entity** | Add `String? scopeId` (or non-null after stabilization) field to entity (freezed/dataclass) | DTO has it, domain doesn't → downstream features can't scope |
| 7 | **Mapper pass-through** | `Entity(scopeId: dto.scopeId)` in `DtoMapper` | Field decoded then dropped one line later |
| 8 | **Drift cache schema** | Add `scopeId` column to the Drift table, bump schema version, write migration in `MigrationStrategy.onUpgrade` (append-only — never edit shipped) | Cold-start crash or column-not-found at first read |

Plus a **9th meta-layer**: **Operator-apply**. Writing a migration ≠ applying it — every SQL/Edge artifact must be (a) saved under `supabase/migrations/`, (b) applied via `supabase db push` by an operator with the output captured in the phase file, and (c) proven by ≥1 real authenticated call returning 2xx. CI must NOT auto-apply DB migrations.

## Decision Tree

**Q1: Does the child table already have rows in production?**
- Yes → all 8 layers + backfill + trigger required.
- No → you can skip the backfill (layer 2) and you can put NOT NULL in the initial migration, but you STILL need layers 3–8.

**Q2: Is the scope derivable from an existing FK chain server-side?**
- Yes (e.g. `progress_events.exercise_id → exercises.lesson_id → lessons.unit_id → units.module_id → modules.scope_id`) → write the trigger (layer 3). Server is authoritative. Client doesn't need to send `scope_id`.
- No → you MUST add `scope_id` to every client write payload. Search `*Repository.insert(` / `*Repository.upsert(` / `*RemoteDataSource` for write paths. None must omit it.

**Q3: Will a derived VIEW (mastery, aggregate, leaderboard, completion %) read the new column?**
- Yes → see snippets/derived-view-from-canonical.sql. **Don't `FROM events` — `FROM canonical_table LEFT JOIN events`**. Otherwise the denominator saturates (1/1 = 100% instead of 1/24 = 4%).
- No → skip the VIEW snippet.

## What this skill does

- Catches **silent NULL writes** before they corrupt production data
- Catches **silent DTO drops** before the domain layer becomes scope-blind
- Catches **saturated VIEW aggregates** before they show users `100% mastery` when they have `4%`
- Catches **migration-written-but-not-applied** drift between Git and live DB
- Gives a test pattern for Riverpod family providers that depend on `currentUserProvider`

## What this skill does NOT do

- Doesn't pick the column name (architect decides per PRD)
- Doesn't decide whether the column is NULLABLE or NOT NULL (depends on Q2 — see Decision Tree)
- Doesn't help with row-level security policies (see your auth skill — but VIEWs need `WITH (security_invoker = on)` so base-table RLS applies)
- Doesn't extract to sealed-union domain variants — adding a column to a sealed `Exercise`-style union is a separate architect decision (see Phase-28 BUG-28-04 deferred note)

## Quick start

```bash
# Per the 8-layer checklist:
# 1-4: write ONE Supabase migration covering ADD COLUMN + backfill + trigger + NOT NULL
#      (or two migrations: column+backfill, then trigger+NOT NULL)
# 5-7: edit DTO known set + entity + mapper in same commit (atomic — never split)
# 8:   bump Drift schema version + onUpgrade migration block
# Then: supabase db push (operator action, NOT coder) + verify with ≥1 real INSERT
```

## Step-by-step

See [implementation.md](implementation.md).

## Code

Paste-ready snippets in [snippets/](snippets/):
- `server-side-derive-trigger.sql` — BEFORE INSERT trigger pattern
- `derived-view-from-canonical.sql` — correct VIEW pattern (no saturation)
- `dto-known-set-pattern.dart` — DTO with `known` Set + extras map
- `family-provider-test-overrides.dart` — Riverpod family override correct signature + currentUserProvider chain

## Known pitfalls

7 distinct bugs paid for in Phase-28 → [pitfalls.md](pitfalls.md).

## Verification

After implementing, before declaring done:

1. `grep -r '<scope_id>' lib/` — should hit DTO + entity + mapper + Drift table (≥4 files).
2. Run **one real insert** through the app (e.g. one new progress event) → query the DB: `SELECT scope_id FROM <child> ORDER BY created_at DESC LIMIT 5` → must be non-NULL.
3. If you wrote a derived VIEW: insert 1 child row, query the VIEW — `denominator` must equal the canonical-table count, not the event-table count.
4. `flutter analyze lib/ test/ integration_test/` — 0 errors (Drift codegen + freezed regen done).
5. **Operator apply gate**: `supabase db push` run by operator, output captured in phase file. CI should NOT auto-deploy DB migrations without human verification on production.

## Skill metadata

- Extracted from: phase-28 (Multi-Well Foundation)
- Bug count this skill prevents: 7 (4 from code-review, 3 from security-review)
- Last verified: 2026-05-26
- Flutter min: 3.27.0
- Pairs with (when added to this template): `drift-schema-migrations`, `supabase-rls-client-contract`, `supabase-progress-aggregation-trigger`, `freezed-json-serializable`
