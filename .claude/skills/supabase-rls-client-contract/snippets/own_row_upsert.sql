-- Server-authoritative own-row upsert.
--
-- Why this exists: the `profiles` table is protected by RLS + a BEFORE UPDATE
-- column-guard trigger that rejects writes made directly by role
-- `authenticated`. The client therefore CANNOT `from('profiles').upsert(...)`.
-- This SECURITY DEFINER function is the sanctioned write path: it runs as the
-- function owner (outside the guard's `WHEN CURRENT_USER = 'authenticated'`),
-- writes ONLY the caller's own row, and whitelists the columns it accepts.
--
-- Ship this in the SAME migration/phase that introduces the restriction.
-- Never leave it as a "-- TODO: RPC not yet built" comment (CLAUDE.md §13).

create or replace function public.upsert_own_profile(
  p_display_name        text default null,
  p_avatar_url          text default null,
  p_onboarding_complete boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''            -- pin: prevents search_path hijack on SECURITY DEFINER
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.profiles;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  insert into public.profiles as p (id, display_name, avatar_url, onboarding_complete)
  values (
    v_uid,
    p_display_name,
    p_avatar_url,
    coalesce(p_onboarding_complete, false)
  )
  on conflict (id) do update set
    -- partial update: only overwrite a column when the caller sent a value
    display_name        = coalesce(excluded.display_name,        p.display_name),
    avatar_url          = coalesce(excluded.avatar_url,          p.avatar_url),
    onboarding_complete = coalesce(p_onboarding_complete,        p.onboarding_complete),
    updated_at          = now()
  returning p.* into v_row;

  return to_jsonb(v_row);
end;
$$;

-- Only signed-in users may call it. Never anon/public.
revoke all     on function public.upsert_own_profile(text, text, boolean) from public, anon;
grant  execute on function public.upsert_own_profile(text, text, boolean) to authenticated;

-- RLS pairing reminder (in the same migration):
--   alter table public.profiles enable row level security;
--   create policy "own row read"  on public.profiles for select
--     using (id = auth.uid());
-- Direct INSERT/UPDATE policies are intentionally ABSENT for `authenticated`
-- so the only write path is this RPC. The column-guard trigger stays as
-- defence-in-depth against accidental direct writes.
