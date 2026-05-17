# Pitfalls — disposed-flag latch

## P1 — `ref.onDispose` fires per rebuild, not just on final teardown
Under provider reuse the same Notifier instance can see `onDispose` callbacks
across rebuild cycles. A `_disposed = true` there is stale almost immediately.

## P2 — Reading a lifecycle flag inside `build()`
`build()` must be pure. Branching on `_disposed` makes the state a function of
disposal timing → nondeterministic loop. Derive from a dependency instead.

## P3 — "It passes in tests"
Single `container.read` never reproduces it. Only repeated rebuild/dispose
cycles (real app, or the rebuild-storm test) expose it.

## P4 — Replacing the flag with `mounted` *inside build()*
`ref.mounted` is for post-await guards, not for branching `build()`. Don't swap
one latch for another — remove the branch entirely.

---

### Findings log
- 2026-05-16 — pre-seeded from ADR-024 (onboarding infinite loop). Not yet
  re-validated in a fresh project.
