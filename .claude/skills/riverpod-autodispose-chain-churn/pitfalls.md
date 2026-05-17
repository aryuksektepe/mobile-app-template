# Pitfalls — autoDispose chain churn

## P1 — riverpod_generator defaults to autoDispose
`@riverpod` (lowercase) is autoDispose. Session/stream providers need
`@Riverpod(keepAlive: true)`. Forgetting this is the #1 cause.

## P2 — Fixing one node, not the chain
Making `currentUser` keepAlive but leaving `authRepo` autoDispose still churns
through the dependency. Audit the whole graph.

## P3 — keepAlive provider `ref.watch`-ing an autoDispose provider
Back-door churn. The keepAlive node rebuilds whenever the autoDispose one is
recreated. Use `ref.read` for one-shot or promote the dependency.

## P4 — "Tests pass"
Single-read container never disposes/recreates. Only a rebuilding widget tree
(or the storm regression test) shows it. Confirm for real at INTEGRATION_SMOKE
via the HTTP access log (no repeated identical request burst).

## P5 — Over-correcting: everything keepAlive
Per-screen ephemeral state should stay autoDispose or you leak memory across
navigation. Keep the scalpel narrow: session + cross-screen streams only.

---

### Findings log
- 2026-05-16 — pre-seeded from ADR-022/025/026 (~30 req/s storm + flicker).
