# Verification Checklist

After implementing this skill, verify:

- [ ] `dart format --set-exit-if-changed .` returns 0
- [ ] `dart run build_runner build --delete-conflicting-outputs` succeeds
- [ ] `flutter analyze` returns 0 issues
- [ ] `flutter test` passes (relevant tests added)
- [ ] Manual: {specific user-visible verification}
- [ ] Permission flow tested on iOS + Android (if applicable)
- [ ] Edge case: {named scenario from pitfalls.md}
- [ ] No new lint warnings introduced
