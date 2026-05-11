# Onboarding Flow — Implementation Guide

## 1. Prerequisites
- `secure-storage-tokens` skill (provides fresh-install Keychain wipe context)
- `remote-config-firebase` skill (for A/B variant resolution)
- `analytics-firebase` skill (for funnel + variant logging)

## 2. Add packages

```bash
flutter pub add shared_preferences smooth_page_indicator lottie flutter_riverpod
```

## 3. Wire OnboardingController

Use [snippets/onboarding_controller.dart](snippets/onboarding_controller.dart). Key points:
- Wipes Keychain on fresh-install (chains with `secure-storage-tokens` skill).
- Reads `onboarding_variant` from Remote Config with 4s timeout.
- Logs `onboarding_step_viewed` + `onboarding_completed` events.
- Sets `onboarding_variant` user property for sticky A/B bucketing.

## 4. Build the screen

Use [snippets/onboarding_screen.dart](snippets/onboarding_screen.dart). Pass 3-5 `OnboardingPage` instances:

```dart
const pages = [
  OnboardingPage(
    title: 'Hoş geldin',
    body: 'Tüm kayıtlarını tek yerde topla.',
    assetPath: 'assets/onboarding/welcome.png',
  ),
  // ...
];
```

**Asset budget**: total <2MB. Lottie files compress better than PNGs for animations. Use `flutter_svg` for vector icons (smaller).

## 5. Permission timing — the most important UX decision

DO NOT bundle multiple permissions on one screen. Use [snippets/soft_ask_widget.dart](snippets/soft_ask_widget.dart) at the moment the user can taste value.

| Permission | When to ask |
|---|---|
| Notification | After onboarding, when first notification would be relevant ("get notified when your order ships") |
| Location | When the feature first needs it ("find restaurants near me") |
| Camera | When user taps "Add photo" |
| Contacts | When user taps "Find friends" |
| ATT (iOS) | After user accepts analytics consent banner; LATE in the journey |

ATT only fires ONCE per install — burning it on screen 1 of onboarding is the most common monetization mistake. Defer.

## 6. GoRouter integration

Use [snippets/router_gate.dart](snippets/router_gate.dart):

```dart
GoRouter(
  redirect: (ctx, state) => onboardingRedirect(ctx, state, ref),
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => OnboardingScreen(
      pages: pages,
      onDone: () => GoRouter.of(ctx).go('/home'),
    )),
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
  ],
);
```

Deep links arriving during onboarding are stashed in `pendingDeepLinkProvider` and replayed after complete.

## 7. A/B variant setup

In Firebase Console → Remote Config:
1. Add parameter `onboarding_variant` (string, default `control`).
2. Add a Condition: "country = TR" → value `variant_a`. Or "audience = new_users" → percentile 50/50 split.
3. Console → A/B Testing → create experiment using this parameter.

In code: variant resolved during `build()`, mirrored to Analytics property → audience joins experiment automatically.

## 8. Localization

Wrap all strings in `AppLocalizations.of(ctx).onboardingWelcomeTitle` (use `flutter gen-l10n`). Provide both TR + EN ARB files.

For RTL languages (Arabic, Hebrew):
- Use `EdgeInsetsDirectional.only(start: 16)` instead of `EdgeInsets.only(left: 16)`.
- `Directionality.of(ctx)` for layout-direction-aware widgets.
- Mirror smooth_page_indicator (use `effect: WormEffect(...)` which auto-handles).

## 9. Accessibility

- Wrap pages in `Semantics(label: 'Onboarding screen X of N')` (already in screen snippet).
- Color contrast ≥4.5:1.
- Test with system font scaling at 200%.
- All buttons hit-target ≥48dp.

## 10. Verify

Run [checklist.md](checklist.md). Critical:
- Drop-off funnel measured per step in Analytics.
- A/B variant assignment sticky across reinstalls (audience-based, not Random()).
- Deep link arriving during onboarding → user lands there after Get-Started.
