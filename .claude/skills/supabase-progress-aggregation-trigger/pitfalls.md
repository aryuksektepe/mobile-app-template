# Pitfalls — progress/event aggregation

## P1 — Events table without a writer
The whole bug: client appends events, nothing aggregates. Ship the
trigger/RPC/cron in the SAME migration as the events table.

## P2 — Mocked summary hides it
A repo mocked to return a non-zero summary makes the feature look done.
Only a non-mocked insert→assert-summary test against real Supabase catches it.

## P3 — Client-side aggregation
Computing totals on the client is unverifiable and tamperable, and breaks
across devices. Aggregate server-side.

## P4 — Trigger not `security definer` / search_path unpinned
The trigger writes a summary the client cannot write directly — it needs
definer rights, and `set search_path = ''` to avoid hijack.

## P5 — "Aggregation later" left as a TODO
Unowned deferral = CLAUDE.md §13 violation. db-migration / security-reviewer
verdict is BLOCK, not PASS-WITH-NOTES.

---

### Findings log
- 2026-05-16 — pre-seeded from ADR-028 (progress_events never aggregated).
