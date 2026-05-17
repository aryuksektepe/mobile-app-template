# Implementation — server-side aggregation writer

## 1. Detect the gap
Client inserts events; UI reads a summary. Grep:
```bash
grep -rn "progress_events\|_events\|insert(" lib/ supabase/migrations/
```
If there is an events table + a summary read but NO trigger / RPC / cron that
writes the summary → this bug.

## 2. Add the writer in the SAME migration
- Default: `AFTER INSERT` trigger on the events table that upserts the
  summary row for the affected user, in-transaction (see snippet).
- If the event needs validation/derivation first → a `SECURITY DEFINER` RPC
  the client calls instead of a raw insert (pair with
  `supabase-rls-client-contract`).
- Heavy/batch metrics → `pg_cron`; the UI needs a "computing…" state.
- Set RLS so the summary is readable by its owner only; the trigger runs as
  definer so it can write the summary the client cannot write directly.

## 3. Prove it (non-mocked, mandatory)
`supabase start`; as a real authenticated user, insert N events; assert the
summary row reflects them (totals/streak). A mocked repo returning a fake
summary does NOT satisfy this — it is exactly what hid ADR-028.

## 4. Route
db-migration Stage 5.5 (real-stack apply + evidence). test-writer Iron Rule
#8. An events table whose aggregation is "TODO" → db-migration / security
verdict BLOCK (unowned deferral, CLAUDE.md §13). Proven at INTEGRATION_SMOKE.
