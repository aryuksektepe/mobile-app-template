// Cold + warm deep-link integration. Router unit tests with a fixed initial
// route never reproduce ADR-033 (cold crash) or ADR-034 (branch not switched).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart' show WidgetTester;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('COLD start with deep link: no red screen, correct tab',
      (tester) async {
    final errors = <FlutterErrorDetails>[];
    FlutterError.onError = errors.add;

    // Launch with the deep link AS the initial location (simulates a push /
    // universal-link cold start). Adapt to your entrypoint + link delivery.
    await launchAppWithInitialDeepLink(tester, '/lessons/abc');
    await tester.pumpAndSettle();

    expect(errors, isEmpty,
        reason: 'Provider mutated in redirect during cold start (ADR-033)');
    expect(find.byKey(const Key('lesson-abc')), findsOneWidget);
    expect(activeBranchIndex(tester), 1,
        reason: 'StatefulShell branch not switched on cold deep link (ADR-034)');
  });

  testWidgets('WARM deep link switches the shell branch', (tester) async {
    await launchApp(tester); // lands on Home (branch 0)
    await deliverDeepLink(tester, '/profile');
    await tester.pumpAndSettle();
    expect(activeBranchIndex(tester), 2, reason: 'branch not switched (ADR-034)');
  });
}
