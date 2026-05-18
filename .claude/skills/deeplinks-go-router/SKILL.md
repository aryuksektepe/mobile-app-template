---
name: deeplinks-go-router
description: Universal Links (iOS) + App Links (Android) + go_router 17.x integration. AASA + assetlinks.json hosting, multi-flavor SHA support, cold-start vs warm-start handling, auth-aware redirect with return-to, URL whitelist + sanitization. Firebase Dynamic Links is DEAD as of Aug 25 2025 — use this skill instead.
triggers: [deep link, deeplink, universal link, app link, go_router, app_links, aasa, assetlinks, firebase dynamic links, branch.io, deferred deep link, url scheme, custom url scheme, CFBundleURLTypes, -10814, black screen deeplink, InheritedGoRouter, cold start deeplink simulator]
platforms: [ios, android]
last_verified: 2026-05-18
flutter_min: "3.22.0"
ios_min: "12.0"
android_min_sdk: 21
package_versions:
  go_router: "^17.2.3"
  app_links: "^7.0.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# Deep Links — Universal Links + App Links + go_router

## What this skill does

- Wires `app_links` 7.x (replacement for deprecated `uni_links` and dead `firebase_dynamic_links`).
- Hosts AASA (iOS) + assetlinks.json (Android) at `/.well-known/`.
- Multi-flavor SHA support (debug + upload + Play App Signing).
- go_router 17.x with auth-aware redirect (`return=/<encoded path>`).
- URL whitelist + sanitization (`/promo/[A-Z0-9]{6,16}`, UUID/integer ID validation).
- Cold-start link captured BEFORE `runApp` to prevent race with `go_router` initialLocation.
- Stream subscription for warm-start + post-launch links.
- Documented options for **deferred deep linking** (Firebase Dynamic Links replacements).

## What this skill does NOT do

- Does NOT cover deferred deep linking implementation — that needs Branch/AppsFlyer/AdJust SDK or clipboard fallback. Lists options only.
- Does NOT handle web/PWA deep links.

## Decision tree

**Q1: Need deferred deep linking (carry param through install)?**
- YES → use **Branch.io** (most popular FDL replacement, free tier) OR **AppsFlyer OneLink** (Google-recommended).
- NO → standard Universal Links + App Links is sufficient. (Most apps DO need deferred for promo/referral.)

**Q2: Multiple flavors with different package names?**
- YES → multi-entry `assetlinks.json` array (one object per package_name); separate AASA per flavor's app ID.
- NO → single entry per file.

**Q3: Let go_router handle deep links automatically OR manage with `app_links`?**
- AUTO (recommended for most cases) — go_router automatically wired for incoming links via `WidgetsApp.router`.
- MANUAL — use `app_links` directly when you need full control over back stack (also disable Flutter's default deep-link plumbing).

## Quick start

```bash
flutter pub add go_router app_links
```

Hosting:
- iOS: `https://yourdomain.com/.well-known/apple-app-site-association` (NO file extension, `Content-Type: application/json`, no redirects)
- Android: `https://yourdomain.com/.well-known/assetlinks.json`

## Code patterns

| Need | File |
|---|---|
| Cold-start link capture + Riverpod provider | [snippets/deeplink_bootstrap.dart](snippets/deeplink_bootstrap.dart) |
| go_router with auth gate + sanitization | [snippets/router_with_deeplinks.dart](snippets/router_with_deeplinks.dart) |
| iOS AASA file template | [snippets/apple-app-site-association.json](snippets/apple-app-site-association.json) |
| Android assetlinks template | [snippets/assetlinks.json](snippets/assetlinks.json) |
| AndroidManifest intent-filter | [snippets/AndroidManifest.snippet.xml](snippets/AndroidManifest.snippet.xml) |

For full setup (Apple Associated Domains capability, AASA CDN cache verification, Android pm verify-app-links) → [implementation.md](implementation.md).

## Known pitfalls

→ [pitfalls.md](pitfalls.md) (16 entries). Top 5:
1. AASA served as `application/octet-stream` or with `.json` extension → Universal Links open Safari instead.
2. Apple CDN caches AASA up to 7 days; debug requires `?mode=developer`.
3. Android App Links chooser instead of direct open → SHA mismatch (Play App Signing).
4. Deep link to gated route → infinite redirect; check `loc.startsWith('/login')` early.
5. Cold-start link fires twice — `getInitialAppLink()` AND stream firing for same link.

## Verification

→ [checklist.md](checklist.md) (16 items: AASA validator passes, `pm get-app-links` shows verified, cold-start tested, deep-link sanitization rejects javascript: schemes).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-10 against `go_router` 17.2.3, `app_links` 7.0.0
- Depends on: (none)
