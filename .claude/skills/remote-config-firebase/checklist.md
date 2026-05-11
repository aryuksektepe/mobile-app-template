# Firebase Remote Config — Verification Checklist

- [ ] `firebase_remote_config: ^6.4.0` resolved
- [ ] `flutterfire reconfigure` run
- [ ] Every `AppConfig` field has a matching default in `AppConfig.defaults`
- [ ] Every default has a matching parameter in Firebase Console
- [ ] `setDefaults` called BEFORE `fetchAndActivate`
- [ ] `fetchAndActivate` is `unawaited` OR has a `.timeout(<5s)`
- [ ] `appConfigProvider` is app-scoped, not widget-scoped (no listener leaks)
- [ ] Console value change → real-time listener fires within ~1 min on a foregrounded device
- [ ] Force-update gate: bumping `min_supported_build` to current+1 shows ForceUpdateScreen
- [ ] Force-update gate with `min_supported_build = 1` (default) NEVER blocks any user
- [ ] Maintenance gate: setting `maintenance_mode = true` in console shows MaintenanceScreen within ~1 min
- [ ] A/B variant logged as Analytics user property after first paint (verify in DebugView)
- [ ] No legal/compliance gate (consent banner, GDPR trigger) depends on a RC value
