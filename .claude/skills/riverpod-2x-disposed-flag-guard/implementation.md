# Implementation — kill the `_disposed` latch

## 1. Detect

Grep the diff:

```bash
grep -rn "bool _disposed\|_disposed = true\|if (_disposed)" lib/
```

Any `Notifier`/`AsyncNotifier` that (a) sets a bool in `ref.onDispose` AND
(b) reads it in `build()` or before `state =` is the bug.

## 2. Rewrite

- Remove the `bool _disposed` field and the `ref.onDispose(() => _disposed =
  true)` line.
- `build()` returns the initial state purely from deps/args — no flag branch.
- Post-await writes guard with `ref.mounted`:

```dart
Future<void> complete() async {
  await _repo.markOnboardingDone();
  if (!ref.mounted) return;          // the only correct "still alive" check
  state = state.copyWith(done: true);
}
```

- "Run exactly once" → derive from a dependency, not a lifecycle latch:
  `final done = ref.watch(onboardingDoneProvider);` and branch on data.

## 3. Prove it with a rebuild-storm test

A single-build test will NOT reproduce this. Drive repeated
invalidate/rebuild cycles and assert the state converges and the build count
is bounded (see `snippets/rebuild_loop_test.dart`). Also wire the
`integration_test/boot_smoke_test.dart` storm guard.

## 4. Route

This is an auto-HIGH code-reviewer trigger (`ref.onDispose` + `bool _disposed`
latch) → bug-hunter. The fix lands in `IN_PROGRESS`; the regression test is a
test-writer Iron Rule #9 lifecycle test; verified running at
`INTEGRATION_SMOKE`.
