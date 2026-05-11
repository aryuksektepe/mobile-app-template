# App Store Review Guidelines — Reference Snapshot

> Apple updates these continuously. Re-fetch from official source before each release: https://developer.apple.com/app-store/review/guidelines/

This file is a **summary of items most commonly causing rejections** for compliance + release-manager agents to reference.

**Last reviewed:** 2026-05-10 (verify against official docs before relying)

---

## Most Common Rejection Reasons (2026)

### 4.3 — Spam / Duplicate
- Don't ship multiple variants of the same app
- Each app must have substantive functionality

### 2.3 — Accurate Metadata
- Screenshots must show actual app UI
- Description must accurately represent the app
- Keywords field must not be misleading

### 4.7.2 — AI-Generated Content (NEW 2026)
- AI-generated content must be disclosed
- User must know when interacting with AI

### 4.8 — Sign In with Apple
- If app offers any third-party social login (Google, Facebook, Twitter, etc.), Sign In with Apple MUST be offered as equivalent option

### 5.1 — Privacy
- 5.1.1 — Privacy Policy URL required
- 5.1.1(v) — In-app account deletion required (since June 2022)
- 5.1.2 — Data Use & Sharing — must match Privacy Manifest declarations

### 1.1 — Safety / Objectionable Content
- No user-generated content without moderation
- No discriminatory content
- No physical harm encouragement

### 5.4 — VPN apps
- Must not violate user privacy

### App Tracking Transparency (ATT)
- Required prompt before any tracking
- "Tracking" = linking user/device data with data from other companies' apps/sites for advertising

### Privacy Manifest (`PrivacyInfo.xcprivacy`)
- Required since May 1, 2024
- Required Reason API declarations for: UserDefaults, FileTimestamp, SystemBootTime, DiskSpace, ActiveKeyboard
- SDK signature requirement for ~80 listed SDKs (Firebase, OneSignal, Mixpanel, etc.)

### Age Rating (NEW iOS 26+)
- New 4+/9+/13+/16+/18+ system since iOS 26
- Deadline: Jan 31, 2026 — must answer new questionnaire

---

## Pre-Submission Checklist (per release)

- [ ] Privacy Policy URL hosted publicly + in app Settings
- [ ] In-app account deletion path ≤2 taps from Settings
- [ ] Privacy Manifest present + Required Reason APIs declared
- [ ] Tracking domains list complete in Privacy Manifest
- [ ] ATT prompt present + correct copy
- [ ] Privacy Nutrition Labels match Manifest
- [ ] Sign In with Apple present (if other social logins)
- [ ] Age rating questionnaire answered (post Jan 2026)
- [ ] Demo account created + credentials in review notes
- [ ] Review notes fill: how to test, region restrictions, IAP sandbox
- [ ] AI-generated content disclosed (if applicable)
- [ ] Screenshots use real UI

---

## When to Re-Fetch

- Before each major release
- When Apple announces guideline updates (typically WWDC + ad-hoc)
- When a rejection occurs (the rejection email cites the specific rule)

Source: https://developer.apple.com/app-store/review/guidelines/
