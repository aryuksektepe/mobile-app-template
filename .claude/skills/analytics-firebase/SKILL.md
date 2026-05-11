---
name: analytics-firebase
description: Firebase Analytics (GA4) for Flutter — event taxonomy, user properties, Consent Mode v2 (KVKK/GDPR), DebugView, BigQuery export, ATT coordination. Type-safe AnalyticsService wrapper, Riverpod-friendly. Use when adding any user-behavior tracking.
triggers: [analytics, firebase_analytics, ga4, event tracking, user property, consent mode, debugview, screen tracking, conversion, funnel, retention]
platforms: [ios, android]
last_verified: 2026-05-10
flutter_min: "3.3.0"
ios_min: "13.0"
android_min_sdk: 23
package_versions:
  firebase_analytics: "^12.3.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: [firebase-core-setup]
---

# Firebase Analytics (GA4)

## What this skill does

- Wires `firebase_analytics` 12.x with type-safe `AnalyticsService` wrapper.
- Configures **Consent Mode v2** (4 flags: `ad_storage`, `analytics_storage`, `ad_user_data`, `ad_personalization`) — mandatory for EU/TR personalization since July 2025.
- Default-deny consent on launch; flip after explicit user acceptance.
- Defines event taxonomy rules (snake_case, ≤40 chars, ≤25 params, no PII).
- Coordinates with **ATT** prompt (only required if you use IDFA — Firebase Analytics alone uses IDFV).
- Sets up DebugView for iOS + Android.
- Riverpod providers + GoRouter screen-tracking observer.

## What this skill does NOT do

- Does NOT design your event taxonomy — that's a product decision; this skill enforces the format.
- Does NOT set up A/B tests — that's `remote-config-firebase`.
- Does NOT implement consent UI — only provides the `setConsent` API hooks.

## Decision tree

**Q1: Do you collect IDFA via Google Ads SDK / Adjust / AppsFlyer?**
- YES → ATT prompt mandatory before any IDFA-using event. Show consent banner first, then ATT.
- NO (Firebase Analytics alone) → ATT NOT required. Use IDFV (auto, no consent UI for IDFV itself).

**Q2: GDPR/KVKK consent banner?**
- YES (default for any app serving EU/TR) → default-deny in Info.plist + Manifest, consent UI on first launch, only flip flags after user accepts.
- NO → app is consumer-region-only outside EU/TR. Verify with legal.

**Q3: BigQuery export?**
- YES (recommended for serious projects) → free up to 1M events/day; required for cohort analysis, custom funnels, ML.
- NO → standard reports only. OK for early-stage.

## Quick start

```bash
flutter pub add firebase_analytics
# Re-run flutterfire reconfigure to add Analytics platform-side
```

## Code patterns

| Need | File |
|---|---|
| Riverpod provider + GoRouter observer | [snippets/analytics_providers.dart](snippets/analytics_providers.dart) |
| Type-safe AnalyticsService wrapper | [snippets/analytics_service.dart](snippets/analytics_service.dart) |
| Default-deny Info.plist entries | [snippets/Info.plist.snippet.xml](snippets/Info.plist.snippet.xml) |
| Default-deny AndroidManifest entries | [snippets/AndroidManifest.snippet.xml](snippets/AndroidManifest.snippet.xml) |
| Consent flip on user acceptance | [snippets/consent_handler.dart](snippets/consent_handler.dart) |

For full setup (DebugView per platform, BigQuery linking, audience definitions) → [implementation.md](implementation.md).

## Known pitfalls

→ [pitfalls.md](pitfalls.md) (14 entries). Top 5:
1. DebugView empty on iOS via CLI — must launch from Xcode scheme with `-FIRDebugEnabled`.
2. Standard reports update on 24-48h delay; only DebugView/Realtime are live.
3. Personalization disabled silently in EEA without Consent Mode v2.
4. Logging email/phone in event params = KVKK violation + Google policy.
5. High-cardinality params bucketed as `(other)` after ~500 unique values.

## Verification

→ [checklist.md](checklist.md) (12 items: DebugView verified per platform, consent flow tested, no PII in events, BigQuery export configured).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-10 against `firebase_analytics` 12.3.0
- Depends on: `firebase-core-setup` (must be configured first)
