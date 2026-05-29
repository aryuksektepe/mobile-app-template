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

## P7 — iOS 18.4+ / iOS 26+ physical device: DEBUG build cold-start crashes
Apple tightened `mprotect()`; Dart JIT can't allocate executable pages without
a debugger attached. `flutter run -d <iphone>` builds OK but hangs at
"Installing and launching..." or installs and white-screens on Home-screen tap
(ProMotion devices crash on `VSyncClient`). **`flutter run` debug + iOS 18.4+
physical = not a runtime smoke** — that's an Apple-side runtime restriction,
not a Flutter bug we can fix.

For the runtime gate on iOS 18.4+ physical: build RELEASE and install via
`xcrun devicectl`, then open from Home screen. Full runbook:
[`ios-26-debug-release-only-physical`](../ios-26-debug-release-only-physical/SKILL.md).
This pitfall trumps the "any flavor debug build" wording in implementation.md
when the target device is iOS 18.4+ physical — substitute release.

(Android is unaffected; iOS Simulator + debug also unaffected.)

## P8 — SPM auto-integration (Flutter 3.44 default ON) breaks FlutterFire pod build
After upgrading to Flutter 3.44, iOS build fails with duplicate symbols /
linker errors mentioning FirebaseCore or grpc. The cause is Swift Package
Manager auto-integration now ON by default, conflicting with the CocoaPods
flow FlutterFire still uses.
FIX: `flutter config --no-enable-swift-package-manager` → `flutter clean` →
`cd ios && rm -rf Pods Podfile.lock && pod install`. Document the flag in
the project's bootstrap docs so it doesn't regress.

---

### Findings log
- 2026-05-16 — pre-seeded from post-mortem (Android desugaring + Kotlin
  languageVersion + MainActivity rename + missing notification drawable +
  Riverpod scoped-provider boot abort). Not yet validated in a fresh project.
- 2026-05-27 — added P7 (iOS 26 mprotect/JIT release-only) + P8 (SPM
  auto-integration FlutterFire conflict). Source: a production v1.2.0 release run.
