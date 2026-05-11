---
name: onboarding-flow
description: First-launch onboarding screens — 3-5 page PageView, A/B variant via Remote Config, soft-ask permission pattern (notifications/location/ATT deferred to right narrative moment), Riverpod state, deep-link replay after completion. Conversion-tuned defaults (research shows 21-72% drop-off when >5 screens).
triggers: [onboarding, intro screens, walkthrough, first launch, welcome screen, soft ask, permission rationale]
platforms: [ios, android]
last_verified: 2026-05-10
flutter_min: "3.22.0"
ios_min: "13.0"
android_min_sdk: 23
package_versions:
  shared_preferences: "^2.3.0"
  smooth_page_indicator: "^1.2.1"
  lottie: "^3.0.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: [secure-storage-tokens, remote-config-firebase]
---

# Onboarding Flow

## What this skill does

- 3-5 screen PageView with `smooth_page_indicator` + persistent Skip + Next/Get-Started buttons.
- **First-launch detection** via `shared_preferences` (cleared on uninstall, unlike Keychain).
- **Wipes secure storage** on detected fresh install (chains with `secure-storage-tokens` skill — solves iOS Keychain persistence trap).
- **A/B variant** from Remote Config (`onboarding_variant`) with sticky bucketing logged to Analytics.
- **Soft-ask permission pattern**: explain WHY first, then OS prompt. Notification + location + ATT all deferred to first relevant moment.
- **Deep-link replay**: stash incoming deep link; replay AFTER onboarding completes.
- Riverpod `OnboardingController` with persistent step (resume mid-flow).
- Localization-ready (TR + EN ARB), RTL-safe, accessibility (semantic labels, contrast).

## What this skill does NOT do

- Does NOT design the onboarding copy/visuals (product/UX work).
- Does NOT cover signup/login flows (use `auth-firebase-email`).

## Decision tree

**Q1: Track step-by-step progress (resume mid-flow)?**
- YES → store `onboarding_step` int in shared_preferences. User who killed app on screen 3 resumes there.
- NO → just `onboarding_completed` boolean. Simpler. Forces user to start over if interrupted.

**Q2: A/B test the onboarding variant?**
- YES → use Remote Config `onboarding_variant` parameter; mirror to Analytics user property for sticky bucketing.
- NO → single variant; can A/B later by adding the param.

**Q3: Where to ask for notification permission?**
- During onboarding (last screen) — higher conversion if framed well, but burns iOS prompt early.
- AFTER onboarding, at first relevant moment (e.g., "Get notified when your order ships") — RECOMMENDED. Higher acceptance.

## Quick start

```bash
flutter pub add shared_preferences smooth_page_indicator lottie flutter_riverpod
```

## Code patterns

| Need | File |
|---|---|
| OnboardingController (Riverpod state) | [snippets/onboarding_controller.dart](snippets/onboarding_controller.dart) |
| OnboardingScreen (PageView) | [snippets/onboarding_screen.dart](snippets/onboarding_screen.dart) |
| Soft-ask permission widget pattern | [snippets/soft_ask_widget.dart](snippets/soft_ask_widget.dart) |
| GoRouter onboarding gate | [snippets/router_gate.dart](snippets/router_gate.dart) |

For full setup (asset budget, A/B variant config, accessibility) → [implementation.md](implementation.md).

## Known pitfalls

→ [pitfalls.md](pitfalls.md) (14 entries). Top 5:
1. Onboarding skipped after iOS reinstall — Keychain persists; use shared_preferences sentinel.
2. ATT prompt one-shot — don't burn it on screen 1; defer to value moment.
3. >5 screens = high drop-off; cap at 3-5, time-to-value <60s.
4. A/B variant flickers control→variant — block splash on RC fetch with timeout.
5. Deferred deep link eaten by onboarding — stash in provider, replay after complete.

## Verification

→ [checklist.md](checklist.md) (12 items: drop-off funnel, RTL, accessibility, deep-link replay, A/B variant logged).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-10
- Depends on: `secure-storage-tokens`, `remote-config-firebase`
