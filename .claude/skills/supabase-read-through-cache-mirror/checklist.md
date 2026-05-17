# Verification Checklist — read-through cache mirror

- [ ] Every mirror-backed read has: local fast path → remote on miss → mirror backfill
- [ ] Offline + empty mirror returns a `Failure`, not `Success([])`
- [ ] Non-mocked integration test: EMPTY mirror → method returns server rows
- [ ] Same test asserts the mirror was backfilled (2nd call served local)
- [ ] No fake repo standing in for the read-through (or call site marked `// CONTRACT-UNTESTED` + deferred to INTEGRATION_SMOKE)
- [ ] INTEGRATION_SMOKE: fresh-install run shows real content, not an empty state
- [ ] Realtime/refresh keeps the mirror current
