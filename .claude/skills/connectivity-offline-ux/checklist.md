# Connectivity Offline UX — Verification Checklist

- [ ] Both `connectivity_plus` + `internet_connection_checker_plus` in dependencies
- [ ] `reachabilityProvider` debounced (1-2s); banner doesn't flicker
- [ ] Reachability probe URL configurable per region (CN-safe alternative)
- [ ] OfflineBanner mounted in `MaterialApp.router` builder — visible across all screens
- [ ] App lifecycle observer invalidates reachability on resume
- [ ] Pending ops queue: max size, TTL, batch flush on reconnect
- [ ] Captive portal scenario tested (hotel WiFi sim)
- [ ] Repository pattern: writes queue when offline, return success-pending
- [ ] Reads: cache-first per `supabase-read-through-cache-mirror`; UI shows "stale data" indicator if backend unreachable
- [ ] Real-device test: airplane mode toggle → banner appears <2s; turn off → banner clears <2s
- [ ] No battery drain (subscription-based, not polling)
