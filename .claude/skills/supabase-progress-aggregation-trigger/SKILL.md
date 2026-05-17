---
name: supabase-progress-aggregation-trigger
description: The client writes raw event rows (progress_events) but nothing on the server aggregates them into the summary the UI reads, so totals/streaks stay zero. Use when a feature appends events client-side and expects a derived rollup (progress, streaks, counts, leaderboards).
triggers: [progress_events, aggregation, rollup, streak zero, totals not updating, server-side writer, postgres trigger, aggregate RPC, derived summary, event sourcing supabase]
platforms: [ios, android]
last_verified: 2026-05-16
flutter_min: "3.19.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: [supabase-rls-client-contract]
---

# Supabase — progress/event aggregation writer

## What this skill does

Fixes ADR-028: the client inserts into an append-only `progress_events` table
and the UI reads a `progress_summary` (totals, streaks). Nobody ever wrote the
aggregation — no trigger, no RPC, no scheduled job — so the summary is
permanently empty. The events accumulate; nothing rolls them up.

## Why it ships green

The repository is mocked to return a fake non-zero summary. The DB-side
aggregation (or its absence) is never exercised by any test. "Write event"
unit tests pass; the rollup that makes the feature work was never built or
run.

## The decision: where does aggregation run?

| Option | When | Note |
|---|---|---|
| `AFTER INSERT` trigger on `progress_events` → upsert `progress_summary` | most cases | atomic, no client trust, instant |
| `SECURITY DEFINER` RPC the client calls instead of raw insert | when the event itself needs validation/derivation | pairs with `supabase-rls-client-contract` |
| Scheduled `pg_cron` rollup | heavy/batch metrics, leaderboards | eventual; UI needs a "computing…" state |

Default: an `AFTER INSERT` trigger that updates the summary in the same
transaction. Ship it in the SAME migration/phase as the events table — an
events table without its writer is an unowned TODO (CLAUDE.md §13).

## The rule

If the client writes events expecting a derived value, the server-side writer
(trigger/RPC/job) MUST exist and be proven by a NON-MOCKED integration test:
insert events against real local Supabase → assert the summary updated. No
"aggregation later" note without an owned BLOCKER task.

## Code patterns
| Need | File |
|---|---|
| AFTER INSERT aggregation trigger | [snippets/aggregate_trigger.sql](snippets/aggregate_trigger.sql) |
| Non-mocked aggregation integration test | [snippets/aggregation_integration_test.dart](snippets/aggregation_integration_test.dart) |

## Known pitfalls
→ [pitfalls.md](pitfalls.md)

## Verification
→ [checklist.md](checklist.md)

## Skill metadata
- Validation status: **pre-seeded** (ADR-028)
- Last verified: 2026-05-16
