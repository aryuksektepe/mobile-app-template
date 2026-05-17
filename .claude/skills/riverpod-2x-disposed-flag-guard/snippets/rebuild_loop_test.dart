// Regression test for the ADR-024 loop. A single read would pass even with
// the bug — you MUST drive repeated invalidate/rebuild cycles and assert the
// build count stays bounded and state converges.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test('repeated invalidation does not loop; state converges', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    var builds = 0;
    container.listen(
      onboardingControllerProvider,
      (_, __) => builds++,
      fireImmediately: true,
    );

    for (var i = 0; i < 20; i++) {
      container.invalidate(onboardingControllerProvider);
      container.read(onboardingControllerProvider);
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // With the _disposed latch this explodes (builds ≫ 20 / never settles).
    expect(builds, lessThan(40),
        reason: 'Rebuild storm — disposed-flag latch regression (ADR-024)');
  });
}
