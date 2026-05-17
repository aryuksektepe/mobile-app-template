# Verification Checklist — local verify_jwt / RUNBOOK

## JWT
- [ ] Decoded a REAL local access token; know its `alg`
- [ ] Function verifies via `supabase-js auth.getUser()` (no hardcoded alg/secret) OR JWKS/secret chosen to match GoTrue
- [ ] Same signing alg local and prod
- [ ] `config.toml` `[functions.<fn>] verify_jwt` matches the in-code expectation (no double/none)
- [ ] CORS `OPTIONS` answered before the auth check

## Proven (db-migration §5.5 / INTEGRATION_SMOKE)
- [ ] `supabase functions serve` + an authenticated 2xx call for EVERY new/changed function, evidence pasted
- [ ] `edge_auth_smoke.sh <fn>` passes for each function

## RUNBOOK env traps
- [ ] Post-`db reset` app-data-clear / `migration up` procedure documented for testers
- [ ] Realtime tables added to `supabase_realtime` publication
- [ ] Functions use in-network `SUPABASE_URL`/`SUPABASE_DB_URL`, not `localhost`
