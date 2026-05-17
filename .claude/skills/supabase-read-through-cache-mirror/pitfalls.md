# Pitfalls — read-through cache mirror

## P1 — Miss returns `[]` instead of going remote
The whole bug. Empty mirror on fresh install → "nothing here yet" while the
server is full. Always fall through on miss.

## P2 — Fake repo fakes the fallthrough
Unit/widget tests stub the method to return seeded data, so the missing
remote path is invisible. Only a non-mocked test against real Supabase with an
EMPTY mirror catches it.

## P3 — Not backfilling the mirror
Going remote on every miss without writing the mirror means every read is a
network call (perf + offline regression). Backfill so the next read is local.

## P4 — Swallowing offline as empty
Offline + empty mirror returning `Success([])` looks like "no content".
Return a real `Failure` so the UI can show a retry, not a misleading empty
state.

---

### Findings log
- 2026-05-16 — pre-seeded from ADR-027 (listLessonsForUnit no read-through).
