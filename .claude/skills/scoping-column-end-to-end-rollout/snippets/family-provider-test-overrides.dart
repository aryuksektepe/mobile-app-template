// ============================================================================
// family-provider-test-overrides.dart
// ----------------------------------------------------------------------------
// Three test-side patterns paid for in Phase-28's test-writer fix round.
// Use whenever you write tests for a Riverpod provider that:
//   (a) is a family — provider(arg)
//   (b) chains to currentUserProvider (or any other root-level provider)
//   (c) needs to fake a "loading forever" state in a widget test
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Imports below are placeholders — replace with your project's actual paths.
// import 'package:my_app/src/features/auth/application/providers/auth_providers.dart';
// import 'package:my_app/src/features/auth/domain/entities/auth_user.dart';
// import 'package:my_app/src/features/profile/application/providers/mastery_providers.dart';

// ============================================================================
// P-8 — Family provider override: SINGLE-ARG signature (not two)
// ============================================================================
//
// WRONG (compile error):
//   wellMasteryProvider('w-cyber').overrideWith(
//     (ref, wellId) async => WellMastery(...),   // ❌ two-arg signature
//   )
//
// The family argument is ALREADY BOUND when you call `wellMasteryProvider('w-cyber')`.
// The override callback receives only `ref`.
//
// Compile error you'll see:
//   The argument type 'Future<WellMastery> Function(WellMasteryRef, dynamic)'
//   can't be assigned to 'FutureOr<WellMastery> Function(WellMasteryRef)'.
//
// CORRECT:

/*
void example_p8() {
  final container = ProviderContainer(
    overrides: [
      wellMasteryProvider('w-cyber').overrideWith(
        (ref) async => const WellMastery(   // ✅ single-arg
          wellId: 'w-cyber',
          pct: 0.75,
          modulesMastered: 3,
          modulesTotal: 4,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  // Now read .future on the family provider with the SAME argument:
  // final mastery = await container.read(wellMasteryProvider('w-cyber').future);
}
*/

// ============================================================================
// P-9 — "Loading forever" in widget tests: use Completer, NOT Future.delayed
// ============================================================================
//
// WRONG (test fails with "A Timer is still pending"):
//   wellsProvider.overrideWith(
//     (ref) => Future.delayed(const Duration(seconds: 60), () => []),
//   )
//
// `Future.delayed` schedules a real timer that outlives the test and leaks.
//
// CORRECT:

/*
testWidgets('shows loading indicator while wells load', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wellsProvider.overrideWith(
          (ref) => Completer<List<Well>>().future,   // ✅ never completes, no timer
        ),
      ],
      child: const MaterialApp(home: WellOverviewScreen()),
    ),
  );
  await tester.pump();   // pump ONCE — don't pumpAndSettle (would hang)

  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
*/

// ============================================================================
// P-10 — Provider that chains to currentUserProvider needs explicit override
// ============================================================================
//
// SYMPTOM:
//   UnimplementedError: supabaseClientProvider must be overridden in
//   bootstrap() / tests.
//
// CAUSE:
//   Your provider under test calls `ref.watch(currentUserProvider)`.
//   currentUserProvider chains to supabaseClientProvider, which is
//   intentionally unimplemented at test time.
//
// FIX: short-circuit at currentUserProvider — DON'T try to fake supabaseClientProvider.

/*
const _fakeUser = AuthUser(id: 'uid-test', email: 'test@example.com');

test('perWellMasteryBoard returns single-entry list', () async {
  final container = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWithValue(_fakeUser),   // ✅ explicit override
      wellMasteryProvider('w-cyber').overrideWith(
        (ref) async => const WellMastery(
          wellId: 'w-cyber',
          pct: 0.75,
          modulesMastered: 3,
          modulesTotal: 4,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  final board = await container.read(perWellMasteryBoardProvider('w-cyber').future);
  expect(board.length, 1);
  expect(board.first.wellId, 'w-cyber');
});
*/

// ============================================================================
// COMBINED PATTERN — typical phase-28-style test for a scoped provider
// ============================================================================
//
// Use this as a copy-paste starting point. Fields commented out so this file
// compiles standalone in the skills/ directory; uncomment + adapt imports.

/*
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_app/src/features/auth/application/providers/auth_providers.dart';
import 'package:my_app/src/features/auth/domain/entities/auth_user.dart';
import 'package:my_app/src/features/scope/domain/entities/scope_thing.dart';
import 'package:my_app/src/features/scope/application/providers/scope_providers.dart';

const _fakeUser = AuthUser(id: 'uid-test', email: 'test@example.com');

void main() {
  group('scopeThingProvider', () {
    test('returns scoped data for current user', () async {
      const thing = ScopeThing(scopeId: 's-1', pct: 0.42);

      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(_fakeUser),
          scopeThingProvider('s-1').overrideWith((ref) async => thing),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(scopeThingProvider('s-1').future);

      expect(result.scopeId, 's-1');
      expect(result.pct, closeTo(0.42, 0.001));
    });

    test('empty list when signed out', () async {
      final container = ProviderContainer(
        overrides: [
          // The provider checks currentUserProvider == null and returns [].
          // Easiest to test: override to return [] directly.
          scopedListProvider.overrideWith((ref) async => const []),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(scopedListProvider.future);
      expect(result, isEmpty);
    });
  });
}
*/
