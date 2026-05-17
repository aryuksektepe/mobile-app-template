// NON-MOCKED: real local Supabase, EMPTY mirror → must fall through to remote
// and backfill. A mocked fake repo hid ADR-027 entirely.
// Not tagged 'mocked' → runs in the backend-integration CI job.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('cache miss falls through to remote and backfills mirror', () async {
    await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
    final db = AppDatabase.forTest(); // fresh, EMPTY mirror
    final repo = LessonRepositoryImpl(db, Supabase.instance.client);

    final first = await repo.listLessonsForUnit('unit-1');
    expect(first, isA<Success<List<Lesson>>>());
    expect((first as Success).value, isNotEmpty,
        reason: 'Cache miss must fetch remote, not return [] (ADR-027)');

    // Second call must now be served from the backfilled mirror.
    final mirrored = await db.lessonsForUnit('unit-1');
    expect(mirrored, isNotEmpty, reason: 'Mirror was not backfilled');
  });
}
