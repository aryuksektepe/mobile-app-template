import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'keepalive_providers.g.dart';

// Session identity — lives for the app session, NOT per-screen.
@Riverpod(keepAlive: true)
Stream<AppUser?> currentUser(CurrentUserRef ref) {
  final repo = ref.watch(authRepoProvider); // authRepo is also keepAlive
  return repo.authStateChanges();
}

// Cross-screen realtime stream — single subscription, kept alive.
@Riverpod(keepAlive: true)
Stream<Progress> progressStream(ProgressStreamRef ref) {
  final repo = ref.watch(progressRepoProvider); // keepAlive
  return repo.watchProgress();
}

// Per-screen ephemeral state stays autoDispose (correct default) — and it
// may `ref.read` (not watch) a keepAlive provider safely.
@riverpod
class LessonFilter extends _$LessonFilter {
  @override
  String build() => 'all';
  void set(String v) => state = v;
}

// WRONG (do not do this): a keepAlive provider watching an autoDispose one
// re-introduces churn:
//   @Riverpod(keepAlive: true)
//   X bad(BadRef ref) => ref.watch(someAutoDisposeProvider);
