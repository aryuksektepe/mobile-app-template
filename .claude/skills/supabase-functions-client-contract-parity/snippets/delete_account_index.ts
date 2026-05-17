// The contract source of truth. Method + body field names are explicit and
// the function REJECTS the wrong shape loudly (405/400) so a mismatch fails
// in tests/INTEGRATION_SMOKE, not silently in prod.
import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  // Method contract — explicit, returns 405 (caught by the parity test).
  if (req.method !== 'POST') {
    return new Response('method not allowed', { status: 405, headers: cors });
  }

  // Body contract — exact field name. Wrong key → 400 (caught by the test).
  const body = await req.json().catch(() => ({}));
  const otp_token = body?.otp_token;
  if (typeof otp_token !== 'string' || otp_token.length === 0) {
    return new Response('missing otp_token', { status: 400, headers: cors });
  }

  const sb = createClient(
    Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: req.headers.get('Authorization')! } } },
  );
  const { data: { user }, error } = await sb.auth.getUser();
  if (error || !user) {
    return new Response('unauthorized', { status: 401, headers: cors });
  }

  // … verify otp_token, delete account …
  return new Response(JSON.stringify({ ok: true }),
    { headers: { ...cors, 'Content-Type': 'application/json' } });
});
