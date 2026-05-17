-- AFTER INSERT aggregation: every progress_events row rolls up into
-- progress_summary in the same transaction. Ship in the SAME migration as
-- progress_events — an events table with no writer is an unowned TODO.

create table if not exists public.progress_summary (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  total_xp    bigint not null default 0,
  streak_days int    not null default 0,
  last_event  timestamptz,
  updated_at  timestamptz not null default now()
);

create or replace function public.agg_progress()
returns trigger
language plpgsql
security definer            -- writes a summary the client cannot write directly
set search_path = ''
as $$
begin
  insert into public.progress_summary as s (user_id, total_xp, last_event)
  values (new.user_id, coalesce(new.xp, 0), new.created_at)
  on conflict (user_id) do update set
    total_xp   = s.total_xp + coalesce(new.xp, 0),
    streak_days = case
      when new.created_at::date = s.last_event::date then s.streak_days
      when new.created_at::date = s.last_event::date + 1 then s.streak_days + 1
      else 1 end,
    last_event = new.created_at,
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_agg_progress on public.progress_events;
create trigger trg_agg_progress
  after insert on public.progress_events
  for each row execute function public.agg_progress();

-- RLS: owner reads own summary; no direct client write (trigger is the writer).
alter table public.progress_summary enable row level security;
create policy "own summary read" on public.progress_summary
  for select using (user_id = auth.uid());
