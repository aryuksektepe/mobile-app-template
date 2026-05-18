---
name: gorouter-statefulshell-deeplink
description: Make a deep-link/push reliably switch a go_router StatefulShellRoute tab branch (and not crash on cold start). A redirect (or ancestor GoRouter.go) returning a branch location does NOT switch the IndexedStack — it snaps back to branch 0. Use a process-global shell holder + StatefulNavigationShell.goBranch(idx, initialLocation: idx==currentIndex), consume the link OUTSIDE the redirect (pure-redirect invariant), and a bounded shell-ready cold-start handshake. Use when wiring deep links / push-tap routing with a bottom-nav StatefulShellRoute, or seeing red-screen Riverpod errors on cold deep-link launch.
triggers: [go_router redirect crash, StatefulShellRoute deeplink, cold start deeplink, push tap routing, modified provider during build, branch not switching, initialLocation deeplink, redirect provider mutation, deeplink tab, goBranch, GoRouter.go does nothing in shell, deep link wrong tab, push lands on home, cold-start deep link lost, statefulnavigationshell]
platforms: [ios, android]
last_verified: 2026-05-18
flutter_min: "3.19.0"
extracted_from_phase: pre-seeded
recurrence_count: 1
validation_status: pre-seeded
depends_on: []
---

# go_router + StatefulShellRoute deep-link wiring

## What this skill does

Fixes ADR-033 and ADR-034:

- **ADR-033 (cold start):** the router `redirect` mutates a provider
  (`ref.read(x.notifier).state = …` / `ref.invalidate`) while resolving a
  deep-link/push route at launch → "modified a provider while building the
  widget tree" red screen on cold start.
- **ADR-034 (warm):** a deep link that goes through redirect-and-return does
  not drive the correct `StatefulShellRoute` branch, so the target tab never
  becomes active (you land on the wrong tab / a dead end).

## Why it ships green

Router tests `pump` a widget with a fixed initial route and never exercise a
real cold-start deep link or push-tap cold launch; tab switching only shows in
a running app. Mocked navigation hides both.

## The three rules

1. **`redirect` is a pure function of router state.** No `ref.read(...)
   .notifier`, no `state =`, no `ref.invalidate` inside `redirect` (or
   `build`/`initState`/`dispose`). Read state; decide a path; return it.
   Side-effects go in event handlers / `addPostFrameCallback` / a listener.
2. **Drive the shell branch explicitly via the SAME API the nav-bar uses.**
   A redirect (or an ancestor `GoRouter.go`) that *returns/goes to* a branch
   location does NOT switch the `IndexedStack` — `matchedLocation` updates but
   the shell stays on (or snaps back to) branch 0. The only reliable switch is
   a **process-global shell holder** (the `StatefulNavigationShell` captured in
   `StatefulShellRoute.builder`) + `navigationShell.goBranch(idx,
   initialLocation: idx == navigationShell.currentIndex)` — i.e. the exact call
   the bottom-nav taps make. Diagnostic: nav-bar tap switches tabs but the
   deep-link/push doesn't → it's this.
3. **Consume the link OUTSIDE `redirect`, with a bounded cold-start
   handshake.** A pending-link Riverpod slot is consumed by a `_DeepLinkNavigator`
   widget mounted *outside* the redirect (rule 1). On cold start the shell may
   not be mounted yet → re-arm via post-frame callback, **capped**. When the
   cap is exhausted the link MUST be consumed+cleared unconditionally (an
   un-cleared slot = permanent stuck on the next launch — pitfall P8).

## Cold vs warm

- **Cold (initialLocation):** the deep link IS the initial location.
  `redirect` must resolve auth/onboarding purely and return the deep target
  (or the gate). Defer any state write to after first frame.
- **Warm (in-context):** `context.go()` / `goBranch()` from a handler. State
  may be mutated here (it's an event, not a build).

## Code patterns
| Need | File |
|---|---|
| Pure redirect (no provider mutation) | [snippets/pure_redirect.dart](snippets/pure_redirect.dart) |
| StatefulShell branch-aware deep link | [snippets/shell_deeplink.dart](snippets/shell_deeplink.dart) |
| Process-global shell holder + goBranch + bounded handshake + `_DeepLinkNavigator` | [snippets/shell_branch_controller.dart](snippets/shell_branch_controller.dart) |
| Cold + warm deep-link integration test | [snippets/deeplink_integration_test.dart](snippets/deeplink_integration_test.dart) |

## Known pitfalls
→ [pitfalls.md](pitfalls.md)

## Verification
→ [checklist.md](checklist.md)

## Skill metadata
- Validation status: **pre-seeded** (ADR-033/034)
- Last verified: 2026-05-16
