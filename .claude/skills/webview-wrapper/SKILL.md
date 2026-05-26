---
name: webview-wrapper
description: WebView wrapper via `webview_flutter` 4.x — used for T&C, help docs, support pages, OAuth fallback. Handles JavaScript bridge, mixed-content guard, file upload (Android picker integration), URL allowlist (block off-domain navigation), Android back-button → WebView history, iOS pull-to-refresh, error/offline state. NOT for OAuth-in-webview (Apple/Google reject; use system browser).
triggers: [webview, webview_flutter, in-app browser, help page, terms of service, privacy policy in app, oauth webview, javascript channel, mixed content, file upload webview]
platforms: [ios, android]
last_verified: 2026-05-26
flutter_min: "3.22.0"
package_versions:
  webview_flutter: "^4.10.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# WebView Wrapper

## What this skill does

- `webview_flutter` 4.x with `WebViewController` setup (JS enabled, transparent background, navigation delegate).
- **URL allowlist** — block navigation off your domain (security). Pin to specific paths if needed.
- JavaScript bridge: `addJavaScriptChannel` for native→web message passing.
- File upload integration (Android needs a callback wire-up; iOS handled natively).
- Pull-to-refresh on iOS via `RefreshIndicator` wrapping (Android has it natively in WebView).
- Android back button → WebView history (`canGoBack()` → `goBack()`).
- Error / offline state UI.
- Mixed-content blocked by default (no HTTP loaded into HTTPS frame).
- Pure-content embedding pattern: T&C, FAQ, support docs. NOT OAuth flows (use `url_launcher`'s `LaunchMode.externalApplication` for OAuth).

## What this skill does NOT do

- Does NOT do OAuth-in-webview (Apple Guideline 4.5.4, Google Identity rejection — use external browser).
- Does NOT cover server-side asset serving (just the client).

## Decision tree

**Q1: Hosted content (your domain) or external?**
- HOSTED — full WebView with JS bridge, allowlist, etc.
- EXTERNAL — `url_launcher` with `LaunchMode.externalApplication` instead; no WebView needed.

**Q2: Need JS↔Dart bridge?**
- YES — `addJavaScriptChannel('AppBridge', onMessage: (msg) => ...)`; web side: `window.AppBridge.postMessage(JSON.stringify({...}))`.
- NO — pure read-only content; skip the channel.

**Q3: File upload from inside webview?**
- YES — Android needs explicit wire-up via PlatformView (file_picker integration); iOS works out-of-box.
- NO — block via navigation delegate to avoid surprise pickers.

## Quick start

```bash
flutter pub add webview_flutter
```

Apply [snippets/webview_screen.dart](snippets/webview_screen.dart).

## Code patterns

| Need | File |
|---|---|
| WebView screen with allowlist + back-handling + JS bridge | [snippets/webview_screen.dart](snippets/webview_screen.dart) |

## Known pitfalls

→ [pitfalls.md](pitfalls.md). Top 5:
1. OAuth-in-webview gets the app rejected by Apple (4.5.4) AND Google blocks it from Sept 2021.
2. No URL allowlist → a compromised link inside the webview navigates to attacker domain, app context intact.
3. Mixed-content (HTTP iframe inside HTTPS page) silently blocked → "blank section" bug.
4. JS bridge `postMessage` from JS but Dart channel registered AFTER page load → first message lost.
5. Android back button closes the entire screen instead of going back in WebView history.

## Verification

→ [checklist.md](checklist.md).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-26
- Depends on: (none)
