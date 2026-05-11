# Google Play Developer Program Policies — Reference Snapshot

> Google updates these continuously. Re-fetch from official source before each release: https://play.google.com/about/developer-content-policy/

This file is a **summary of items most commonly causing rejections** for compliance + release-manager agents to reference.

**Last reviewed:** 2026-05-10 (verify against official docs before relying)

---

## Most Common Rejection Reasons (2026)

### Privacy & Security
- **Account Deletion** (mandatory since Dec 2023)
  - In-app deletion path ≤2 taps from Settings
  - Web URL provided to Play Console (separate from in-app)
  - Data deletion timeline disclosed
- **Data Safety Form** (mandatory)
  - Must accurately declare all data collection + sharing
  - Encryption-in-transit claim must be true
  - Per-data-type: collected vs shared, optional vs required, purposes
- **Permissions**
  - High-risk permissions (SMS, Call Log, Location, etc.) require justification
  - Avoid requesting unused permissions
- **Sensitive User Data** — must be necessary for app functionality

### User Data
- **Personal & Sensitive Data Policy**
  - SCRP-compliant disclosure required
  - In-app prominent disclosure for sensitive data (location, contacts)

### Misleading Behavior
- **Deceptive Behavior**
  - App must do what it says
  - No fake reviews / install manipulation
- **Impersonation** — don't impersonate other apps/brands

### Monetization & Ads
- **Subscriptions**
  - Cancellation must be in-app (≤2 taps)
  - Auto-renewal disclosure required
- **Ads**
  - Disruptive ads forbidden (close button required after 5s)
  - Out-of-context ads forbidden (no ads in lock screen, etc.)

### Children's Apps (if Designed for Families)
- COPPA compliance
- No behavioral advertising
- Limited data collection
- Family Policy Center adherence

### Health Apps
- Medical claims require validation
- Disclaimer requirements

### Android Vitals (affects ranking)
- Crash-free sessions ≥99.5% target
- ANR rate <0.47% (Play "bad behavior" threshold)
- Slow start (cold start) impacts ranking

### Recent (2025-2026 Updates)
- Android ID treated as Device Identifier in Data Safety (April 2025)
- Generative AI app policy expansion (2026)
- Mandatory privacy declarations for SDK data sharing

---

## Pre-Submission Checklist (per release)

- [ ] Data Safety form filled accurately
- [ ] Account deletion link provided (web URL + in-app path)
- [ ] Privacy Policy URL hosted publicly
- [ ] All permissions justified
- [ ] Sensitive data prominent disclosure (if applicable)
- [ ] Subscriptions: in-app cancellation present
- [ ] Children's policy adherence (if applicable)
- [ ] Android Vitals on staging build: crash-free ≥99.5%, ANR <0.47%
- [ ] AAB built with `--obfuscate --split-debug-info`
- [ ] Symbol upload to Play Console (mapping.txt) + Crashlytics
- [ ] IARC age rating questionnaire answered
- [ ] Localized listings for all supported languages
- [ ] Screenshots: phone + 7" tablet + 10" tablet (recommended)

---

## When to Re-Fetch

- Before each major release
- When Google announces policy updates (Play Console notifications)
- When a rejection occurs
- Quarterly review minimum

Source: https://play.google.com/about/developer-content-policy/
