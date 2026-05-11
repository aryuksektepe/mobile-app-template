# Deep Links — Verification Checklist

## Setup
- [ ] `go_router ^17.2.3` + `app_links ^7.0.0` resolved
- [ ] iOS deployment target ≥ 12.0
- [ ] Android `minSdk = 21`

## iOS Universal Links
- [ ] Associated Domains capability added in Xcode with `applinks:yourdomain.com`
- [ ] Debug entitlement also has `applinks:yourdomain.com?mode=developer`
- [ ] AASA file at `https://yourdomain.com/.well-known/apple-app-site-association` (NO extension)
- [ ] Served with `Content-Type: application/json`, no redirects
- [ ] AASA validator passes (branch.io/resources/aasa-validator)
- [ ] Apple's CDN cache shows current content: `https://app-site-association.cdn-apple.com/a/v1/yourdomain.com`
- [ ] `xcrun simctl openurl booted https://yourdomain.com/promo/ABC123` opens app

## Android App Links
- [ ] `assetlinks.json` at `https://yourdomain.com/.well-known/assetlinks.json`
- [ ] Contains entries for ALL flavor package_names
- [ ] Each entry contains debug + upload + Play App Signing SHA256 fingerprints
- [ ] AndroidManifest intent-filter has `android:autoVerify="true"`
- [ ] `adb shell pm get-app-links com.acme.myapp` shows `verified` for the domain
- [ ] `adb shell am start -W -a android.intent.action.VIEW -d "https://yourdomain.com/promo/ABC123" com.acme.myapp` opens app

## Code wiring
- [ ] `captureColdStartLink()` called BEFORE `runApp()`
- [ ] `subscribeToWarmLinks()` set up in top-level App widget; cancelled on dispose
- [ ] `pendingDeepLinkProvider` consumed + cleared in go_router redirect
- [ ] `sanitizeDeepLink` whitelists hosts + path patterns
- [ ] `sanitizeDeepLink` rejects `javascript:`, `data:`, `file:` schemes (test: pass `Uri.parse('javascript:alert(1)')`)
- [ ] Auth gate: deep-link to gated route → `/login?return=<encoded>` → after login → land on intended route
- [ ] No infinite redirect loop on `/login` (verify by deep-linking to `/promo/X` while logged out)

## Cold start / warm start
- [ ] Cold-start (app terminated) tap on Universal Link → opens app to correct screen
- [ ] Warm-start (app in background) tap → switches to correct screen
- [ ] Two consecutive deep links don't cause double-routing (pitfall #12)
