---
name: connectivity-offline-ux
description: Connectivity-aware UX via `connectivity_plus` 6.x — Riverpod stream provider, global offline banner, queued operation pattern (retry on reconnect), cache-first reads (pairs with `supabase-read-through-cache-mirror`), distinction between "has network interface" vs "has internet reachability" (the former lies). Use whenever the app requires network and must remain usable / responsive when the connection drops.
triggers: [connectivity, connectivity_plus, offline, online, no internet, network status, offline banner, retry on reconnect, queued operation, internet reachability, ConnectivityResult, hasNetwork, has internet, captive portal]
platforms: [ios, android]
last_verified: 2026-05-26
flutter_min: "3.22.0"
package_versions:
  connectivity_plus: "^6.0.5"
  internet_connection_checker_plus: "^2.5.2"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# Connectivity-Aware Offline UX

## What this skill does

- Riverpod `connectivityProvider` stream (wifi / mobile / none / ethernet / vpn / bluetooth / other).
- Distinguishes **"has interface"** (`connectivity_plus`) from **"can reach internet"** (`internet_connection_checker_plus` — TCP probes a known endpoint). The former returns `wifi` on captive portal / hotel WiFi → traffic still fails.
- Global `OfflineBanner` widget mounted in `MaterialApp.router` builder — shows when reachability is false.
- Queued operation pattern: when offline, writes go to a Drift-backed pending queue + flush on reconnect.
- Cache-first read pattern guidance (use with `supabase-read-through-cache-mirror`).
- Lifecycle: re-probe reachability on app resume.

## What this skill does NOT do

- Does NOT implement the local DB queue itself (Drift-backed; uses `drift-schema-migrations`).
- Does NOT replace the per-feature offline UX (this is the chrome; per-feature handles its own loading/empty state).

## Decision tree

**Q1: Need real internet check or just interface presence?**
- INTERFACE ONLY (`connectivity_plus`) — fast, no traffic. False positive on captive portals.
- INTERNET REACHABILITY (`internet_connection_checker_plus`) — probes a real endpoint. Slower (~500ms) but accurate.
- BOTH (recommended) — wifi+mobile interface check is debounce trigger; reachability TCP probe confirms.

**Q2: Offline writes — drop or queue?**
- QUEUE (recommended for non-trivial apps) — Drift table `pending_ops` with retry policy; flushes on reconnect.
- DROP — fail and let user retry. Simpler but lossy UX.

## Quick start

```bash
flutter pub add connectivity_plus internet_connection_checker_plus
```

Apply [snippets/connectivity_provider.dart](snippets/connectivity_provider.dart). Mount `OfflineBanner` in your app shell.

## Code patterns

| Need | File |
|---|---|
| connectivityProvider + reachability + offline banner | [snippets/connectivity_provider.dart](snippets/connectivity_provider.dart) |

## Known pitfalls

→ [pitfalls.md](pitfalls.md). Top 5:
1. `connectivity_plus` returns `wifi` on captive portal — traffic still fails. Always combine with reachability probe.
2. Reachability probe to `google.com` blocked in CN/some regions; pick a region-friendly probe endpoint.
3. iOS background mode kills the stream subscription; re-fetch reachability on app resume.
4. Queued ops fire 100x on reconnect → backend rate-limit. Debounce + batch.
5. Banner shows for 200ms on every transient hiccup → flicker. Debounce 1-2s before showing.

## Verification

→ [checklist.md](checklist.md).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-26
- Depends on: (none; pairs with `supabase-read-through-cache-mirror` + `drift-schema-migrations` for queued ops)
