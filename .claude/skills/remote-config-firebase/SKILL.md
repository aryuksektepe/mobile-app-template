---
name: remote-config-firebase
description: Firebase Remote Config for Flutter — feature flags, A/B test variants, kill switches, force-update gates. Real-time updates (since v4), typed snapshot via freezed AppConfig + Riverpod StreamProvider, non-blocking fetch with safe defaults. Use whenever a value should be controllable without app release.
triggers: [remote config, feature flag, ab test, a/b test, kill switch, force update, paywall variant, dynamic config, server-side config, conditional config]
platforms: [ios, android]
last_verified: 2026-05-10
flutter_min: "3.3.0"
ios_min: "13.0"
android_min_sdk: 23
package_versions:
  firebase_remote_config: "^6.4.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: [firebase-core-setup]
---

# Firebase Remote Config

## What this skill does

- Wires `firebase_remote_config` 6.x with **non-blocking fetch** (defaults available immediately, real values activate when ready).
- Typed snapshot: `AppConfig` freezed model + `appConfigProvider` Riverpod StreamProvider that **re-emits on real-time updates** (`onConfigUpdated`, since v4.0.0).
- Safe defaults for every key (offline-first principle).
- A/B test integration: log variant assignment as Firebase Analytics user property for sticky bucketing.
- Force-update gate pattern (`min_supported_build`).

## What this skill does NOT do

- Does NOT implement the consent banner gating (use `analytics-firebase` for that).
- Does NOT design the parameter taxonomy — that's product/ops.
- Does NOT manage A/B test experiment lifecycle in Firebase Console.

## Decision tree

**Q1: Block app start on remote config fetch?**
- NO (recommended) — show with defaults, activate when fetched. User sees app in <2s always.
- YES — only for variants that materially differ (e.g., paywall A/B). Then use a 2-4s splash with `await fetchAndActivate().timeout(...)`.

**Q2: Real-time updates needed?**
- YES (recommended for kill switches, maintenance mode) — subscribe to `onConfigUpdated` stream. Updates within ~1 min of console publish.
- NO — standard fetch interval is enough.

**Q3: Use Remote Config for legal/compliance gates (e.g., GDPR consent banner show/hide)?**
- NO. NEVER. Hard-code legal triggers by `Locale`/`Country`. RC default-fetch failure could cause unlawful processing.

## Quick start

```bash
flutter pub add firebase_remote_config
flutterfire reconfigure
```

In Firebase Console → Remote Config → add parameters with defaults + Conditions (country, app version, audience).

## Code patterns

| Need | File |
|---|---|
| Typed AppConfig + Riverpod StreamProvider | [snippets/remote_config.dart](snippets/remote_config.dart) |
| Bootstrap with non-blocking fetch | [snippets/init_remote_config.dart](snippets/init_remote_config.dart) |
| Force-update check widget | [snippets/force_update_gate.dart](snippets/force_update_gate.dart) |

For full setup (parameter taxonomy, conditions, A/B test linking) → [implementation.md](implementation.md).

## Known pitfalls

→ [pitfalls.md](pitfalls.md) (14 entries). Top 5:
1. Onboarding flickers control→variant — set defaults that work standalone, OR splash-block.
2. Default 12h fetch interval surprises — server still enforces ~1h prod floor regardless.
3. `getInt('foo')` returns 0 — type mismatch with `setDefaults`; use `getValue('foo').asInt()`.
4. Real-time storm during console rollout — debounce + check `event.updatedKeys`.
5. Force-update fails when offline — defaults must include current build to never block legit users.

## Verification

→ [checklist.md](checklist.md) (10 items: defaults match all keys, real-time updates fire, A/B variant logged to Analytics).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-10 against `firebase_remote_config` 6.4.0
- Depends on: `firebase-core-setup`
