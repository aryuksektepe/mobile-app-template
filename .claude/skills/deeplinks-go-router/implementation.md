# Deep Links — Implementation Guide

## 1. Add packages

```bash
flutter pub add go_router app_links
```

## 2. iOS Universal Links

### 2.1 Apple Developer + Xcode
1. Note your **Team ID** (Apple Developer → Membership) and **Bundle ID** (Xcode).
2. Xcode → Runner target → Signing & Capabilities → **+ Capability → Associated Domains**.
3. Add: `applinks:yourdomain.com`
   - For debug development bypass: also add `applinks:yourdomain.com?mode=developer`
4. (Per flavor) repeat for `yourdomain-dev.com` etc., or use the same domain with different appIDs in AASA.

### 2.2 Host AASA file
1. Use [snippets/apple-app-site-association.json](snippets/apple-app-site-association.json) as template.
2. Replace `TEAMID` (10 chars from membership) and bundle IDs.
3. Define `components` paths matching what your app handles.
4. Host at: `https://yourdomain.com/.well-known/apple-app-site-association`
5. **CRITICAL** serving requirements:
   - **NO file extension** (must be exactly `apple-app-site-association`)
   - `Content-Type: application/json`
   - Valid HTTPS (real cert, not self-signed)
   - **No redirects** (301/302 will fail)
   - <128KB

### 2.3 Verify Apple's CDN cache
After publishing AASA:
- Check the cached version: `https://app-site-association.cdn-apple.com/a/v1/yourdomain.com`
- If outdated, the debug entitlement (`?mode=developer`) bypasses CDN.
- macOS: `swcutil dl -d yourdomain.com`
- Apple's CDN caches for up to 7 days.
- Online validators: branch.io/resources/aasa-validator

### 2.4 Test
Simulator: `xcrun simctl openurl booted https://yourdomain.com/promo/ABC123`
Real device: AirDrop/Notes-paste a Universal Link, tap it.

## 3. Android App Links

### 3.1 Get SHA-256 fingerprints
You need ALL THREE (per flavor):
1. **Debug** keystore: `cd android && ./gradlew signingReport`
2. **Upload** keystore: from your release signing config.
3. **Play App Signing**: Play Console → Your app → Release → Setup → App signing → "App signing key certificate" → SHA-256.

The Play App Signing one is most-missed (works in debug, fails on Play Store). Without it, Android shows the chooser instead of opening the app.

### 3.2 Host assetlinks.json
1. Use [snippets/assetlinks.json](snippets/assetlinks.json) as template.
2. One array entry per `package_name` (multi-flavor → multiple entries).
3. List ALL relevant SHA256 fingerprints in `sha256_cert_fingerprints`.
4. Host at: `https://yourdomain.com/.well-known/assetlinks.json`
5. `Content-Type: application/json`, valid HTTPS, no redirects.

### 3.3 AndroidManifest intent-filter
Add entries from [snippets/AndroidManifest.snippet.xml](snippets/AndroidManifest.snippet.xml). Set `android:autoVerify="true"`.

### 3.4 Verify
```bash
adb shell pm verify-app-links --re-verify com.acme.myapp
adb shell pm get-app-links com.acme.myapp
```

Expected output: `verified` for your domain.

If `unverified` or `not approved`: SHA mismatch (most common) or `assetlinks.json` not reachable.

### 3.5 Test
```bash
adb shell am start -W -a android.intent.action.VIEW -d "https://yourdomain.com/promo/ABC123" com.acme.myapp
```

## 4. Cold-start link capture (BEFORE runApp)

Use [snippets/deeplink_bootstrap.dart](snippets/deeplink_bootstrap.dart). The order is critical:
```dart
WidgetsFlutterBinding.ensureInitialized();
await Firebase.initializeApp(...);
final container = ProviderContainer();
await captureColdStartLink(container);   // BEFORE runApp
runApp(UncontrolledProviderScope(container: container, child: const App()));
```

If you skip this, go_router renders `initialLocation = '/'` first, THEN the link arrives, and the user sees a flash of `/` before navigating. Worse, if `/` triggers redirects, the deep link can race-condition into being lost.

## 5. go_router with auth gate

Use [snippets/router_with_deeplinks.dart](snippets/router_with_deeplinks.dart). Key features:
- `sanitizeDeepLink` whitelists hosts + path patterns.
- Rejects `javascript:`, `data:`, `file:` schemes.
- `return=` query param preserves intended destination through login.
- Bails early on `/login` to prevent infinite redirect.

## 6. Warm-start subscription

In your top-level App widget:
```dart
@override
void initState() {
  super.initState();
  _sub = subscribeToWarmLinks(ref);
}
@override
void dispose() {
  _sub?.cancel();
  super.dispose();
}
```

## 7. Deferred deep linking (Firebase Dynamic Links replacement)

FDL was shut down **August 25, 2025**. Options:

| Option | Notes |
|---|---|
| **Branch.io** | Most popular FDL replacement. Free tier. NativeLink for IDFA-less attribution. |
| **AppsFlyer OneLink** | Google officially recommends. Paid. |
| **Adjust / Singular / Kochava / Airbridge** | Other paid MMPs. |
| **Roll-your-own** | Short-link service + clipboard handoff (iOS) + Play Install Referrer (Android). Acceptable if your only need is "carry promo code through install." |

This skill does NOT integrate any of these — pick one and follow their docs.

## 8. Verify

Run [checklist.md](checklist.md). Critical:
- AASA validator passes.
- `adb shell pm get-app-links` shows verified.
- Cold-start, warm-start, terminated all tested.
- Sanitization rejects malicious schemes.
