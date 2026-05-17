---
name: riverpod-2x-disposed-flag-guard
description: Riverpod 2.x Notifier reuse + a manual `bool _disposed` / `ref.onDispose` latch causes an infinite rebuild loop (e.g. onboarding never completes). Use when a Notifier guards rebuilds with a disposed flag, or a screen loops/freezes after a state change.
triggers: [riverpod disposed flag, _disposed latch, ref.onDispose rebuild, notifier reuse, onboarding infinite loop, rebuild loop, LateInitializationError notifier, provider never settles]
platforms: [ios, android]
last_verified: 2026-05-16
flutter_min: "3.19.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# Riverpod 2.x — the `_disposed` flag latch trap

## What this skill does

Explains and fixes the ADR-024 class: a `Notifier`/`AsyncNotifier` that keeps a
manual `bool _disposed` set from `ref.onDispose`, then reads it to "guard"
`build()`/state writes. Under Riverpod 2.x provider reuse, `onDispose` fires per
rebuild while the same Notifier instance is reused → the flag flips mid-cycle →
the guard re-triggers a rebuild → infinite loop (onboarding never advances,
splash never releases).

## Why it ships green

Unit tests build a `ProviderContainer` once and read the provider once. The
loop needs *repeated* rebuild/dispose cycles on a live element — which only
happens in a running app. Single-build test → invisible.

## The anti-pattern

```dart
class OnboardingController extends Notifier<OnboardingState> {
  bool _disposed = false;
  @override
  OnboardingState build() {
    ref.onDispose(() => _disposed = true);   // fires every rebuild
    if (_disposed) return const OnboardingState.done(); // self-retrigger
    ...
  }
  void next() {
    if (_disposed) return;          // stale guard
    state = state.copyWith(...);    // may run post-dispose → loop
  }
}
```

## The fix

- Do NOT track disposal with a manual flag. Use `ref.mounted` (Riverpod ≥2.5)
  for "is this still alive" checks after awaits.
- Never read a disposal flag inside `build()` to branch state — `build()` must
  be a pure function of its dependencies.
- For "run once" semantics use a dependency/arg or `ref.listenSelf`, not a
  lifecycle flag.
- If you truly need post-await safety: `await x; if (!ref.mounted) return;`.

See [implementation.md](implementation.md) for the corrected Notifier and a
regression test that drives repeated rebuilds.

## Code patterns

| Need | File |
|---|---|
| Corrected Notifier (no flag latch) | [snippets/controller_fixed.dart](snippets/controller_fixed.dart) |
| Rebuild-storm regression test | [snippets/rebuild_loop_test.dart](snippets/rebuild_loop_test.dart) |

## Known pitfalls

→ [pitfalls.md](pitfalls.md).

## Verification

→ [checklist.md](checklist.md).

## Skill metadata
- Validation status: **pre-seeded** (from ADR-024 post-mortem)
- Last verified: 2026-05-16
