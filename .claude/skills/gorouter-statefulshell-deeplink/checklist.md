# Verification Checklist — go_router + StatefulShell deep links

## Redirect purity
- [ ] No `ref.read(...).notifier` / `state =` / `ref.invalidate` inside `redirect`/`build`/`initState`/`dispose`
- [ ] Side-effects moved to event handler / root `ref.listen` / post-frame callback
- [ ] Async auth: redirect returns `null` while loading (no premature path)

## Shell branch
- [ ] Deep-target routes live UNDER their `StatefulShellBranch`, or `goBranch(i)` is called
- [ ] Warm deep link switches to the correct tab
- [ ] Cold deep link lands on the correct screen AND the correct active tab

## Proven (INTEGRATION_SMOKE)
- [ ] Cold-start deep-link integration test: no red screen, correct screen, correct tab
- [ ] Warm deep-link integration test: branch switches
- [ ] Real push-tap / universal-link cold start exercised on a device/emulator
- [ ] code-reviewer flagged any redirect provider mutation as auto-HIGH
