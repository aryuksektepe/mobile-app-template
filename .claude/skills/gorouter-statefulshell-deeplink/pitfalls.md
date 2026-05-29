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

## P6 — `redirect`/ancestor `GoRouter.go` to a branch location ≠ branch switch
Returning `/league` from redirect, or calling `GoRouter.go('/league')` from an
ancestor, updates `matchedLocation` but the `IndexedStack` stays on (or snaps
back to) branch 0 — you land on Home. Only `navigationShell.goBranch(idx, …)`
via the process-global shell holder switches it. **Diagnostic:** nav-bar tap
switches tabs but the deep-link/push doesn't → it is exactly this.

## P7 — `goBranch(idx)` without `initialLocation: idx == currentIndex`
A bare `goBranch(idx)` doesn't match nav-bar tap semantics: re-tapping the
current tab won't reset it to root, and edge cases mis-restore branch state.
Always pass `initialLocation: idx == navigationShell.currentIndex`.

## P8 — Bounded cold-start handshake dies silently → permanent stuck
The shell isn't mounted at cold start, so the navigator re-arms via post-frame.
If the retry cap is exhausted and the pending-link slot is NOT cleared, the
poisoned slot replays on every future launch (app stuck on a dead link). When
the cap is hit, consume+clear the slot **unconditionally**.

## P9 — Riverpod `!identical` notify vs value-`!=` listen guard mismatch
A notifier that fires on every new string object (`!identical`) paired with a
listener guarded by `next != previous` (value-equality): `'/x' != '/x'` is
`false`, so a re-delivered identical link is swallowed (poisoned slot — the 2nd
tap on the same link is a no-op). Guard on `if (next != null)`; leave
idempotency to the notifier's own `clear()`.

## P10 — Cold-start deep link can't be reproduced in the simulator
`app_links`' `AppLinksIosPlugin.register(with:)` is wrapped in `#if DEBUG`
(workaround for Flutter #149214). `getInitialLink()` only fires in a session
launched by `flutter run`; `simctl openurl` cold start and real FCM/Universal-
Link cold start do NOT trigger it. Don't burn hours repro'ing in the sim —
verify cold-start custom-scheme links in a real-build phase (INTEGRATION_SMOKE).
Confirm the pinned version from `pubspec.lock` (don't assume). See also
`deeplinks-go-router` pitfalls (custom-scheme `-10814`, dual-Router black screen).

---

### Generalized bug catalog (deep-link campaign — solve in minutes next time)
| # | Symptom | Root cause | Canonical fix | Fast diagnosis |
|---|---|---|---|---|
| 1 | Push/deep-link targets a tab but Home opens | redirect/ancestor `GoRouter.go` doesn't switch the StatefulShell branch | process-global shell holder + `goBranch(idx, initialLocation: idx==currentIndex)`, consume outside redirect | nav-bar tap works but deep-link doesn't → certainly this |
| 4 | Cold-start deep link lost / lands on Home | premature provider clear + `initialLocation` doesn't select the branch | shell-ready handshake + single consume point (P5/P8) | only reproduces on cold start |
| 5 | 2nd tap on same link no-ops / cold-start infinitely stuck | bounded retry cap dies silently (P8) + `!identical` vs value-`!=` guard (P9) | unconditional consume+clear on cap; `listen` guard `next != null` | warm 2nd tap no-op = poisoned slot |

### Findings log
- 2026-05-16 — pre-seeded from ADR-033 (cold redirect crash) + ADR-034
  (StatefulShell branch not driven).
- 2026-05-18 — enriched from a real production run (6-round deep-link/
  push bug-loop): added P6–P10 + generalized bug catalog + process-global shell
  holder / bounded-handshake / guard-mismatch snippet. recurrence_count → 1.
