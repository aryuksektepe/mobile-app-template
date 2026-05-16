// Boot smoke: proves the app COMPILES and BOOTS with zero uncaught
// exceptions. This is the gate the pipeline previously lacked.
//
// Drives the REAL flavored entrypoint (main_dev.dart → bootstrap() → App),
// NOT `App()` directly — boot aborts (Sentry/Crashlytics init, Riverpod
// scoped-provider `dependencies`, Firebase init) live in bootstrap(), so
// pumping App() alone would never see them.
//
// Run: flutter test integration_test/app_boot_test.dart  (on an emulator)
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// TODO(executor): import the real flavored entrypoint, e.g. main_dev.dart
import 'package:<APP_PACKAGE>/main_dev.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots to first screen without uncaught exceptions',
      (tester) async {
    final errors = <FlutterErrorDetails>[];
    final prev = FlutterError.onError;
    FlutterError.onError = errors.add;

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));

    FlutterError.onError = prev;
    expect(errors, isEmpty, reason: 'Uncaught errors during boot: $errors');

    // TODO(executor): assert a known first-screen widget is present, e.g.:
    // expect(
    //   find.byType(SplashScreen).evaluate().isNotEmpty ||
    //       find.byType(AuthLandingScreen).evaluate().isNotEmpty,
    //   isTrue,
    //   reason: 'No known first screen rendered after boot',
    // );
  });
}
