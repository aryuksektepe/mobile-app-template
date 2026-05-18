# Implementation — go_router + StatefulShell deep links

## 1. Make redirect pure
Grep:
```bash
grep -rn "redirect:" lib/src/core/router/ -A12 | \
  grep -nE "\.notifier|state =|ref.invalidate|ref.read\("
```
Any provider mutation inside `redirect` is the ADR-033 crash. Move it out:
- `redirect` only reads state and returns a path (or null).
- Side-effects → an event handler, a `ref.listen` at app root, or
  `WidgetsBinding.instance.addPostFrameCallback`.

## 2. Branch-aware deep links (the reliable way)
For a deep link targeting a tab inside `StatefulShellRoute.indexedStack`,
a redirect/ancestor `GoRouter.go` to the branch location does NOT switch the
`IndexedStack` (P6). The reliable path:
- Capture the `StatefulNavigationShell` from `StatefulShellRoute.builder` into a
  **process-global holder** (`ShellBranchController`, NOT a provider — reading
  it is never "ref during build").
- Switch with the SAME call the nav-bar makes:
  `shell.goBranch(idx, initialLocation: idx == shell.currentIndex)` (P7).
- A push/cold-start handler only **parks** the target in a Riverpod slot; a
  `_DeepLinkNavigator` mounted in `MaterialApp.router`'s `builder:` (outside
  redirect, outside the shell) consumes it.
- Cold start: the shell may not be mounted yet → re-arm via post-frame,
  **bounded**; when the cap is hit, clear the slot unconditionally (P8).
- `ref.listen` guard is `next != null`, never `next != previous` (P9).
See [snippets/shell_branch_controller.dart](snippets/shell_branch_controller.dart).
A bare `context.go('/deeptab/x')` not under the branch leaves the shell on the
old tab (ADR-034 / P6).

## 3. Cold vs warm
- Cold: the deep link is `initialLocation`. Resolve auth/onboarding purely;
  return the target or the gate; defer writes to post-first-frame.
- Warm: navigate from the link handler (`go`/`goBranch`) — mutation OK here.

## 4. Prove it (INTEGRATION_SMOKE)
Integration tests for BOTH paths on a real emulator:
- cold: launch the app WITH the deep link as initial route (push + universal
  link), assert no red screen + correct screen + correct active tab.
- warm: app running, deliver the link, assert branch switches.
boot_smoke_test alone is not enough — add a deep-link cold-start case.

## 5. Route
code-reviewer auto-HIGH (provider mutation in redirect/build) → bug-hunter.
Deep-link cold + warm integration tests are test-writer targets; executed at
INTEGRATION_SMOKE (real push/universal-link cold start).
