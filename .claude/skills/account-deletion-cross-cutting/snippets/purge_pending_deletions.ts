// Supabase Edge Function — daily hard-purge of soft-deleted accounts.
// Schedule via Supabase Cron (cron extension): `0 3 * * *` (3 AM UTC daily).
//
// Apple/Play want "actually deleted" — the 30-day window aligns with KVKK/GDPR
// reasonable-delay-for-backups norm. Adjust window if your legal told you otherwise.
//
// Deploy:
//   supabase functions deploy purge_pending_deletions --no-verify-jwt
// Schedule (run once from psql / SQL editor):
//   select cron.schedule(
//     'purge_pending_deletions',
//     '0 3 * * *',
//     $$ select net.http_post(
//          url:='https://<project>.functions.supabase.co/purge_pending_deletions',
//          headers:='{"Authorization":"Bearer <service_role_key>"}'::jsonb
//        ) $$
//   );

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';

const SOFT_DELETE_WINDOW_DAYS = 30; // KVKK/GDPR-friendly; align with privacy policy

serve(async (req) => {
  // Only callable with the service role key (set in cron Authorization header above).
  const auth = req.headers.get('authorization');
  if (auth !== `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`) {
    return new Response('unauthorized', { status: 401 });
  }

  const supa = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const cutoff = new Date(Date.now() - SOFT_DELETE_WINDOW_DAYS * 86_400_000).toISOString();

  // 1. Find expired soft-deletes
  const { data: targets, error: q1 } = await supa
    .from('users')
    .select('id')
    .eq('status', 'pending_delete')
    .lt('deleted_at', cutoff);
  if (q1) return new Response(`query failed: ${q1.message}`, { status: 500 });
  if (!targets || targets.length === 0) {
    return new Response(JSON.stringify({ purged: 0 }), { status: 200 });
  }

  const ids = targets.map((t) => t.id);

  // 2. Hard-delete cascading rows (order matters — FKs)
  //    Each app has its own table set; adjust to match your schema.
  for (const table of [
    'progress_events',
    'user_settings',
    'fcm_tokens',
    'subscriptions_mirror',
    'profile_avatars',
    // ... add all user-FK'd tables here ...
  ]) {
    const { error } = await supa.from(table).delete().in('user_id', ids);
    if (error) {
      console.error(`purge: ${table} failed`, error);
      // Continue — partial purge still progresses. Re-run will finish residue.
    }
  }

  // 3. Finally, delete the users row itself
  const { error: dErr } = await supa.from('users').delete().in('id', ids);
  if (dErr) return new Response(`final delete failed: ${dErr.message}`, { status: 500 });

  // 4. Also call Firebase Admin to delete the auth user (if Firebase Auth used)
  //    — separate from Supabase. Requires Firebase service account JSON in env.
  //    Use firebase-admin REST: POST https://identitytoolkit.googleapis.com/v1/accounts:delete

  return new Response(JSON.stringify({ purged: ids.length, userIds: ids }), {
    status: 200,
    headers: { 'content-type': 'application/json' },
  });
});
