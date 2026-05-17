# Verification Checklist — fetch-then-subscribe yield

- [ ] Every `async*` provider that awaits a fetch `yield`s that value (or documents why the watch stream supplies it)
- [ ] No `await repo.x()` result assigned-then-discarded inside an `async*` body
- [ ] Emission ORDER tested: first == fetched snapshot, then == realtime updates
- [ ] Test asserts order, not merely "emits something"
- [ ] INTEGRATION_SMOKE: screen shows data on first frame, not only after a manual refresh / first realtime event
- [ ] Realtime-outage degradation considered (snapshot still renders)
- [ ] code-reviewer flagged original as auto-HIGH (async* no-yield)
