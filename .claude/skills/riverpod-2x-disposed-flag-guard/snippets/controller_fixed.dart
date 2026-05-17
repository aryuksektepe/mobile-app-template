// Corrected: no manual disposal flag, pure build(), ref.mounted after awaits.
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingState {
  const OnboardingState({this.page = 0, this.done = false});
  final int page;
  final bool done;
  OnboardingState copyWith({int? page, bool? done}) =>
      OnboardingState(page: page ?? this.page, done: done ?? this.done);
}

class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    // Pure: derived only from deps. No `_disposed` branch, no onDispose latch.
    final alreadyDone = ref.watch(onboardingDoneProvider);
    return OnboardingState(done: alreadyDone);
  }

  void next() => state = state.copyWith(page: state.page + 1);

  Future<void> complete() async {
    await ref.read(onboardingRepoProvider).markDone();
    if (!ref.mounted) return; // the only correct post-await guard
    state = state.copyWith(done: true);
  }
}

final onboardingDoneProvider = Provider<bool>((_) => false); // wire to repo
final onboardingRepoProvider = Provider<dynamic>((_) => throw UnimplementedError());
final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
        OnboardingController.new);
