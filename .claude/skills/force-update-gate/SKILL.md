---
name: force-update-gate
description: Force/soft update flow — compares current app version with Remote Config minimum_version + recommended_version, shows blocking modal for force-update, dismissable banner for soft-update, deep-links to App Store / Play Store. Handles staged rollout (gradual force-update via Remote Config percentage). Use whenever the app has a server-side flag to require/recommend updates (kill-switch for broken releases, deprecated API endpoints, mandatory security fixes).
triggers: [force update, soft update, minimum version, update gate, kill switch, version check, app update, store deep link, in app update, app review reject update]
platforms: [ios, android]
last_verified: 2026-05-26
flutter_min: "3.22.0"
package_versions:
  package_info_plus: "^8.0.0"
  url_launcher: "^6.3.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: [remote-config-firebase]
---

# Force Update Gate

## What this skill does

- Reads `minimum_version` + `recommended_version` from Remote Config (`remote-config-firebase` skill provides the typed snapshot).
- On every cold start AND foreground resume: compares with current `Version` (`package_info_plus`).
- 3 states: **FORCE_UPDATE** (current < minimum) → blocking modal, no dismiss; **SOFT_UPDATE** (current < recommended) → dismissable banner with "later"; **UP_TO_DATE** → no UI.
- Store deep links: iOS `itms-apps://apps.apple.com/app/id<APPLE_ID>`, Android `market://details?id=<PACKAGE>` (with HTTPS fallback).
- Riverpod `updateGateProvider` exposing the current state — router redirect picks up FORCE.
- Staged rollout: Remote Config can target % of users for force-update (gradual ramp).
- Works alongside the OS-native `in_app_update` (Android Play Core flexible/immediate update) — this skill is the SERVER-DRIVEN gate; in-app-update is the install mechanism.

## What this skill does NOT do

- Does NOT execute the install itself — `url_launcher` to store + (optional) `in_app_update` Android.
- Does NOT track update analytics — separate event taxonomy (`analytics-firebase`).
- Does NOT replace a runtime kill-switch for individual features (use Remote Config flags directly for that).

## Decision tree

**Q1: Force or soft?**
- FORCE — major breaking change (auth flow rewrite, schema migration, security incident). User CANNOT bypass.
- SOFT — recommended (new features, perf). User can dismiss with "later".

**Q2: When to evaluate?**
- COLD START — always.
- FOREGROUND RESUME — yes, in case Remote Config updated while app was backgrounded.
- POST-RC-UPDATE — yes (real-time listener; Remote Config v4+ supports realtime).

**Q3: Staged rollout?**
- Use Remote Config conditions: targeting 5% → 25% → 50% → 100% over days. Reduces risk of mass-bricking on a bad force-update.

## Quick start

```bash
flutter pub add package_info_plus url_launcher
```

Apply [snippets/update_gate.dart](snippets/update_gate.dart). Wire `updateGateProvider` into the go_router redirect.

Remote Config setup (Firebase Console):
- `minimum_version` (String) — semver, e.g. `"2.4.0"`
- `recommended_version` (String) — semver
- `update_force_message` (String, optional) — custom force-update copy
- `update_soft_message` (String, optional) — custom soft-update copy

## Code patterns

| Need | File |
|---|---|
| Update gate provider + comparison logic | [snippets/update_gate.dart](snippets/update_gate.dart) |
| Blocking modal widget | [snippets/force_update_modal.dart](snippets/force_update_modal.dart) |

## Known pitfalls

→ [pitfalls.md](pitfalls.md). Top 5:
1. Force-update shipped without backup escape hatch — RC rollback works, but if Firebase RC itself is down, every user is locked out.
2. Version comparison fails on `"2.10.0" > "2.9.0"` because of string compare instead of semver.
3. Store deep link `market://` not handled on devices without Play Store (e.g., Huawei AppGallery) — fallback to HTTPS.
4. Force-update blocks even when user is on a working older version with NO breaking issue — overuse erodes trust.
5. RC fetch fails on no-network — without sane defaults the gate may show "force update" on first launch.

## Verification

→ [checklist.md](checklist.md).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-26
- Depends on: `remote-config-firebase`
