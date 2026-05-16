# Pitfalls — Supabase RLS ↔ Client Contract

From the post-mortem that motivated this skill. Append findings after each use.

## P1 — Client writes a column the schema doesn't have
`from('profiles').upsert({'onboarding_complete': true})` →
`PGRST204 Could not find the 'onboarding_complete' column`. The client and the
migration disagreed; no real write ever ran in the pipeline (all tests mocked).
Fix: schema + RPC + non-mocked test in the same phase.

## P2 — Column-guard trigger blocks the authenticated client write
A `BEFORE UPDATE ... WHEN (current_user = 'authenticated')` trigger rejects the
direct client write with `42501`. The "fix" of loosening the trigger would
defeat its purpose. Correct fix: a `SECURITY DEFINER` RPC that runs as owner
(outside the guard) and writes only the caller's own row.

## P3 — Unowned "RPC TODO" in a migration
A migration shipped with `-- TODO: SECURITY DEFINER RPC not yet built` and no
tracked task. The restriction landed; the compensating path never did; the
client write was dead on arrival. This is a CLAUDE.md §13 process violation —
`db-migration` Iron Rule #10 + `security-reviewer` Iron Rule #8 now BLOCK on it.

## P4 — `SECURITY DEFINER` without pinned `search_path`
`security definer` without `set search_path = ''` lets a caller shadow
unqualified objects → privilege escalation. Always pin and schema-qualify
(`public.profiles`).

## P5 — `supabase db reset` with a live device session → FK 23503
Reset recreates `auth.users`; the device's stale JWT points at a deleted user;
next write → `23503 violates foreign key constraint`. Misread as an app bug for
hours. Fix: clear app data after reset, or `supabase migration up` instead.

## P6 — Mocked datasource test gave false confidence
A mocked `profiles` datasource test was green and counted toward ~54% line
coverage while the real RLS path was completely broken. Line coverage from
mocked tests ≠ integration coverage. A backend path is untested until a
non-mocked test exercises it once.

---

### Findings log
- 2026-05-16 — pre-seeded from post-mortem (missing column + RLS/column-guard
  block + unowned RPC TODO + db reset FK). Not yet validated in a fresh project.
