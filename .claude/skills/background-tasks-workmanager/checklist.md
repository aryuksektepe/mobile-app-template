# Background Tasks — Verification Checklist

- [ ] `workmanager` 0.6+ in dependencies
- [ ] `callbackDispatcher` is TOP-LEVEL function with `@pragma('vm:entry-point')`
- [ ] iOS: Xcode Capabilities → Background Modes → Background fetch + Background processing enabled
- [ ] iOS: Info.plist `BGTaskSchedulerPermittedIdentifiers` includes every task identifier
- [ ] Android: tasks scheduled with reasonable frequency (≥ 15 min)
- [ ] Constraints: `networkType.connected` (not `unmetered` unless really OK to never run on cellular)
- [ ] `requiresBatteryNotLow: true` for non-urgent work
- [ ] Exponential backoff on failure (`BackoffPolicy.exponential`)
- [ ] Top-level callback wraps work in try/catch + returns false on failure
- [ ] Task work completes in < 30s on iOS BGAppRefreshTask
- [ ] OEM battery workaround dialog shown to user (Xiaomi / Huawei / Samsung detection)
- [ ] Tested on real iOS device with lldb simulate trigger
- [ ] Tested on a Xiaomi or Huawei device (the canonical "kill background" cases)
- [ ] Crash reporter logs task failures (per `crash-monitor-dual`)
- [ ] Documented expectation: "may not run if device idle / Low Power"; do NOT use for real-time
