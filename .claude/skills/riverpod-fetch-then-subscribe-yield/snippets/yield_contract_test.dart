// Yield-contract test: assert ORDER — fetched snapshot first, then updates.
// A "emits something" test would pass even with the dropped-yield bug.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

class MockLessonRepo extends Mock implements LessonRepo {}

void main() {
  test('lessons provider yields fetched snapshot BEFORE realtime updates',
      () async {
    final repo = MockLessonRepo();
    when(repo.fetchLessons).thenAnswer((_) async => [Lesson('snapshot')]);
    when(repo.watchLessons).thenAnswer(
      (_) => Stream.value([Lesson('live-update')]),
    );

    final container = ProviderContainer(overrides: [
      lessonRepoProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    final emissions = <List<Lesson>>[];
    final sub = container.listen(
      lessonsProvider.future,
      (_, __) {},
    );
    // Collect ordered emissions from the stream provider:
    await for (final v in container.read(lessonsProvider.stream).take(2)) {
      emissions.add(v);
    }
    sub.close();

    expect(emissions.first.single.id, 'snapshot',
        reason: 'Initial fetch was not yielded (ADR-029 dropped yield)');
    expect(emissions[1].single.id, 'live-update');
  });
}
