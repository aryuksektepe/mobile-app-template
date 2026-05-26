# Media Picker + Upload — Verification Checklist

- [ ] `image_picker` + `image_cropper` + `flutter_image_compress` + storage SDK in deps
- [ ] iOS Info.plist: `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` + `NSPhotoLibraryAddUsageDescription` (save back to gallery) — see `permission-handler-centralized`
- [ ] Android perms: `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, optionally `READ_MEDIA_VISUAL_USER_SELECTED` for Android 14
- [ ] `targetSdkVersion >= 33` so Android 13 media-perm prompt fires
- [ ] EXIF orientation fix: `flutter_image_compress` with `autoCorrectionAngle: true`
- [ ] File size pre-check (reject before reading into memory)
- [ ] MIME type guard (allowlist: jpeg/png/webp/heic)
- [ ] HEIC → JPEG conversion in compress step (Android Chrome compat)
- [ ] Firebase Storage `SettableMetadata(contentType:)` set per upload
- [ ] Progress stream wired to UI loader; cancel button works
- [ ] De-dupe: same file uploaded twice → same URL (hash-based path)
- [ ] Real-device test: camera + gallery + multi + portrait orientation + HEIC source
- [ ] Android 14 partial-access test: pick 3 photos → UI works
- [ ] iOS background test: upload mid-flow → background app → foreground → upload completes or restarts cleanly
