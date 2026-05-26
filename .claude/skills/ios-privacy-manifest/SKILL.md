---
name: ios-privacy-manifest
description: iOS Privacy Manifest (PrivacyInfo.xcprivacy) — required by Apple since May 1, 2024. Declares data types collected, tracking domains, required-reason API usage (UserDefaults, file timestamp, disk space, system boot time, active keyboard). Without it the binary is rejected at upload. Also enforces that "commonly-used" third-party SDKs ship their own manifest + signature. Use as Phase 01 foundation work and whenever a new SDK is added.
triggers: [privacy manifest, PrivacyInfo.xcprivacy, required reason api, NSPrivacyAccessedAPITypes, NSPrivacyTracking, NSPrivacyTrackingDomains, NSPrivacyCollectedDataTypes, app store reject privacy, third party sdk signature, ITMS-91056, ITMS-91061, ITMS-91065]
platforms: [ios]
last_verified: 2026-05-26
flutter_min: "3.22.0"
ios_min: "13.0"
package_versions: {}
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# iOS Privacy Manifest

## What this skill does

- Creates `ios/Runner/PrivacyInfo.xcprivacy` with the four required sections.
- Maps your app's runtime to the **Required Reason API** categories Apple enforces.
- Declares `NSPrivacyTracking` + `NSPrivacyTrackingDomains` consistent with `NSUserTrackingUsageDescription` (skill: `ios-att-prompt`) and App Store Connect → App Privacy.
- Audits third-party SDKs for their own manifests + signatures (Apple ITMS-91065 reject if missing).
- Provides a `tools/audit-privacy-manifest.sh` helper that grep-matches your codebase against the Required Reason API list.

## What this skill does NOT do

- Does NOT fill App Store Connect → App Privacy form (that's a separate App Store Connect UI; the manifest and the form MUST agree, but the form is filled by hand).
- Does NOT replace a privacy policy URL (also required separately).
- Does NOT enumerate every third-party SDK's privacy practices — vendor's responsibility.

## Decision tree

**Q1: Does your app call `UserDefaults` / `NSUserDefaults`?**
- YES (almost certainly — every Flutter app uses it via shared_preferences) → declare `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1` (own data) or `1C8F.1` (third-party SDK).
- NO → skip.

**Q2: Does your app read file modification dates (`stat`, `fileModificationDate`, `creationDate`)?**
- YES (cached_network_image, image_picker, video thumbnails do this) → declare `NSPrivacyAccessedAPICategoryFileTimestamp` with reason `3B52.1` (display to user) or `C617.1` (sync with cloud) or `0A2A.1` (own app data).
- NO → skip.

**Q3: Does your app check available disk space?**
- YES (downloads, video record, large cache write) → declare `NSPrivacyAccessedAPICategoryDiskSpace` with reason `7D9E.1` (display) or `B728.1` (own data write) or `85F4.1` (sync).
- NO → skip.

**Q4: Does your app read system boot time (`uptime`, `mach_absolute_time`)?**
- YES (analytics session ID, crash timestamps) → declare `NSPrivacyAccessedAPICategorySystemBootTime` with reason `35F9.1` (measure performance).
- NO → skip.

**Q5: Does your app read the active keyboard list (rare — IME / keyboard apps)?**
- YES → declare `NSPrivacyAccessedAPICategoryActiveKeyboards` with reason `54BD.1` (custom keyboard) or `3EC4.1` (developer's own keyboard).
- NO → skip.

**Q6: Are you tracking users across apps/websites (combining data with other companies' data for ads)?**
- YES → `NSPrivacyTracking: true` + list domains in `NSPrivacyTrackingDomains` + ATT prompt mandatory (skill: `ios-att-prompt`).
- NO → `NSPrivacyTracking: false`, no domains list. (But ATT prompt may still be needed if any SDK fingerprints — read partner docs.)

## Quick start

1. Create `ios/Runner/PrivacyInfo.xcprivacy` (see [snippets/PrivacyInfo.xcprivacy](snippets/PrivacyInfo.xcprivacy)).
2. Add it to the Runner target in Xcode: drag into the Runner group, ensure "Copy items if needed" + Target Membership = Runner.
3. Run the audit helper: `bash tools/audit-privacy-manifest.sh` — flags every Required Reason API call site so you can verify the manifest matches.
4. Upload to TestFlight; the binary upload errors out immediately if the manifest is malformed.

## Code patterns

| Need | File |
|---|---|
| Full PrivacyInfo.xcprivacy template (annotated) | [snippets/PrivacyInfo.xcprivacy](snippets/PrivacyInfo.xcprivacy) |
| Required Reason API audit script | [snippets/audit-privacy-manifest.sh](snippets/audit-privacy-manifest.sh) |
| Third-party SDK manifest checklist | [snippets/sdk-checklist.md](snippets/sdk-checklist.md) |

For ITMS-91056 / 91061 / 91065 reject debugging → [implementation.md](implementation.md).

## Known pitfalls

→ [pitfalls.md](pitfalls.md) (10 entries). Top 5:
1. Binary upload reject `ITMS-91056` — manifest missing Required Reason API your app actually calls (likely UserDefaults — every Flutter app uses it).
2. Binary upload reject `ITMS-91065` — a commonly-used third-party SDK (Firebase, FB SDK, Adjust, AppsFlyer, Branch) is missing its own manifest OR signature in your pod.
3. `NSPrivacyTracking: true` declared but no `NSUserTrackingUsageDescription` → App Review reject + ATT prompt won't show.
4. App Privacy form in App Store Connect contradicts the manifest (e.g., manifest says "no tracking" but form says "yes") → App Review reject.
5. Wrong reason code for a Required Reason API (e.g., using `CA92.1` for a third-party SDK's UserDefaults — should be `1C8F.1`) → App Review reject.

## Verification

→ [checklist.md](checklist.md) (12 items: manifest valid plist, all Required Reason APIs covered, SDKs audited, App Privacy form consistent, no extraneous declarations).

## Skill metadata
- Validation status: **pre-seeded** (research-based from Apple developer docs + Bitrise + Singular + community reports — verify against your specific SDK set)
- Last verified: 2026-05-26
- Depends on: (none — foundation work)
