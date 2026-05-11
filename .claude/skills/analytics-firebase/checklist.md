# Firebase Analytics — Verification Checklist

## Setup
- [ ] `firebase_analytics: ^12.3.0` resolved
- [ ] `flutterfire reconfigure` run after adding the package
- [ ] iOS pods reinstalled

## Default-deny consent
- [ ] All 4 `GOOGLE_ANALYTICS_DEFAULT_ALLOW_*` keys set to `false` in `ios/Runner/Info.plist`
- [ ] All 4 `google_analytics_default_allow_*` meta-data entries set to `false` in `AndroidManifest.xml`
- [ ] Verified via DebugView: NO events appear before consent flip

## Consent flow
- [ ] Consent UI shown on first launch (or version bump)
- [ ] After "Accept all": all 4 flags flip to true; events start appearing in DebugView within seconds
- [ ] After "Deny all": no analytics events appear; `setConsent(false, false, false, false)` confirmed
- [ ] Consent choice persisted across app restarts
- [ ] Bumping `currentConsentVersion` re-shows banner

## Event taxonomy
- [ ] All event names snake_case, ≤40 chars
- [ ] No reserved prefixes (`firebase_`, `google_`, `ga_`)
- [ ] Per-event param count ≤25
- [ ] No PII in any event param (verified by reading every `logEvent` call)
- [ ] User IDs hashed before being passed to `setUserId`

## DebugView
- [ ] iOS DebugView shows events when launched from Xcode with `-FIRDebugEnabled`
- [ ] Android DebugView shows events after `adb shell setprop debug.firebase.analytics.app <package>`
- [ ] Screen views fire on every navigation (verify with GoRouter observer wired)

## ATT (only if using IDFA)
- [ ] `NSUserTrackingUsageDescription` set in Info.plist
- [ ] ATT prompt fires AFTER consent banner accepted, NOT at app launch
- [ ] ATT denial does NOT prevent Analytics (uses IDFV instead) when consent granted

## Compliance
- [ ] Privacy policy lists Firebase / Google as processor with purpose
- [ ] Privacy policy explains the 4 consent flags in plain language
- [ ] No PII or quasi-identifiers in any logged event (manual review)
- [ ] Play Data Safety form declares "App activity / App interactions" + "Device or other IDs"
- [ ] App Store Privacy declares "Product Interaction" + "Device ID"

## BigQuery (if enabled)
- [ ] Linked in same region as Firestore/Storage
- [ ] First batch arrived within 24h of linking
- [ ] Sample query against `events_*` returns expected event names
