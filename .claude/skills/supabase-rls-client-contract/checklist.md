# Verification Checklist — Supabase RLS ↔ Client Contract

Run before a backend-touching phase can pass `db-migration` /
`security-reviewer` / `INTEGRATION_SMOKE`.

## Server
- [ ] Every client write path broken by this phase's restriction has a sanctioned RPC/Edge function
- [ ] RPC is `security definer` AND `set search_path = ''` (pinned)
- [ ] RPC writes only `auth.uid()`'s row; never trusts a client-supplied id
- [ ] RPC whitelists columns (ignores unexpected client fields)
- [ ] `revoke ... from public, anon;` + `grant execute ... to authenticated;`
- [ ] RLS enabled; read policy `using (id = auth.uid())`; no direct-write policy for `authenticated`
- [ ] RPC + restriction land in the SAME migration/phase (no deferral)

## Client
- [ ] No remaining direct `from('<guarded table>').insert/upsert/update` for the protected path
- [ ] Client calls the RPC; `PostgrestException` is surfaced, not swallowed

## Test (non-mocked, mandatory)
- [ ] Integration test runs against `supabase start` (real Postgres + RLS + triggers)
- [ ] Uses a real signed-in session (exercises `auth.uid()`)
- [ ] Asserts the RPC happy path writes the caller row
- [ ] Asserts the direct table write is correctly BLOCKED
- [ ] NOT tagged `mocked` (so `backend-integration` CI runs it) — and that job is green

## Process
- [ ] No `-- TODO: RPC not yet built` left anywhere without an owned BLOCKER task
- [ ] If anything above is unmet → verdict is BLOCK (no PASS-WITH-NOTES for an open contract loop)

## Operational
- [ ] db-reset playbook noted for testers (clear app data, or `migration up` with live session)
