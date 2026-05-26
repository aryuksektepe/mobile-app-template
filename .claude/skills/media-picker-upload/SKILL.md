---
name: media-picker-upload
description: Image / video pick from camera or gallery → crop → resize → upload to Firebase Storage or Supabase Storage. Covers iOS Info.plist usage strings, Android 13+ READ_MEDIA_* + Android 14 partial photo access (limited), EXIF orientation correction (iOS rotates portraits incorrectly without fix), MIME guard, file size pre-check (don't upload 50MB), progress reporting, retry on flaky network. Use whenever the app accepts user-uploaded media.
triggers: [image picker, image_picker, camera, gallery, photo upload, firebase storage, supabase storage, exif orientation, image rotation, file size limit, mime type, image crop, photo limited access, picker]
platforms: [ios, android]
last_verified: 2026-05-26
flutter_min: "3.22.0"
package_versions:
  image_picker: "^1.1.2"
  image_cropper: "^8.0.2"
  flutter_image_compress: "^2.3.0"
  firebase_storage: "^12.0.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: [permission-handler-centralized]
---

# Media Picker + Upload

## What this skill does

- `image_picker` 1.x for camera + gallery (single + multi).
- `image_cropper` for aspect-locked crop (avatar = 1:1, banner = 16:9, etc.).
- `flutter_image_compress` for client-side resize before upload (cap at e.g. 2000px longest side).
- EXIF orientation fix (iOS portraits land rotated 90° otherwise — package handles when configured).
- MIME guard + max file size pre-check.
- Firebase Storage OR Supabase Storage upload with progress stream + resumable retry.
- iOS Info.plist usage strings (camera + photos) via `permission-handler-centralized`.
- Android 13+ READ_MEDIA_IMAGES / VIDEO permission; Android 14 partial photo access (`limited`).

## What this skill does NOT do

- Does NOT cover advanced video editing (trim/transcode) — use ffmpeg_kit_flutter separately.
- Does NOT handle profile-avatar UI flow (separate per-app pattern).

## Decision tree

**Q1: Camera, gallery, or both?**
- BOTH (most common) — ActionSheet picker → "Take photo" / "Choose from gallery".
- GALLERY ONLY — `image_picker_for_web`-friendly.

**Q2: Single or multi?**
- SINGLE for avatar/document.
- MULTI for post composition / album upload — use `image_picker.pickMultiImage()`.

**Q3: Compress on client or server?**
- CLIENT (recommended) — saves bandwidth + storage; user sees instant upload progress.
- SERVER — bandwidth-heavy uploads; only when you need original for processing.

## Quick start

```bash
flutter pub add image_picker image_cropper flutter_image_compress firebase_storage
```

Apply [snippets/media_picker_service.dart](snippets/media_picker_service.dart). Wire `permission-handler-centralized` for camera/photos pre-asks.

## Code patterns

| Need | File |
|---|---|
| Pick + crop + compress + upload service | [snippets/media_picker_service.dart](snippets/media_picker_service.dart) |

## Known pitfalls

→ [pitfalls.md](pitfalls.md). Top 5:
1. iOS Portrait photos uploaded sideways → EXIF orientation byte not honored by server.
2. Android 14 partial photo access (`limited`) — user picked 5 photos; gallery UI shows "no photos" if you only check `granted`.
3. 50MB video upload kills the app on low-RAM devices — must compress / reject pre-upload.
4. Firebase Storage upload with no `metadata.contentType` → file served as `application/octet-stream` → browsers refuse to render.
5. Re-upload after network drop creates duplicate — use `Reference.putFile(...)` with `resumable: true` OR de-dupe by client hash.

## Verification

→ [checklist.md](checklist.md).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-26
- Depends on: `permission-handler-centralized`
