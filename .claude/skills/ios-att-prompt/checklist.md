# ATT — Verification Checklist

Per CLAUDE.md §3 INTEGRATION_SMOKE gate — these are executed on a real iOS 14.5+ device. Simulator behavior is reliable but App Review tests on devices.

## Info.plist
- [ ] `NSUserTrackingUsageDescription` present
- [ ] String is specific (lists data categories + purposes), ≤175 chars
- [ ] Localized for every supported locale via `Runner/{locale}.lproj/InfoPlist.strings`
- [ ] String matches App Store Connect → App Privacy → Data Used to Track You
- [ ] String matches `NSPrivacyTrackingDomains` in Privacy Manifest (skill: `ios-privacy-manifest`)

## Bootstrap order (main.dart)
- [ ] `AttService.bootstrap()` called BEFORE any tracking SDK first session
- [ ] Firebase Analytics `setConsent(...)` called with pre-ATT defaults (analytics ON, ads OFF)
- [ ] Adjust / AppsFlyer / AdMob NOT initialized before ATT response
- [ ] iOS < 14.5 guard returns `authorized` without calling the API

## Pre-prompt
- [ ] Triggered from a natural moment (post-onboarding / post first FR success), NOT first launch
- [ ] App-branded UI (no system-mimicry)
- [ ] Single CTA "Continue" (no skip/later — those route to the system prompt)
- [ ] Neutral framing (no "tap Allow to enable the app")
- [ ] Reachable test: PRD entry point → pre-prompt screen, executed on device (per INTEGRATION_SMOKE criterion 5)

## After ATT response
- [ ] `setConsent` re-synced with resolved status
- [ ] Tracking SDKs init AFTER status resolved
- [ ] On denial: app fully functional — no feature gated

## QA scenarios (cover in qa-test-guide YAML)
- [ ] Reset tracking + relaunch: `xcrun simctl privacy <udid> reset tracking <bundle>` → prompt shows again
- [ ] Tap "Don't Allow": app continues to next screen, all features available
- [ ] Tap "Allow": Firebase Analytics DebugView shows `ad_storage=granted`
- [ ] iOS 14.4 sim: no prompt, IDFA returned, no exception

## App Review self-audit (5.1.2(i))
- [ ] Purpose string accurately describes data + partners?
- [ ] App Privacy declaration matches?
- [ ] Pre-prompt doesn't imply consent is required?
- [ ] No feature is gated by ATT response?
