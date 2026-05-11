# Onboarding Flow — Verification Checklist

## Setup
- [ ] Onboarding has 3-5 screens (not more)
- [ ] Total asset weight <2MB (verify with `flutter build --analyze-size`)
- [ ] Skip button visible on every screen
- [ ] Smooth page indicator visible

## State persistence
- [ ] First-launch flag stored in `shared_preferences` (NOT secure_storage)
- [ ] On detected first launch, secure_storage `deleteAll()` runs (verifies pitfall #1 mitigation)
- [ ] Onboarding step persisted; killing + reopening app resumes mid-flow
- [ ] App update does NOT re-show onboarding (pitfall #2)
- [ ] Debug "Reset onboarding" menu works

## A/B variant
- [ ] Remote Config parameter `onboarding_variant` exists
- [ ] First-launch fetch awaited with 4s timeout (no infinite splash)
- [ ] Variant logged as Analytics user property `onboarding_variant`
- [ ] Same user under same audience condition gets same variant across reinstalls

## Permissions
- [ ] Soft-ask explanation shown BEFORE OS prompt for any sensitive permission
- [ ] ATT prompt NOT shown on screen 1
- [ ] Notification permission deferred to first relevant moment
- [ ] Outcome (granted/denied) logged to analytics

## Deep link replay
- [ ] Deep link arriving during onboarding → stashed in pendingDeepLinkProvider
- [ ] After `complete()`, user lands on the deep-linked screen (NOT `/home`)
- [ ] If no deep link, lands on `/home`

## Analytics funnel
- [ ] `onboarding_step_viewed{step:N, variant:X}` fires per step
- [ ] `onboarding_completed{variant:X, final_step:N}` fires once
- [ ] DebugView shows the funnel during testing

## Localization + accessibility
- [ ] All strings in ARB files (TR + EN minimum)
- [ ] RTL languages don't break layout (use EdgeInsetsDirectional)
- [ ] Semantic labels present on each page
- [ ] Color contrast ≥4.5:1
- [ ] Tested with system font at 200%
- [ ] All buttons ≥48dp hit target
