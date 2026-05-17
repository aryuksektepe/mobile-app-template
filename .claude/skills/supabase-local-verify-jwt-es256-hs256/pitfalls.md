# Pitfalls — local verify_jwt / LOCAL-STACK-RUNBOOK

## P1 — Hand-rolled jose with a hardcoded alg
`jwtVerify(token, secret, { algorithms: ['HS256'] })` breaks the moment the
project issues ES256 (new Supabase default). Delegate to `auth.getUser()`.

## P2 — Assuming local == prod alg
Local GoTrue and prod can differ. Pin both to the same scheme or you get
"works in prod, 401 locally" (and the pipeline never tested local → shipped).

## P3 — Functions never called against a real stack
The root pipeline gap. Unit-testing functions with fake JWTs proves nothing.
db-migration Stage 5.5 + INTEGRATION_SMOKE require a real authenticated call.

## P4 — CORS preflight after the auth check
`OPTIONS` hitting the auth check returns 401; the browser/app then reports
"unauthorized" for a CORS problem. Answer `OPTIONS` first.

## P5 — `supabase db reset` + live device session → 23503
Recreated `auth.users`; stale JWT → FK violation. Clear app data or
`migration up`. (See `supabase-rls-client-contract`.)

## P6 — Realtime "works" but emits nothing locally
Table not in `supabase_realtime` publication. `alter publication
supabase_realtime add table public.<t>;`

---

### Findings log
- 2026-05-16 — pre-seeded from ADR-031 (all authenticated Edge fns 401 local).
