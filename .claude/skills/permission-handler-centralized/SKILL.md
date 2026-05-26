---
name: permission-handler-centralized
description: Centralized PermissionService via `permission_handler` 11.x — single point for camera, photos, location, contacts, microphone, notifications, ATT. Soft-ask + just-in-time pattern (NOT permission blast at launch), settings deep link when denied permanently, iOS Info.plist usage strings checklist, Android 13+ POST_NOTIFICATIONS + media partial photo access. Use whenever any new feature needs OS permission.
triggers: [permission, permission_handler, runtime permission, camera permission, location permission, photos permission, just in time permission, soft ask, settings deep link, Info.plist usage description, NSCameraUsageDescription, openAppSettings, permanentlyDenied]
platforms: [ios, android]
last_verified: 2026-05-26
flutter_min: "3.22.0"
package_versions:
  permission_handler: "^11.3.1"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# Centralized Permission Service

## What this skill does

- One `PermissionService` for the whole app — no scattered `Permission.camera.request()` calls.
- **Soft-ask + just-in-time** pattern (per `onboarding-flow`): explain THE BENEFIT, ask at the moment of need, never blast at app launch.
- iOS Info.plist usage strings checklist (every permission requires a string; missing = silent crash).
- Android 13+ runtime POST_NOTIFICATIONS handling.
- Android 14+ partial photo access (READ_MEDIA_VISUAL_USER_SELECTED) — UI must handle the "selected photos only" case.
- `permanentlyDenied` → modal with `openAppSettings()` deep link.
- Per-permission Riverpod provider exposing current `PermissionStatus`.
- Cross-skill coordination: `notifications-fcm` handles notification permission, `ios-att-prompt` handles ATT — this skill centralizes everything ELSE.

## What this skill does NOT do

- Does NOT handle ATT (different framework — `ios-att-prompt`).
- Does NOT handle notification permission deeply (`notifications-fcm` has the channel-creation context).
- Does NOT pick the soft-ask copy (UX territory).

## Decision tree

**Q1: Hard ask, soft ask, or in-context?**
- HARD ASK (`Permission.X.request()` straight) — only for the next-second-blocked flow (e.g. user just tapped "Take photo").
- SOFT ASK (custom screen explaining benefit BEFORE system prompt) — recommended for sensitive (camera/photos/location/contacts).
- IN-CONTEXT — the feature itself explains "we need X to do Y", then on tap → soft ask → system prompt.

**Q2: Permanent denial — modal or banner?**
- MODAL with "Ayarlardan aç" CTA → `openAppSettings()`. User must consciously dismiss.
- BANNER — softer but lower conversion. Use for non-critical permissions.

## Quick start

```bash
flutter pub add permission_handler
```

Apply [snippets/permission_service.dart](snippets/permission_service.dart). Add Info.plist usage strings (see [snippets/Info.plist.snippet.xml](snippets/Info.plist.snippet.xml)) and AndroidManifest perms.

## Code patterns

| Need | File |
|---|---|
| PermissionService + Riverpod providers | [snippets/permission_service.dart](snippets/permission_service.dart) |
| iOS Info.plist usage strings (all common) | [snippets/Info.plist.snippet.xml](snippets/Info.plist.snippet.xml) |

## Known pitfalls

→ [pitfalls.md](pitfalls.md). Top 5:
1. iOS Info.plist missing `NSCameraUsageDescription` → call crashes silently on first invoke.
2. Android 13+ `POST_NOTIFICATIONS` permission ignored because targeting SDK < 33.
3. `permanentlyDenied` user can't be re-prompted by `request()` — only `openAppSettings()` works.
4. Permission requested before user understood why (blast at launch) → ~30% lower opt-in.
5. Android 14 partial photo access — `Permission.photos.request()` returns `limited`, app reads as `granted`-equivalent but only sees user-selected photos.

## Verification

→ [checklist.md](checklist.md).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-26
- Depends on: (none; coordinates with `notifications-fcm`, `ios-att-prompt`)
