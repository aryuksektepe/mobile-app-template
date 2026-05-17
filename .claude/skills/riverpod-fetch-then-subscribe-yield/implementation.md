# Implementation — fetch-then-subscribe yield

## 1. Detect
```bash
grep -rn "async\*" lib/ -A6 | grep -nE "await .*(fetch|get|load).*;"
```
Flag any `async*` body where an `await repo.x()` result is assigned to a
variable that is never `yield`ed (or awaited as a bare statement before a
`yield*`).

## 2. Fix
- `yield await repo.fetchX();` then `yield* repo.watchX();`.
- If the watch stream already replays the latest row, drop the explicit fetch
  and document that the SDK contract provides the initial event.
- Never leave an `await` whose result is discarded inside an `async*` provider.

## 3. Yield-contract test (mandatory — test-writer Iron Rule #9)
Assert the emission ORDER: first event == fetched snapshot, subsequent events
== realtime updates. A test that only asserts "emits something" does not test
this contract. See `snippets/yield_contract_test.dart`. Also exercise the real
path at INTEGRATION_SMOKE (UI shows data on first frame, not after a manual
refresh).

## 4. Route
code-reviewer auto-HIGH (`async*` with awaited-but-not-yielded result) →
bug-hunter. Fix in IN_PROGRESS; contract test by test-writer; real-data render
proven at INTEGRATION_SMOKE.
