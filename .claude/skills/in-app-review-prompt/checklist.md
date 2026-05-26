# In-App Review — Verification Checklist

- [ ] `in_app_review` 2.x in dependencies
- [ ] `recordHappyMoment()` called from positive-outcome handlers ONLY (not from errors)
- [ ] `maybePrompt()` gated by ≥3 happy moments + ≥7 day install age + ≥90 day cooldown
- [ ] NEVER called at app launch / onboarding / inside a transactional flow
- [ ] Sandbox / TestFlight behavior documented (iOS API silently no-ops — by design)
- [ ] `isAvailable()` checked; falls back to `openStoreListing()` on Huawei / Amazon / iOS sandbox
- [ ] Settings → "Rate us" → `openStoreListing()` directly (bypasses gates)
- [ ] No pre-prompt dialog ("Did you like?") — Apple 5.6.1 rejects this
- [ ] Telemetry event `review_prompt_shown` for analytics correlation (NOT the outcome — Apple/Google don't expose it)
- [ ] Real-device test (Play-equipped Android + production-build iOS)
