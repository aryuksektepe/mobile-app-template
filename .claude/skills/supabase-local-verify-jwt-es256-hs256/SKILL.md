---
name: supabase-local-verify-jwt-es256-hs256
description: On a local Supabase stack every authenticated Edge Function returns 401 because the gateway/verify_jwt expects a different JWT signing algorithm (ES256 vs HS256) than the tokens the local GoTrue issues. The LOCAL-STACK-RUNBOOK for JWT/verify_jwt/realtime env traps.
triggers: [edge function 401, verify_jwt, ES256 HS256, local supabase 401, JWT algorithm mismatch, functions serve 401, all authenticated functions fail locally, local stack runbook, realtime publication]
platforms: [ios, android]
last_verified: 2026-05-16
flutter_min: "3.19.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# Supabase local stack — verify_jwt ES256↔HS256 (LOCAL-STACK-RUNBOOK)

## What this skill does

Fixes ADR-031 and is the canonical **LOCAL-STACK-RUNBOOK**: on a local stack
EVERY authenticated Edge Function returns `401` because the function's
`verify_jwt` / gateway expects a JWT signed with a different algorithm than
the one the local GoTrue actually issues (ES256 vs legacy HS256), or the
function uses the wrong secret/JWKS. It looks like "auth is broken" but it is
a local-stack configuration trap — and because the pipeline never called Edge
functions against a real stack, it shipped.

## Why it ships green

Edge functions were unit-tested with hand-made fake JWTs or fully mocked. No
test ever signed in against local GoTrue and called a deployed function, so
the algorithm/secret mismatch was never exercised. (This is the gap
`INTEGRATION_SMOKE` + db-migration Stage 5.5 close.)

## Diagnosis (fast)

```bash
supabase status                       # note JWT secret + API URL
# Decode the header of a real local access token:
TOKEN=$(curl -s "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON" -H 'Content-Type: application/json' \
  -d '{"email":"u@e.com","password":"pw"}' | jq -r .access_token)
echo "$TOKEN" | cut -d. -f1 | base64 -d 2>/dev/null   # -> {"alg":"HS256",...} or ES256
curl -i "$SUPABASE_URL/functions/v1/<fn>" -H "Authorization: Bearer $TOKEN"
```

If the token `alg` ≠ what the function/gateway verifies → 401 on every
authenticated call.

## The fixes (pick per setup)

- Align the function to the local GoTrue alg. New Supabase issues asymmetric
  (ES256/JWKS); older/local may be HS256 with the shared `JWT_SECRET`. Make
  the function verify with the SAME scheme: use `supabase-js`
  `auth.getUser(token)` (delegates verification) instead of hand-rolled jose
  with a hardcoded alg.
- If verifying manually: fetch the JWKS from `${SUPABASE_URL}/auth/v1/.well-known/jwks.json`
  (asymmetric) OR use `Deno.env.get('SUPABASE_JWT_SECRET')` with `HS256`
  (symmetric) — never assume.
- `supabase/config.toml`: set `[auth] jwt_expiry` etc.; ensure
  `[functions.<fn>] verify_jwt` matches intent (true = gateway enforces).
- Keep local and prod on the SAME alg to avoid "works in prod, 401 local".

## LOCAL-STACK-RUNBOOK (other recurring env traps)

- **`supabase db reset` nukes `auth.users`** → a device holding the old JWT
  hits `23503` FK on next write. After reset: `adb shell pm clear <appId>` /
  reinstall, or use `supabase migration up` with a live session. (See
  `supabase-rls-client-contract`.)
- **Realtime shows nothing locally** → table not in the `supabase_realtime`
  publication: `alter publication supabase_realtime add table public.<t>;`
  and enable Realtime in `config.toml`.
- **Functions can't reach DB** → use the in-network `SUPABASE_DB_URL`
  /`SUPABASE_URL` env inside the function, not `localhost`.
- **CORS/OPTIONS 401** → preflight must be answered BEFORE the auth check in
  the function (return CORS headers on `OPTIONS` early).

## Code patterns
| Need | File |
|---|---|
| Edge fn auth that matches local GoTrue | [snippets/verify_auth.ts](snippets/verify_auth.ts) |
| Authenticated Edge smoke (curl) | [snippets/edge_auth_smoke.sh](snippets/edge_auth_smoke.sh) |

## Known pitfalls
→ [pitfalls.md](pitfalls.md)

## Verification
→ [checklist.md](checklist.md)

## Skill metadata
- Validation status: **pre-seeded** (ADR-031)
- Last verified: 2026-05-16
