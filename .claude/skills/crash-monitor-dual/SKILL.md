---
name: crash-monitor-dual
description: Dual crash monitoring — Firebase Crashlytics (free, NDK-strong, Apple-friendly) + Sentry (rich breadcrumbs, releases, performance, source-mapped Dart). Wires both error handlers, PII scrubbing, opaque user IDs, dSYM/symbol uploads. Use whenever crash reporting is required (production-grade apps).
triggers: [crashlytics, sentry, crash report, error tracking, error monitoring, dsym, obfuscation, source map, performance monitoring, breadcrumbs]
platforms: [ios, android]
last_verified: 2026-05-10
flutter_min: "3.7.0"
ios_min: "13.0"
android_min_sdk: 21
package_versions:
  firebase_crashlytics: "^5.2.0"
  sentry_flutter: "^9.20.0"
  sentry_dart_plugin: "latest"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: [firebase-core-setup]
---

# Crash Monitoring — Crashlytics + Sentry (dual)

## What this skill does

- Wires BOTH Firebase Crashlytics AND Sentry to capture every Flutter error path:
  - `FlutterError.onError` (framework errors)
  - `PlatformDispatcher.instance.onError` (async uncaught)
  - Native iOS/Android crashes (Crashlytics owns these reliably)
- **PII-safe by default**: opaque hashed user IDs, `beforeSend` scrubber removes emails/tokens/headers.
- **Symbol uploads**: dSYM (iOS Crashlytics auto), Sentry source maps (`sentry_dart_plugin`).
- **Release tracking**: ties crashes to build version via `package_info_plus`.
- **Default-off in debug** to avoid noise.
- Disabled until consent (analytics consent flag controls Crashlytics collection).

## Why dual?

| Need | Crashlytics | Sentry |
|---|---|---|
| Free tier | Unlimited | 5K events/mo |
| Native iOS/Android | Best-in-class (signal-handler level) | Good but Crashlytics wins on edge cases |
| Dart stack symbolication | Auto with FlutterFire CLI | Auto with `sentry_dart_plugin` |
| Breadcrumbs | Custom keys (limited) | Rich (HTTP, navigation, user actions) |
| Releases / dist | Build number tagging | First-class release tracking |
| Performance / transactions | None | Yes |
| Session Replay | None | Yes (mobile since 2024) |
| Apple-friendly | Yes (App Store Connect linking) | OK |
| Daily triage UX | Console (functional) | Sentry UI is better |

Crashlytics catches everything reliably (insurance). Sentry is the daily triage tool.

## What this skill does NOT do

- Does NOT design alerting rules (Velocity Alerts, Sentry alert rules) — that's ops config.
- Does NOT integrate with PagerDuty / Slack — those are dashboard-side.
- Does NOT capture native iOS/Android crashes from FFI/method channels into Sentry (Crashlytics does).

## Decision tree

**Q1: Are you OK paying ~$26/mo for Sentry Team plan after 5K events?**
- YES → dual setup (this skill).
- NO → Crashlytics-only. Skip Sentry portions; still solid for production.

**Q2: Source data residency requirement (KVKK strict reading)?**
- YES → use Sentry EU region (`*.de.sentry.io`); Crashlytics has no EU residency option, declare cross-border in privacy policy.

## Quick start

```bash
flutter pub add firebase_crashlytics sentry_flutter
flutter pub add --dev sentry_dart_plugin
flutterfire reconfigure       # adds iOS dSYM upload script
```

## Code patterns

| Need | File |
|---|---|
| Combined init in main() | [snippets/crash_bootstrap.dart](snippets/crash_bootstrap.dart) |
| PII-scrubbing beforeSend | [snippets/sentry_scrubber.dart](snippets/sentry_scrubber.dart) |
| Set opaque hashed user ID | [snippets/identify_user.dart](snippets/identify_user.dart) |
| `pubspec.yaml` sentry-dart-plugin block | [snippets/pubspec_sentry.yaml](snippets/pubspec_sentry.yaml) |

For full setup (iOS dSYM verification, R8/ProGuard mapping upload, release tagging) → [implementation.md](implementation.md).

## Known pitfalls

→ [pitfalls.md](pitfalls.md) (14 entries). Top 5:
1. Both services report same crash twice — accept it OR assign primary owner per type.
2. Obfuscated stack `xxx.dart:1` in Crashlytics — symbols not uploaded.
3. PII in Sentry events — set `sendDefaultPii: false` + add `beforeSend` scrubber.
4. `runZonedGuarded` is legacy — use `PlatformDispatcher.onError` instead.
5. Test crash needs app restart to upload — wait 5 min, check both dashboards.

## Verification

→ [checklist.md](checklist.md) (16 items: dSYM uploaded, mapping.txt uploaded, test crash visible in both, no PII in payloads).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-10 against `firebase_crashlytics` 5.2.0 + `sentry_flutter` 9.20.0
- Depends on: `firebase-core-setup`
