# Pitfalls — fetch-then-subscribe yield

## P1 — `await` result discarded in `async*`
`final x = await fetch();` with no `yield x;` compiles, analyzes clean, and
ships an empty screen. The analyzer does not flag an unused awaited value here.

## P2 — Assuming `watch` replays the latest
Some realtime SDKs DO emit the current row on subscribe; many do NOT. Don't
guess — if you skip the explicit fetch, assert the SDK's initial-event
contract in a test.

## P3 — "Stream emits" test passes
A test that only checks the stream emits something will pass with the bug.
Assert emission ORDER (snapshot then update).

## P4 — Broken realtime hides as "no data"
If realtime is misconfigured and the snapshot is dropped, the screen is empty
forever and looks like "no content yet" rather than a bug. Always render the
snapshot so a realtime outage degrades gracefully.

---

### Findings log
- 2026-05-16 — pre-seeded from ADR-029 (fetch dropped + broken realtime).
