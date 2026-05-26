# Privacy Manifest — Verification Checklist

Run per phase whenever a new pod / permission / tracking endpoint is added. Owned by `compliance` agent.

## Manifest structure
- [ ] `ios/Runner/PrivacyInfo.xcprivacy` exists
- [ ] Added to Runner target membership in Xcode
- [ ] Valid plist (open in Xcode without error) — `plutil -lint ios/Runner/PrivacyInfo.xcprivacy`
- [ ] Four top-level keys present (`NSPrivacyTracking`, `NSPrivacyTrackingDomains`, `NSPrivacyCollectedDataTypes`, `NSPrivacyAccessedAPITypes`)

## Required Reason APIs
- [ ] `audit-privacy-manifest.sh` shows every category your code or pods touch has a corresponding entry
- [ ] Every entry uses the correct reason code class (CA92.1 = app, 1C8F.1 = third-party SDK)
- [ ] `UserDefaults` declared (every Flutter app needs it via shared_preferences)
- [ ] File timestamp declared if using image_picker / cached_network_image / video_thumbnail / file_picker
- [ ] Disk space declared if using video record / large download / cache pre-check
- [ ] System boot time declared if using firebase_analytics / sentry_flutter (both call it for session)

## Third-party SDKs
- [ ] `find ios/Pods -name 'PrivacyInfo.xcprivacy'` lists every commonly-used SDK
- [ ] No pod from Apple's commonly-used list is missing a manifest
- [ ] No upload error `ITMS-91065`

## Tracking
- [ ] `NSPrivacyTracking` true ⇔ ANY collected data type has `Tracking=true`
- [ ] `NSPrivacyTrackingDomains` lists every endpoint posting tracking data (app-measurement.com, partner endpoints)
- [ ] `NSUserTrackingUsageDescription` present in Info.plist (cross-skill: `ios-att-prompt`)
- [ ] On ATT-denied device test build, DNS to listed domains is blocked (correct behavior)

## App Store Connect consistency
- [ ] App Privacy form in App Store Connect declares every data type listed in manifest
- [ ] No data type in App Privacy that is NOT in manifest
- [ ] Purposes match (analytics / advertising / app functionality)

## Upload gate
- [ ] TestFlight upload completes without `ITMS-91056` / `ITMS-91061` / `ITMS-91065`
- [ ] No App Review reject 5.1.x related to privacy declarations
