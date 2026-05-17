---
name: gorouter-statefulshell-deeplink
description: go_router + StatefulShellRoute deep-link/push cold-start crashes (provider mutated inside redirect) and warm-start fails to switch the shell branch. Use when wiring deep links / push-tap routing with a bottom-nav StatefulShellRoute, or seeing red-screen Riverpod errors on cold deep-link launch.
triggers: [go_router redirect crash, StatefulShellRoute deeplink, cold start deeplink, push tap routing, modified provider during build, branch not switching, initialLocation deeplink, redirect provider mutation, deeplink tab]
platforms: [ios, android]
last_verified: 2026-05-16
flutter_min: "3.19.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
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

## The two rules

1. **`redirect` is a pure function of router state.** No `ref.read(...)
   .notifier`, no `state =`, no `ref.invalidate` inside `redirect` (or
   `build`/`initState`/`dispose`). Read state; decide a path; return it.
   Side-effects go in event handlers / `addPostFrameCallback` / a listener.
2. **Drive the shell branch explicitly.** For a deep link into a tab, navigate
   so the `StatefulShellRoute` switches branches —
   `StatefulNavigationShell.goBranch(index)` or a route under the right branch
   — not a bare `context.go(path)` that the shell ignores.

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
| Cold + warm deep-link integration test | [snippets/deeplink_integration_test.dart](snippets/deeplink_integration_test.dart) |

## Known pitfalls
→ [pitfalls.md](pitfalls.md)

## Verification
→ [checklist.md](checklist.md)

## Skill metadata
- Validation status: **pre-seeded** (ADR-033/034)
- Last verified: 2026-05-16
