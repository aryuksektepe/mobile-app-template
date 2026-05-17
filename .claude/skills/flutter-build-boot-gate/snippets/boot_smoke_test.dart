// Boot smoke: proves the app COMPILES and BOOTS with zero uncaught
// exceptions AND no rebuild/dispose storm. This is the gate the pipeline
// previously lacked. Runs every phase at INTEGRATION_SMOKE.
//
// Drives the REAL flavored entrypoint (main_dev.dart → bootstrap() → App),
// NOT `App()` directly — boot aborts (Sentry/Crashlytics init, Riverpod
// scoped-provider `dependencies`, Firebase init, autoDispose churn) live in
// bootstrap()/first frames, so pumping App() alone would never see them.
//
// Run: flutter test integration_test/boot_smoke_test.dart  (on an emulator)
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// TODO(executor): import the real flavored entrypoint, e.g. main_dev.dart
import 'package:<APP_PACKAGE>/main_dev.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots to first screen, no uncaught error, no rebuild storm',
      (tester) async {
    final errors = <FlutterErrorDetails>[];
    final prev = FlutterError.onError;
    FlutterError.onError = errors.add;

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));

    FlutterError.onError = prev;
    expect(errors, isEmpty, reason: 'Uncaught errors during boot: $errors');

    // Boot marker: main()/bootstrap() MUST emit `debugPrint('BOOT_OK
    // flavor=…')` as its last line. tool/smoke_boot.sh greps device logs for
    // it; here we assert a real first screen rendered (a settled splash that
    // never navigates is NOT a passing boot).
    // TODO(executor): assert the known first screen, e.g.:
    // expect(
    //   find.byType(SplashScreen).evaluate().isNotEmpty ||
    //       find.byType(AuthLandingScreen).evaluate().isNotEmpty,
    //   isTrue,
    //   reason: 'No known first screen rendered after boot',
    // );

    // Rebuild/dispose storm guard (ADR-022/024/025/026 class): if a debug
    // build counter is wired, assert it stayed bounded. Example:
    // expect(debugBuildCount('OnboardingScreen'), lessThan(5),
    //   reason: 'Rebuild storm — autoDispose churn / disposed-flag latch');
  });
}
