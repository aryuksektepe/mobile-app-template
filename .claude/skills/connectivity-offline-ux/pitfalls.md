# Connectivity Offline UX — Pitfalls Catalog

| # | Symptom | Cause | Fix | Source |
|---|---|---|---|---|
| 1 | Hotel/airport WiFi shows "online" but every API call times out | `connectivity_plus` only reports interface presence; captive portal hijacks DNS | Use `internet_connection_checker_plus` for reachability TCP probe | [connectivity_plus docs](https://pub.dev/packages/connectivity_plus) |
| 2 | China users see "offline" forever | Reachability probes Google by default — blocked in CN | Configure custom probe URL list — include a region-friendly endpoint | [internet_connection_checker docs](https://pub.dev/packages/internet_connection_checker_plus) |
| 3 | iOS app shows offline after returning from background | Stream subscription killed; not re-probed on resume | App lifecycle observer → `ref.invalidate(reachabilityProvider)` on resume | [Flutter app lifecycle](https://api.flutter.dev/flutter/widgets/AppLifecycleState.html) |
| 4 | Backend rate-limits on reconnect — 100 queued ops fire at once | Naive flush of pending queue on reconnect | Batch + debounce: flush in groups of 5, 200ms apart; circuit-break on 429 | this skill's pattern |
| 5 | Banner flickers on every transient drop (subway etc.) | No debounce; binary on/off too fast | Debounce 1-2s before showing offline banner | this skill snippet |
| 6 | iOS WiFi off but cellular on → `ConnectivityResult.mobile` but VPN routes all traffic | VPN status not reflected in `connectivity_plus.mobile` | List ALL connectivity types as "potentially online"; rely on reachability probe for truth | docs |
| 7 | Pending ops queue grows unbounded | No expiry — user offline for days, queue is huge | Set max queue size + drop oldest OR TTL (24h) per op | this skill |
| 8 | Reachability check costs battery (probing every 5s) | Polling instead of event-driven | Subscribe to `connectivity_plus` stream → debounce → ONE probe per transition; no polling | connectivity_plus docs |
| 9 | Web platform — connectivity_plus reports `wifi` always | Browsers don't expose interface; always reports connected | Use reachability probe only on web; or NavigatorOnline event | [MDN navigator.onLine](https://developer.mozilla.org/en-US/docs/Web/API/Navigator/onLine) |
| 10 | Offline UI for reads but writes silently fail | Repository didn't check connectivity before write | Connectivity-aware repository: on offline, queue + return success-pending; on online, flush | this skill's queued-op pattern |
