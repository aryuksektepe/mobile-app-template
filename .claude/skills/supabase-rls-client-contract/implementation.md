# Implementation — Supabase RLS ↔ Client Contract

## When this triggers

Any phase that: adds a Supabase read/write, adds/changes an RLS policy, adds a
`BEFORE INSERT/UPDATE` column-guard trigger, `REVOKE`s a grant, or contains a
migration with a "RPC not yet built / TODO" note.

## Step 1 — Identify every client write path the change breaks

For the migration's restriction, list the exact client call sites it kills
(`from('<table>').insert/upsert/update`). Each one needs a sanctioned server
path or it ships dead.

## Step 2 — Write the compensating RPC in the SAME migration

Use `snippets/own_row_upsert.sql` as the template. Required properties:

- `security definer` + `set search_path = ''` (pin — unpinned SECURITY DEFINER
  is a privilege-escalation vector).
- Writes only `auth.uid()`'s row. Never trust a client-supplied id.
- Whitelists columns; ignores anything else.
- `revoke ... from public, anon;` then `grant execute ... to authenticated;`.
- Returns the row as `jsonb` so the client refreshes in one round-trip.

Pair it with the RLS policies in the same migration (read policy `using (id =
auth.uid())`; intentionally NO direct write policy for `authenticated` — the
RPC is the only write path; the column-guard trigger stays as
defence-in-depth).

## Step 3 — Switch the client to the RPC

Replace `from('table').upsert(...)` with `rpc('fn', params: {...})` (see
`snippets/profile_repository_rpc.dart`). Do NOT catch-and-swallow
`PostgrestException` — surfacing it is what makes the integration test
meaningful.

## Step 4 — Non-mocked integration test (mandatory, same phase)

Add `snippets/profile_rpc_integration_test.dart` to `integration_test/`. It
must run against `supabase start` (real Postgres + RLS + triggers), exercise a
real signed-in session, AND assert the direct table write is correctly
blocked. Do NOT tag it `mocked` — the `backend-integration` CI job runs
`flutter test integration_test/ --exclude-tags=mocked`.

This satisfies `test-writer` Iron Rule #8 and closes the loop required by
`db-migration` Iron Rule #10 / `security-reviewer` Iron Rule #8.

## Step 5 — db reset playbook (test environment)

`supabase db reset` recreates `auth.users`. Any device/emulator holding the
old JWT now references a deleted user → `23503` FK violation on the next write
(looks like an app bug, is not).

- CI: ephemeral DB, no stale session — safe.
- Local device testing: after `db reset`, `adb shell pm clear <applicationId>`
  (Android) or reinstall (iOS) to force fresh sign-in.
- If you must keep a live session: `supabase migration up` instead of
  `db reset` (applies new migrations without nuking `auth.users`).

## Step 6 — Verdict gate

If the RPC is missing, unowned, or has no non-mocked test:
`db-migration` → BLOCK, `security-reviewer` → BLOCK. There is no
PASS-WITH-NOTES for an open client↔server contract loop.
