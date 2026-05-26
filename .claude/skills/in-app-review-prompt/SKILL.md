---
name: in-app-review-prompt
description: In-app rating prompt via `in_app_review` 2.x — Apple SKStoreReviewController + Google Play In-App Review API. Rate-limit aware (Apple max 3 prompts / 365 days per app, Google opaque quota), shows ONLY at high-positive moments (post-success, never on error), NEVER on launch / never before user got value. Includes "happy path detector" + fallback "rate us in store" deep link if API throttled.
triggers: [in app review, in_app_review, rate us, rate the app, SKStoreReviewController, requestReview, RequestReviewFlow, rating prompt, app review prompt, when to ask for rating]
platforms: [ios, android]
last_verified: 2026-05-26
flutter_min: "3.22.0"
package_versions:
  in_app_review: "^2.0.10"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# In-App Review Prompt

## What this skill does

- Wires `in_app_review` 2.x — abstracts SKStoreReviewController (iOS) + Google Play In-App Review API (Android).
- **Happy-path detector**: tracks "positive moments" (purchase success, content completion, milestone reached) and triggers only after ≥ N events.
- **Cooldown**: 90+ day local cooldown after last prompt regardless of platform API behavior (extra defensive — Apple's 3/year + Google's opaque quota).
- **Never on first launch / never after error / never inside transactional flow**.
- Fallback: if `isAvailable()` returns false (iOS quota burned, sandbox), offer "Rate us in App Store" via `openStoreListing()`.
- Localized prompt is OS-native (no copy needed — OS uses store metadata).

## What this skill does NOT do

- Does NOT replace user-feedback widgets (in-app feedback form is separate UX).
- Does NOT track NPS / CSAT (use a separate skill / analytics event).

## Decision tree

**Q1: When to count a "positive moment"?**
- After a SUCCESSFUL outcome: completed lesson, purchase confirmed, content saved, milestone hit.
- NEVER after a payment failure / crash / error toast.
- NEVER after sign-up / first launch (user hasn't gotten value yet).

**Q2: How many positive moments before prompting?**
- 3-5 is a reasonable threshold; tune per app.
- Plus: minimum app age 7-14 days since install.
- Plus: at least 2 distinct sessions.

**Q3: API throttled — show OS-native again or fallback?**
- FALLBACK to "Rate us in App Store" CTA + `openStoreListing()` (opens store deep link).

## Quick start

```bash
flutter pub add in_app_review
```

Apply [snippets/review_prompt_service.dart](snippets/review_prompt_service.dart). Trigger from your "positive moment" handlers.

## Code patterns

| Need | File |
|---|---|
| ReviewPromptService with happy-path detector + cooldown | [snippets/review_prompt_service.dart](snippets/review_prompt_service.dart) |

## Known pitfalls

→ [pitfalls.md](pitfalls.md). Top 5:
1. iOS sandbox / TestFlight builds — `requestReview()` does NOTHING (Apple blocks for non-App-Store builds). Logs say success but nothing shows.
2. Prompted too early (first launch) → user 1-stars out of annoyance.
3. Apple's hard limit: 3 prompts per 365 days; subsequent calls silently no-op. If you exceed it, you waste a high-value moment.
4. No cooldown → prompted user every "positive moment" → annoyed.
5. Google Play In-App Review fails on devices without Play Store (Huawei AppGallery, Amazon Fire) — `isAvailable()` returns false; need fallback.

## Verification

→ [checklist.md](checklist.md).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-26
- Depends on: (none)
