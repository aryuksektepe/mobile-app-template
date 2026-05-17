// Edge Function auth that matches whatever scheme the project uses (ES256 or
// HS256) — by delegating to supabase-js instead of hand-rolling jose with a
// hardcoded alg. This is what prevents the ADR-031 "all fns 401 locally".
import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
};

Deno.serve(async (req) => {
  // Answer preflight BEFORE the auth check (else local CORS → 401).
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response('unauthorized', { status: 401, headers: cors });
  }

  const sb = createClient(
    Deno.env.get('SUPABASE_URL')!,        // in-network URL inside the function
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );

  // getUser() verifies with the project's actual signing scheme — no
  // assumption about ES256 vs HS256, no hardcoded secret.
  const { data: { user }, error } = await sb.auth.getUser();
  if (error || !user) {
    return new Response(`unauthorized: ${error?.message ?? 'no user'}`,
      { status: 401, headers: cors });
  }

  return new Response(JSON.stringify({ ok: true, uid: user.id }),
    { headers: { ...cors, 'Content-Type': 'application/json' } });
});
