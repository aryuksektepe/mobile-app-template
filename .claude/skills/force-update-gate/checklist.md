# Force Update Gate — Verification Checklist

- [ ] RC keys defined with defaults: `minimum_version=0.0.0`, `recommended_version=0.0.0`
- [ ] `updateGateProvider` wired into go_router redirect (FORCE → `/force-update`)
- [ ] Cold-start re-fetch path tested
- [ ] Foreground-resume re-fetch wired (app lifecycle listener)
- [ ] Semver compare unit-tested: `2.10.0 > 2.9.0`, `2.0.0-rc.1 == 2.0.0`, weird inputs (`"abc"`) fall back gracefully
- [ ] Force modal has `PopScope(canPop: false)` — back gesture cannot dismiss
- [ ] Store deep link uses primary scheme (`itms-apps://` / `market://`) AND HTTPS fallback
- [ ] Huawei device path tested (Play Store missing — HTTPS fallback works)
- [ ] Staged rollout RC condition created BEFORE first force flip
- [ ] App Review bypass strategy documented (RC condition based on App Version targeting OR feature flag)
- [ ] When force-update active, all other navigation is blocked (verify by testing deep-link tap)
- [ ] Telemetry event `update_gate_shown` fires for both force + soft (per `analytics-firebase`)
