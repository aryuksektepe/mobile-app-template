import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'lessons_provider.g.dart';

// Correct: emit the fetched snapshot, THEN stream live updates.
@riverpod
Stream<List<Lesson>> lessons(LessonsRef ref) async* {
  final repo = ref.watch(lessonRepoProvider);
  yield await repo.fetchLessons(); // snapshot — UI renders immediately
  yield* repo.watchLessons();      // realtime updates thereafter
}

// Anti-pattern for reference (DO NOT SHIP):
// @riverpod
// Stream<List<Lesson>> lessonsBad(LessonsBadRef ref) async* {
//   final repo = ref.watch(lessonRepoProvider);
//   final initial = await repo.fetchLessons(); // fetched and dropped
//   yield* repo.watchLessons();                // empty until first event
// }
