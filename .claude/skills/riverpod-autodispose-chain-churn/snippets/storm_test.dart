// Storm regression: mock the datasource ONLY to count calls. With the churn
// bug, rapid rebuilds re-create the provider → N remote calls. Fixed: 1.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

class MockProgressRepo extends Mock implements ProgressRepo {}

void main() {
  test('rapid rebuilds do NOT re-fetch (keepAlive holds)', () async {
    final repo = MockProgressRepo();
    var calls = 0;
    when(repo.watchProgress).thenAnswer((_) {
      calls++;
      return const Stream<Progress>.empty();
    });

    final container = ProviderContainer(overrides: [
      progressRepoProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    for (var i = 0; i < 20; i++) {
      final sub = container.listen(progressStreamProvider, (_, __) {});
      sub.close();
    }

    expect(calls, 1,
        reason: 'autoDispose churn — provider recreated per listen (ADR-022/025/026)');
  });
}
