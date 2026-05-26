# Media Picker + Upload — Pitfalls Catalog

| # | Symptom | Cause | Fix | Source |
|---|---|---|---|---|
| 1 | iOS portrait photo uploaded sideways | EXIF orientation byte not auto-corrected by some compressors / by server | `flutter_image_compress` with `autoCorrectionAngle: true` (default); strip EXIF after fix | [EXIF orientation](https://exiv2.org/tags.html) |
| 2 | Android 14 partial photo access — gallery shows "no photos" | UI checks `isGranted` but `isLimited` is the real success state for partial access | Treat `isLimited` as allowed; show "Add more" CTA → `Permission.photos.request()` | [Android partial photo access](https://developer.android.com/about/versions/14/changes/partial-photo-video-access) |
| 3 | 50MB video kills the app | Read into memory without size check | Pre-validate `file.lengthSync()` BEFORE compress; reject + toast if > limit | this skill snippet |
| 4 | Browsers won't display uploaded image (download instead) | Firebase Storage `contentType` defaulted to `application/octet-stream` | Set `SettableMetadata(contentType: 'image/jpeg')` explicitly per snippet | [Firebase Storage metadata](https://firebase.google.com/docs/storage/flutter/file-metadata) |
| 5 | User uploads same file twice → 2 storage objects | No de-dupe; resumable upload doesn't help across sessions | Hash file (SHA-256) → use hash as object path; second upload short-circuits to existing URL | content-addressable storage |
| 6 | HEIC photo from iPhone fails to display on Android (server stored as .heic) | Android Chrome doesn't render HEIC | Convert HEIC → JPEG in compress step (`format: CompressFormat.jpeg`); per snippet | image_compress docs |
| 7 | Upload progress stuck at 99% forever | `snapshotEvents` stream emits per-byte but state never transitions to `success` if `getDownloadURL` is slow | Listen for `TaskState.success` AND THEN `await ref.getDownloadURL()` (per snippet) | [Firebase Storage flutter](https://firebase.google.com/docs/storage/flutter/upload-files) |
| 8 | iOS Info.plist `NSPhotoLibraryUsageDescription` missing → crash on first pick | Apple requires usage string before gallery access | Add it + `NSCameraUsageDescription` (see `permission-handler-centralized`) | Apple docs |
| 9 | Upload runs while app backgrounded → fails on iOS without Background Modes | iOS suspends networking when app goes to background | Either restart upload on foreground OR enable Background Modes → Background Fetch | iOS background docs |
| 10 | Server-side moderation/scan rejects upload but client shows success | No `await uploadComplete` check; relied on initial PUT response | Always `await getDownloadURL()` AND make a follow-up GET to confirm the URL serves 200 | this skill's pattern |
