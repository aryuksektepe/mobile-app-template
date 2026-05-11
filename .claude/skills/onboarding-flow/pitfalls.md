# Onboarding Flow — Pitfalls Catalog

14 entries from Flutter community + 2025 mobile-onboarding research.

| # | Symptom | Cause | Fix | Source |
|---|---|---|---|---|
| 1 | Onboarding skipped after iOS reinstall | iOS Keychain persists across uninstall; if you stored "completed" flag in flutter_secure_storage, it survives | Store flag in `shared_preferences` (cleared on uninstall); wipe secure storage on detected first launch | [dev.to](https://dev.to/isurujn/beware-of-fluttersecurestorage-on-ios-m6e) |
| 2 | Onboarding re-shown after every app update | Storing flag in iCloud-synced KV store; or migration logic accidentally wipes prefs | Use `shared_preferences` plain key; never wipe in migration logic | [LeanCode](https://leancode.co/glossary/secure-storage-in-flutter) |
| 3 | ATT prompt never re-shows | iOS only allows the prompt **once** per install; if user said no, you cannot re-prompt | Time the prompt for the right narrative moment (post-value, ~6-30s post-launch); use a soft pre-prompt first | [Purchasely 2025](https://www.purchasely.com/blog/att-opt-in-rates-in-2025-and-how-to-increase-them) |
| 4 | High drop-off on screen 4+ | Onboarding too long; 21-72% abandon when >5 screens | Cap at 3-5 screens, time-to-value <60s | [Setgreet](https://www.setgreet.com/blog/what-the-numbers-actually-say-about-mobile-app-onboarding-(and-what-to-track)) |
| 5 | Notification permission denied at 90%+ | Asking on first screen with no context | Soft-ask with explanation FIRST, defer OS prompt to relevant moment | [OneSignal](https://onesignal.com/blog/how-to-get-permissions-for-apples-app-tracking-transparency/) |
| 6 | Reinstalling test users skip onboarding | Logout doesn't reset onboarding state | Add a debug menu "Reset onboarding" calling `OnboardingController.reset()`; ensure logout doesn't wipe `is_first_app_launch` (only secure tokens) | community |
| 7 | App size jump from 12MB Lottie | Bundling all illustrations as raw assets | Use Lottie compressed or `flutter_svg`; lazy-load past first slide | community |
| 8 | Accessibility scan failures | No `Semantics` labels; relying on visual-only cues | Wrap each page in `Semantics(label: ...)`, ensure 4.5:1 contrast, support 200% text scaling | Material guidance |
| 9 | RTL layout broken | Hardcoded `Row` directions, `EdgeInsets.only(left:)` | Use `EdgeInsetsDirectional`, `Directionality.of(ctx)`, mirror page indicator | Flutter docs |
| 10 | A/B variant flickers / shows control then variant | `RemoteConfig.fetchAndActivate()` not awaited before first paint | Block splash on a Future that includes RC; cap at 4s timeout | [Firebase RC docs](https://firebase.google.com/docs/remote-config) |
| 11 | "Skip" button missing → App Store reviewer rejects (perceived dark pattern) | Hidden or grayed-out skip | Always render Skip visibly on every step; never tiny gray text | UX consensus |
| 12 | Deferred deep link gets eaten by onboarding | `/promo/abc` lands during cold start, but onboarding redirects to `/onboarding` | Stash incoming link in `pendingDeepLinkProvider`, replay AFTER `complete()` | community |
| 13 | User sees onboarding twice on Android because of Activity recreate | State held in widget instead of provider | Persist step in shared_preferences, restore from there | Flutter community |
| 14 | Variant assignment changes for the same user | Using `Random()` in app instead of RC's sticky bucketing | Always rely on Firebase RC + Analytics audience for sticky assignment | [Firebase A/B](https://firebase.google.com/docs/ab-testing) |
