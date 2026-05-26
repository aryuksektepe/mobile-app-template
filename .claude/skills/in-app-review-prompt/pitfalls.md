# In-App Review — Pitfalls Catalog

| # | Symptom | Cause | Fix | Source |
|---|---|---|---|---|
| 1 | `requestReview()` does nothing on TestFlight / sandbox | Apple blocks SKStoreReviewController for non-App-Store builds — silent no-op | Use `isAvailable()` first; expect false on TestFlight; do NOT debug "the call worked but UI didn't show" — it's by design | [Apple SKStoreReviewController docs](https://developer.apple.com/documentation/storekit/skstorereviewcontroller) |
| 2 | Prompted at first launch → 1-star reviews | No gates; called from onboarding or app launch | Enforce: ≥3 happy moments + ≥7 day install age + ≥90 day cooldown (snippet) | UX research (e.g. Apptentive) |
| 3 | Apple's 3/365 quota burned on low-value moments | Prompted on every happy moment without cooldown | 90-day local cooldown in addition to Apple's API limit (snippet enforces this) | [Apple HIG ratings](https://developer.apple.com/design/human-interface-guidelines/ratings-and-reviews) |
| 4 | Huawei device / Amazon Fire device — prompt never shows | Google Play In-App Review API unavailable without Play Store | `isAvailable()` returns false → fallback `openStoreListing()` (uses platform default browser) | [in_app_review docs](https://pub.dev/packages/in_app_review) |
| 5 | Showing prompt right after a payment / IAP flow | Apple guideline: "do NOT request a review during a transactional flow" | Defer: wait until user is BACK in main app, not on receipt screen | Apple HIG |
| 6 | Prompted user dismissed → app shows custom "Rate us" CTA → annoying | Combining OS prompt + custom CTA in same session | One OR the other per session; never both | UX best practices |
| 7 | Cooldown not respected on app reinstall | SharedPreferences cleared on uninstall; counter reset | Acceptable behavior — fresh install = fresh user; the gates remain (min install age) | this skill's pattern |
| 8 | Custom "How are we doing?" dialog before OS prompt → Apple reject | Apple disallows pre-prompts in 5.6.1 (rating filter) | Trust the OS prompt; no pre-filtering "did you like the app?" dialogs | [Apple 5.6.1](https://developer.apple.com/app-store/review/guidelines/) |
| 9 | Android: stub for emulator / non-Play test | `isAvailable()` returns false on emulators without Play Services | Test on a real device with Play Store installed | [Play In-App Review](https://developer.android.com/guide/playcore/in-app-review) |
| 10 | Settings "Rate us" button hidden because OS quota burned | Settings tap shouldn't go through the gated maybePrompt() | Manual tap → call `openStoreListing()` directly (always works); no gating | this skill's pattern |
