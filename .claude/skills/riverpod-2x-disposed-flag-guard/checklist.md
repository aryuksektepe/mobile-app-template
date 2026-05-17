# Verification Checklist — disposed-flag latch

- [ ] No `bool _disposed` field in any `Notifier`/`AsyncNotifier` set from `ref.onDispose`
- [ ] No disposal flag read inside `build()` (build is pure over deps/args)
- [ ] Post-await state writes guard with `if (!ref.mounted) return;`, not a flag
- [ ] "Run once" semantics derived from a dependency, not a lifecycle latch
- [ ] Rebuild-storm regression test exists (≥20 invalidate cycles → bounded builds, state converges)
- [ ] `integration_test/boot_smoke_test.dart` shows no rebuild storm on the affected screen
- [ ] code-reviewer flagged the original as auto-HIGH (onDispose + _disposed latch)
