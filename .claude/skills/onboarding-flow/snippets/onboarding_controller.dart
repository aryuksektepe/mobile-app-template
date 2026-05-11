// OnboardingController — Riverpod AsyncNotifier with persistent step.
// Wipes secure storage on detected fresh install (iOS Keychain trap).

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingState {
  const OnboardingState({
    required this.completed,
    required this.step,
    required this.variant,
  });

  final bool completed;
  final int step;
  final String variant;     // 'control' | 'variant_a' | 'variant_b'

  OnboardingState copyWith({bool? completed, int? step, String? variant}) =>
      OnboardingState(
        completed: completed ?? this.completed,
        step: step ?? this.step,
        variant: variant ?? this.variant,
      );
}

class OnboardingController extends AsyncNotifier<OnboardingState> {
  static const _kFirstLaunch = 'is_first_app_launch';
  static const _kCompleted = 'onboarding_completed';
  static const _kStep = 'onboarding_step';

  @override
  Future<OnboardingState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool(_kFirstLaunch) ?? true;

    if (isFirstLaunch) {
      // CRITICAL: clear leftover Keychain from prior install (iOS).
      // Pairs with secure-storage-tokens skill's fresh-install wipe.
      await const FlutterSecureStorage().deleteAll();
      await prefs.setBool(_kFirstLaunch, false);
    }

    return OnboardingState(
      completed: prefs.getBool(_kCompleted) ?? false,
      step: prefs.getInt(_kStep) ?? 0,
      variant: await _resolveVariant(),
    );
  }

  Future<String> _resolveVariant() async {
    final rc = FirebaseRemoteConfig.instance;
    // 4s timeout — fall back to default if slow network.
    await rc.fetchAndActivate().timeout(
      const Duration(seconds: 4),
      onTimeout: () => false,
    );
    final v = rc.getString('onboarding_variant');
    return v.isEmpty ? 'control' : v;
  }

  Future<void> nextStep() async {
    final s = state.value!;
    final prefs = await SharedPreferences.getInstance();
    final next = s.step + 1;
    await prefs.setInt(_kStep, next);
    state = AsyncData(s.copyWith(step: next));

    await FirebaseAnalytics.instance.logEvent(
      name: 'onboarding_step_viewed',
      parameters: {'step': next, 'variant': s.variant},
    );
  }

  Future<void> complete() async {
    final s = state.value!;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCompleted, true);
    state = AsyncData(s.copyWith(completed: true));

    await FirebaseAnalytics.instance.logEvent(
      name: 'onboarding_completed',
      parameters: {'variant': s.variant, 'final_step': s.step},
    );

    // Sticky audience bucketing for Firebase A/B Testing.
    await FirebaseAnalytics.instance.setUserProperty(
      name: 'onboarding_variant',
      value: s.variant,
    );
  }

  /// Debug-only: reset onboarding state.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCompleted);
    await prefs.remove(_kStep);
    ref.invalidateSelf();
  }
}

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, OnboardingState>(
  OnboardingController.new,
);
