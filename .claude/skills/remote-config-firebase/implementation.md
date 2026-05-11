# Firebase Remote Config — Implementation Guide

## 1. Prerequisite
- `firebase-core-setup` complete

## 2. Add packages

```bash
flutter pub add firebase_remote_config freezed_annotation package_info_plus
flutter pub add --dev build_runner freezed
flutterfire reconfigure
```

Run codegen for `AppConfig`:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## 3. Define parameters in Firebase Console

For each parameter:
1. Console → Remote Config → Add parameter.
2. Name (snake_case, matches your `defaults` map key).
3. Default value (in-console — should match your in-app default).
4. (Optional) Conditions: country, app version, audience, user property, percentile (for A/B tests).

Recommended starter set:
- `feature_x_enabled` (boolean, default `false`)
- `paywall_variant` (string: `control` | `variant_a`)
- `min_supported_build` (number, default `1`)
- `maintenance_mode` (boolean, default `false`)
- `maintenance_message` (string, default `""`)

## 4. Wire bootstrap

Add to your `bootstrap()` AFTER `Firebase.initializeApp()`:

```dart
import 'init_remote_config.dart';

await initRemoteConfig();   // sets defaults, fires fetchAndActivate (non-blocking)
```

See [snippets/init_remote_config.dart](snippets/init_remote_config.dart).

## 5. Define typed AppConfig

Use [snippets/remote_config.dart](snippets/remote_config.dart). Add a field per console parameter.

To add a new parameter `xyz_enabled`:
1. Add `'xyz_enabled': false` to `AppConfig.defaults`.
2. Add `required bool xyzEnabled` field.
3. Add `xyzEnabled: rc.getBool('xyz_enabled')` in `fromRemote`.
4. Run codegen: `dart run build_runner build`.
5. Add the parameter in Firebase Console.

## 6. Read in widgets

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return config.when(
      loading: () => const SizedBox(),  // defaults arrive ~immediately
      error: (e, _) => const SizedBox(),
      data: (c) => c.featureXEnabled ? const FeatureXWidget() : const Placeholder(),
    );
  }
}
```

## 7. Force-update + maintenance gate

Wrap your home/router with `AppGate` from [snippets/force_update_gate.dart](snippets/force_update_gate.dart):

```dart
GoRouter(
  routes: [
    GoRoute(path: '/', builder: (ctx, _) => const AppGate(child: HomeScreen())),
  ],
)
```

⚠ `AppGate` defaults `min_supported_build` to `1`, ensuring offline users / RC fetch failure NEVER blocks legit users.

## 8. A/B test variant logging

After AppConfig settles (e.g., on first frame after splash), log the variant to Firebase Analytics:

```dart
import 'package:firebase_analytics/firebase_analytics.dart';

ref.listen(appConfigProvider, (prev, next) {
  next.whenData((c) {
    FirebaseAnalytics.instance.setUserProperty(
      name: 'paywall_variant',
      value: c.paywallVariant,
    );
  });
});
```

This makes the variant a **sticky audience signal**, enabling Firebase A/B Testing experiment tracking.

## 9. Verify

Run [checklist.md](checklist.md). Test:
- Change a value in console → real-time update fires within ~1 min.
- Bump `min_supported_build` to a value > current → app shows ForceUpdateScreen.
- Set `maintenance_mode: true` → app shows MaintenanceScreen.
- Restore values → app returns to normal within ~1 min.
