# Firebase Analytics — Pitfalls Catalog

14 entries from FlutterFire issues, Firebase docs, and Consent Mode v2 updates.

| # | Symptom | Cause | Fix | Source |
|---|---|---|---|---|
| 1 | DebugView empty on iOS when running `flutter run` from CLI | `-FIRDebugEnabled` only persists when launching from Xcode scheme args | Edit Xcode scheme → Run → Arguments → add `-FIRDebugEnabled`. After first Xcode launch the flag persists for CLI runs until reset | [GH #8662](https://github.com/firebase/flutterfire/issues/8662) |
| 2 | DebugView empty on Android | Debug flag not set | `adb shell setprop debug.firebase.analytics.app com.acme.myapp.dev` (use the package matching your flavor) | [Firebase docs](https://firebase.google.com/docs/analytics/debugview) |
| 3 | Events logged but missing from "Events" report for 24-48h | Standard reports update on a delay; only DebugView and Realtime are live | Use DebugView during dev; document delay for stakeholders | [Firebase docs](https://firebase.google.com/docs/analytics/debugview) |
| 4 | Event name `Sign-Up` rejected | Event names must be `[a-zA-Z][a-zA-Z0-9_]{0,39}` (snake_case, ≤40 chars) | Use snake_case: `sign_up` (or built-in: `logSignUp`) | [Firebase param-names](https://firebase.google.com/docs/reference/cpp/group/parameter-names) |
| 5 | Event silently dropped | Used reserved prefix `firebase_`, `google_`, or `ga_` in event/param name | Rename. Avoid those prefixes everywhere | [Firebase docs](https://firebase.google.com/docs/reference/cpp/group/parameter-names) |
| 6 | Param values truncated | String param values capped at **100 chars** | Truncate or hash before logging; never put long URLs/JSON in a param | [Firebase docs](https://firebase.google.com/docs/reference/cpp/group/parameter-names) |
| 7 | Reports show "(other)" for a custom param | High-cardinality string param; GA4 buckets after ~500 unique values | Reduce cardinality (bucket prices into ranges, omit user IDs as event params) | [Firebase events docs](https://firebase.google.com/docs/analytics/events) |
| 8 | "Audience" doesn't fire | More than 25 user properties, or used reserved property name | Audit user properties (limit 25); use `setUserProperty(name, value)` with allowed naming | [Firebase user-properties](https://firebase.google.com/docs/analytics/user-properties) |
| 9 | Personalization disabled silently in EEA | After July 2025 Google began disabling personalization/remarketing for apps without Consent Mode v2 | Implement the four `setConsent` flags + Info.plist/Manifest defaults | [Respectlytics article](https://respectlytics.com/blog/google-consent-mode-v2-mobile-apps/) |
| 10 | Analytics fires before user accepts consent | `setConsent` called too late or `setAnalyticsCollectionEnabled` left true | Set defaults to `false` in Info.plist/Manifest; only flip via `setConsent` after consent UI | [Google consent guide](https://developers.google.com/tag-platform/security/guides/app-consent) |
| 11 | iOS shows two consent prompts (ATT + your CMP) at same time | Bad ordering | Show CMP first (clear language about analytics), then trigger ATT only if you actually use IDFA. Without IDFA you don't need ATT | [SecurePrivacy](https://secureprivacy.ai/blog/google-consent-mode-mobile) |
| 12 | Logging email/phone in event params | PII in event = KVKK/GDPR violation, also forbidden by Google policy | Never log emails, phone numbers, raw IDs. Use opaque hashed user ID via `setUserId` if needed | [Firebase user-properties](https://firebase.google.com/docs/analytics/user-properties) |
| 13 | `screen_view` events stop after introducing custom router | Auto screen tracking depends on UINavigationController/Activity transitions; Flutter declarative routing breaks it | Add `FirebaseAnalyticsObserver` to GoRouter `observers`; for routes without unique paths (modals, tabs), call `analytics.logScreenView` manually | [FlutterFire screens](https://firebase.flutter.dev/docs/analytics/screens/) |
| 14 | Events double-counted after introducing screen-tracking observer | Both Firebase auto-screen-tracking AND your manual `logScreenView` calls firing | Disable Firebase's auto screen tracking via `FIREBASE_ANALYTICS_AUTO_SCREEN_REPORTING_ENABLED=NO` in Info.plist when using observer | community |

## How to extend
Append new findings as Symptom/Cause/Fix/Source. Bump `last_verified` in [SKILL.md](SKILL.md).
