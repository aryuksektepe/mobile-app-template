# Implementation — fix local Edge 401 (JWT alg)

## 1. Confirm it's the alg/secret, not a real auth bug
Decode a REAL local access token header (see SKILL Diagnosis). Note `alg`.
Call the function with that token. 401 + alg-mismatch in function logs → this.

## 2. Make the function verify the way GoTrue signs
Prefer delegation over hand-rolled crypto:
```ts
import { createClient } from 'jsr:@supabase/supabase-js@2';
const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
  global: { headers: { Authorization: req.headers.get('Authorization')! } },
});
const { data: { user }, error } = await sb.auth.getUser();
if (error || !user) return new Response('unauthorized', { status: 401 });
```
`auth.getUser()` verifies with whatever scheme the project uses — no hardcoded
`HS256`/`ES256`.

## 3. Align config + parity prod↔local
- `supabase/config.toml`: `[functions.<fn>] verify_jwt = true` (gateway) or
  verify in-code consistently. Don't mix.
- Same signing alg locally and in prod.

## 4. Prove it (db-migration Stage 5.5)
`supabase start && supabase functions serve`; sign in against local GoTrue;
call EACH new/changed function with the real token; assert 2xx; paste into the
phase `## Integration Smoke`. A 401/405 here is a phase finding, not a launch
surprise.

## 5. Apply the rest of the LOCAL-STACK-RUNBOOK
db reset / realtime publication / function→DB networking / CORS preflight (see
SKILL). These recur together; check them as a set when standing up the stack.
