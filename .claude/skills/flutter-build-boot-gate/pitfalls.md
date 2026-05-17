# Pitfalls — Flutter Build + Boot Gate

Real failure modes from the post-mortem that motivated this skill. Append new
findings after each use (date + project).

## P1 — Pumping `App()` instead of the real entrypoint
The boot abort lived in `bootstrap()` (a Riverpod scoped provider declared
without `dependencies:` → first-frame assertion). A test that pumped
`ProviderScope(child: App())` directly never ran `bootstrap()`, so it stayed
green while the shipped app locked on splash. **Always drive `main_dev.dart`'s
`main()`.**

## P2 — `pumpAndSettle` shorter than the splash
Splash auto-navigates after 1500ms. A `pumpAndSettle(Duration(seconds: 1))`
returns before navigation and asserts on the splash, masking a broken first
route. Use ≥10s AND assert a concrete known first-screen widget — "no exception"
alone is too weak.

## P3 — `tester.takeException()` misses framework errors
`takeException()` only surfaces synchronous exceptions thrown by the pumped
widget. Boot aborts often arrive as `FlutterError`s during settle. Capture via
`FlutterError.onError` (see snippet) and assert the collected list is empty.

## P4 — Build-only CI gives false confidence
`flutter build apk` passing proves it compiles, NOT that it boots. The Riverpod
scoped-provider class is invisible to compile. CI must run the emulator boot
test, not just the build.

## P5 — Static green ≠ verified
`flutter analyze` clean + mocked tests passing + ~54% line coverage shipped six
launch-blockers. None of those gates built or booted the app. Never treat
static green as a substitute for this gate. This is the meta-lesson the whole
`INTEGRATION_SMOKE` state encodes.

## P6 — Forgetting to record evidence
Even when the gate ran, not writing the build-log-tail + boot PASS into the
phase's `## Integration Smoke` means the orchestrator can't confirm it and
will (correctly) refuse to advance. Recording is part of the gate, not
optional.

---

### Findings log
- 2026-05-16 — pre-seeded from post-mortem (Android desugaring + Kotlin
  languageVersion + MainActivity rename + missing notification drawable +
  Riverpod scoped-provider boot abort). Not yet validated in a fresh project.
