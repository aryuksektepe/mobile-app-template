---
name: supabase-rls-client-contract
description: Every client DB write path must have a matching, integration-tested RLS/RPC path. Use when adding Supabase reads/writes, RLS policies, column-guard triggers, or when a migration says an RPC is "not yet built". Includes the SECURITY DEFINER own-row upsert pattern.
triggers: [supabase write, RLS policy, column guard, security definer, rpc, could not find the column, violates row-level security, profile upsert, onboarding write, 42501, PGRST204, db reset foreign key]
platforms: [ios, android]
last_verified: 2026-05-16
flutter_min: "3.19.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# Supabase RLS ↔ Client Contract — no write path without a tested server path

## What this skill does

- Names the **anti-pattern** where a client writes a table directly while the schema/RLS makes that write impossible — and explains why mocked tests never catch it.
- Gives the **correct pattern**: a server-authoritative `SECURITY DEFINER` RPC that writes the caller's own row, whitelists fields, and bypasses the column-guard trigger by design.
- Encodes the **process rule**: a migration that adds a server-side restriction MUST deliver the compensating client RPC in the SAME phase, with a non-mocked integration test.

## What this skill does NOT do

- Not a general Supabase auth/session skill (token storage → `secure-storage-tokens`).
- Not RLS policy design from scratch — it covers the client↔server contract, not every MASVS control (that is `security-reviewer`).

## The anti-pattern (ships broken, invisibly)

Client code writes a table directly:

```dart
await supabase.from('profiles').upsert({
  'id': userId,
  'display_name': name,
  'onboarding_complete': true,
});
```

It fails in production for one of two reasons that **static + mocked tests
cannot see**:

- **(a) Column not in schema** → `PGRST204 Could not find the 'onboarding_complete' column`. The client and the migration disagree; nobody ran a real write.
- **(b) RLS / column-guard blocks the write** → `42501 new row violates row-level security policy` or a `BEFORE UPDATE` column-guard trigger raises because the row is written by role `authenticated`.

Mocked datasource tests stub `supabase.from(...)` and assert the Dart code
"works", so they are green while the real path is dead. This is exactly the
class the `backend-integration` CI job + Iron-Rule-#8 non-mocked test exist to
expose.

## The correct pattern: server-authoritative own-row RPC

Instead of the client writing the table, it calls a `SECURITY DEFINER`
function that:

- writes only the caller's own row (`id = auth.uid()`), so a hijacked client
  cannot touch other users;
- whitelists the columns it accepts (ignores anything else the client sends);
- runs as the function **owner**, so it is intentionally outside the
  `WHEN CURRENT_USER = 'authenticated'` column-guard trigger — the guard
  protects against direct client writes, the RPC is the sanctioned path;
- is `GRANT EXECUTE`-d to `authenticated` only; `anon` / `public` REVOKEd;
- returns the updated row as `jsonb` so the client refreshes state in one
  round-trip.

Client call:

```dart
final updated = await supabase.rpc('upsert_own_profile', params: {
  'p_display_name': name,
  'p_onboarding_complete': true,
});
```

Ready-to-paste SQL → [snippets/own_row_upsert.sql](snippets/own_row_upsert.sql)
(partial `COALESCE` upsert + `jsonb` return + grants).

## The process rule (this is enforced, not advisory)

A migration that adds a SERVER-SIDE restriction (new RLS policy, BEFORE-UPDATE
column-guard trigger, `REVOKE`, tightened RLS) that makes an existing or
intended client data path impossible MUST, **in the same phase**:

1. Add an owned BLOCKER task in the phase file's `## Open Questions / Blockers`
   naming the exact broken client path and the compensating RPC/Edge function.
2. Ship the RPC (or Edge function) — not a `-- TODO: RPC not yet built` comment.
3. Have a NON-MOCKED integration test (run against `supabase start`) proving
   the client path works end-to-end.

An unowned "RPC ileride yapılacak / TODO" note is a process violation
(CLAUDE.md §13). `db-migration` Iron Rule #10 and `security-reviewer` Iron
Rule #8 both BLOCK on this — neither may PASS a phase that leaves the loop open.

## Operational pitfall: `supabase db reset` vs a live device session

`supabase db reset` drops and recreates the DB **including `auth.users`**. A
device/emulator that still holds the old session (JWT) now has an `auth.uid()`
pointing at a user row that no longer exists. The next write fails with
`23503 insert or update ... violates foreign key constraint` (e.g.
`profiles.id → auth.users.id`), which looks like an app bug but is a
test-environment artifact.

Fix:
- After `supabase db reset`, clear app data on the test device:
  `adb shell pm clear <applicationId>` (Android) / reinstall (iOS), so the app
  forces a fresh sign-in; OR
- While a live session must be preserved, use `supabase migration up` instead
  of `db reset` (applies new migrations without nuking `auth.users`).

## Code patterns

| Need | File |
|---|---|
| `SECURITY DEFINER` own-row upsert RPC + grants | [snippets/own_row_upsert.sql](snippets/own_row_upsert.sql) |
| Client repository calling the RPC | [snippets/profile_repository_rpc.dart](snippets/profile_repository_rpc.dart) |
| Non-mocked integration test (real local Supabase) | [snippets/profile_rpc_integration_test.dart](snippets/profile_rpc_integration_test.dart) |

Full setup (column-guard trigger interaction, RLS policy pairing, db reset
playbook) → [implementation.md](implementation.md).

## Known pitfalls

→ [pitfalls.md](pitfalls.md). Top 3:
1. Direct `from().upsert()` against a column-guard/RLS-protected table — use the RPC.
2. `SECURITY DEFINER` without `set search_path = ''` — schema-hijack risk; always pin it.
3. `db reset` with a live device session → FK 23503; clear app data or use `migration up`.

## Verification

→ [checklist.md](checklist.md) (RPC exists, grants correct, RLS pairs, non-mocked test green, no unowned RPC TODO).

## Skill metadata
- Validation status: **pre-seeded** (written from a real post-mortem; adapt, don't apply blind)
- Last verified: 2026-05-16
