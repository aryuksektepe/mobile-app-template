---
name: ios-att-prompt
description: App Tracking Transparency (ATT) flow for iOS — pre-prompt education screen, ATT request timing (don't blast at launch — show after user gets value), IDFA gating, ordering BEFORE any tracking SDK first session, Consent Mode v2 coordination. Apple Guideline 5.1.2(i). Use whenever the app, an SDK, or an ad partner reads IDFA, builds device fingerprints, or shares data with third parties for advertising.
triggers: [att, app tracking transparency, apptrackingtransparency, idfa, tracking permission, ios tracking, NSUserTrackingUsageDescription, consent mode v2, IDFA opt-in, ATTrackingManager, pre-prompt, ad tracking, advertising id, ASIdentifierManager]
platforms: [ios]
last_verified: 2026-05-26
flutter_min: "3.22.0"
ios_min: "14.5"
package_versions:
  app_tracking_transparency: "^2.0.6+1"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: [firebase-core-setup]
---

# App Tracking Transparency (ATT) — iOS

## What this skill does

- Wires `app_tracking_transparency` 2.x with correct `NSUserTrackingUsageDescription`.
- Two-stage prompt: pre-prompt (custom UI explaining value) → system prompt — proven to lift opt-in rate by 20-40 pp.
- Defers ATT until a natural moment (post-onboarding / after first value), NOT first launch.
- Gates **all** tracking-SDK first sessions (Firebase Analytics, Mixpanel, Adjust, AppsFlyer, GAM/AdMob) behind `requestTrackingAuthorization()` — IDFA is permanently lost for the device's attribution if any SDK sends a session before the response.
- Coordinates with Google Consent Mode v2 (EU compliance).
- iOS < 14.5 safe guard.

## What this skill does NOT do

- Does NOT pick the copy for the pre-prompt — that's UX/legal.
- Does NOT implement SKAdNetwork / SKAN postback handling (separate skill territory; ad SDKs handle).
- Does NOT replace KVKK/GDPR consent banner — ATT is a SEPARATE iOS-only prompt; you still need Consent Mode v2 for EU.

## Decision tree

**Q1: Does the app, any analytics SDK, or any ad SDK read IDFA / build a fingerprint / share data with third parties for advertising?**
- YES → ATT prompt mandatory. Continue.
- NO → set `NSUserTrackingUsageDescription` anyway (defensive), but skip the prompt. Set `tracking_authorization_status` to `notDetermined` everywhere and never call `requestTrackingAuthorization()`.

**Q2: Pre-prompt or direct system prompt?**
- PRE-PROMPT (recommended) — custom Dart screen with value proposition, then user taps "Continue" → system prompt. ~20-40 pp higher opt-in.
- DIRECT — call `requestTrackingAuthorization()` straight from a natural moment. Simpler; lower opt-in.

**Q3: When to show?**
- Recommended natural moments: end of onboarding, after first content view, after a positive action. **NOT** first launch. **NOT** during tutorial.
- Apple guidance: "after they've experienced your app's benefits" — typically 6-30s into first session.

## Quick start

```bash
flutter pub add app_tracking_transparency
```

Add to `ios/Runner/Info.plist`:
```xml
<key>NSUserTrackingUsageDescription</key>
<string>İçeriği size daha alakalı hale getirmek ve reklam performansını ölçmek için cihaz tanıtıcınızı kullanmak istiyoruz.</string>
```

Keep the string **specific and accurate** (Apple Reject 5.1.2(i) if vague or misleading; ≤175 chars).

## Code patterns

| Need | File |
|---|---|
| ATT service (singleton, status cache, guard) | [snippets/att_service.dart](snippets/att_service.dart) |
| Pre-prompt screen | [snippets/att_pre_prompt.dart](snippets/att_pre_prompt.dart) |
| Info.plist entry | [snippets/Info.plist.snippet.xml](snippets/Info.plist.snippet.xml) |

For SDK init ordering (Firebase Analytics, AdMob, Adjust) → [implementation.md](implementation.md).

## Known pitfalls

→ [pitfalls.md](pitfalls.md) (10 entries). Top 5:
1. ATT blasted at first launch → opt-in ~25% (vs. 40-60% with proper timing).
2. `NSUserTrackingUsageDescription` missing → iOS treats it as automatic deny + may crash on call.
3. Tracking SDKs initialized BEFORE ATT response → IDFA permanently lost for the device's attribution (Singular, Adjust, AppsFlyer doc all warn).
4. Calling `getAdvertisingIdentifier()` after denial returns all-zeros UUID — never log or use it as user ID.
5. App Store reject 5.1.2(i): purpose string is vague or doesn't match data actually collected.

## Verification

→ [checklist.md](checklist.md) (10 items: pre-prompt shown at natural moment; SDKs gated until ATT response; iOS 14.0 device behavior; reject reason 5.1.2(i) self-audit).

## Skill metadata
- Validation status: **pre-seeded** (research-based; not yet validated in a real shipped app — append findings to pitfalls.md after first use)
- Last verified: 2026-05-26
- Depends on: `firebase-core-setup` (for Analytics that must be ATT-gated)
