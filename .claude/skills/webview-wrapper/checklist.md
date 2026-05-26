# WebView Wrapper — Verification Checklist

- [ ] `webview_flutter` 4.x in dependencies
- [ ] URL allowlist (`allowedHosts`) enforced in `onNavigationRequest`
- [ ] HTTPS-only navigation check
- [ ] JS bridge channels + delegate registered BEFORE first `loadRequest`
- [ ] Android back button → `canGoBack()` → `goBack()` via `PopScope`
- [ ] Error state UI with retry button
- [ ] Loading state (linear progress) until `onPageFinished`
- [ ] OAuth flows NOT in WebView (use `url_launcher` external)
- [ ] Cookies cleared on sign-out (`WebViewCookieManager().clearCookies()`)
- [ ] iOS: `RefreshIndicator` wrap for pull-to-refresh if applicable
- [ ] File upload pathway tested if applicable (Android picker, iOS native)
- [ ] Off-domain navigation → opens in external browser, not in-app
- [ ] Real-device test: T&C page loads, back button goes back, off-link goes external, error state shows on bad URL
