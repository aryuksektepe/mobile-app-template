# Pitfalls — go_router + StatefulShell deep links

## P1 — Provider mutation inside `redirect`
`ref.read(x.notifier).state = …` / `ref.invalidate` in redirect → red screen
on cold deep-link/push launch (modified provider during build). redirect is
pure; side-effects elsewhere.

## P2 — Bare `context.go()` doesn't switch the branch
With `StatefulShellRoute.indexedStack`, a path not under the target branch
leaves the shell on the old tab. Route under the branch or `goBranch(i)`.

## P3 — Only testing warm navigation
Cold start (deep link as initialLocation) is a different code path and the one
that crashes (ADR-033). Test BOTH.

## P4 — Async auth in redirect
If `authState` is still loading, returning a real path can bounce or crash.
Return `null` (stay) while loading; let the listener re-trigger redirect when
it resolves.

## P5 — One-time deep-link token consumed in redirect
Consuming/clearing the link in redirect is a side-effect → P1. Consume in a
post-frame callback or root listener after navigation settles.

---

### Findings log
- 2026-05-16 — pre-seeded from ADR-033 (cold redirect crash) + ADR-034
  (StatefulShell branch not driven).
