// Riverpod NotifierProvider for the App Lock state machine.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'app_lock_storage.dart';

@immutable
class AppLockState {
  const AppLockState({
    required this.enabled,
    required this.biometricEnabled,
    required this.isLocked,
    required this.initialized,
    required this.failCount,
    required this.lockedUntilEpochMs,
  });

  final bool enabled;
  final bool biometricEnabled;
  final bool isLocked;
  final bool initialized;
  final int failCount;
  final int lockedUntilEpochMs;

  bool get isLockedOut =>
      DateTime.now().millisecondsSinceEpoch < lockedUntilEpochMs;
  int get lockoutSecondsRemaining {
    if (!isLockedOut) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return ((lockedUntilEpochMs - now) / 1000).ceil();
  }

  AppLockState copyWith({
    bool? enabled,
    bool? biometricEnabled,
    bool? isLocked,
    bool? initialized,
    int? failCount,
    int? lockedUntilEpochMs,
  }) =>
      AppLockState(
        enabled: enabled ?? this.enabled,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        isLocked: isLocked ?? this.isLocked,
        initialized: initialized ?? this.initialized,
        failCount: failCount ?? this.failCount,
        lockedUntilEpochMs: lockedUntilEpochMs ?? this.lockedUntilEpochMs,
      );

  static const empty = AppLockState(
    enabled: false,
    biometricEnabled: false,
    isLocked: false,
    initialized: false,
    failCount: 0,
    lockedUntilEpochMs: 0,
  );
}

class AppLockController extends Notifier<AppLockState> {
  final _storage = AppLockStorage.instance;
  final _localAuth = LocalAuthentication();

  @override
  AppLockState build() => AppLockState.empty;

  Future<void> init() async {
    final enabled = await _storage.isEnabled();
    final bio = await _storage.isBiometricEnabled();
    final fails = await _storage.failCount();
    final until = await _storage.lockedUntilMs() ?? 0;
    state = AppLockState(
      enabled: enabled,
      biometricEnabled: bio,
      isLocked: enabled, // cold start: enabled means locked
      initialized: true,
      failCount: fails,
      lockedUntilEpochMs: until,
    );
  }

  /// Called by AppLockGate when REAL background → foreground.
  void lock() {
    if (!state.enabled) return;
    state = state.copyWith(isLocked: true);
  }

  Future<bool> tryUnlockWithPin(String pin) async {
    if (state.isLockedOut) return false;
    final ok = await _storage.verifyPin(pin);
    if (ok) {
      await _storage.setFailCount(0);
      state = state.copyWith(
        isLocked: false,
        failCount: 0,
        lockedUntilEpochMs: 0,
      );
      return true;
    }
    final newFail = state.failCount + 1;
    await _storage.setFailCount(newFail);
    final until = lockoutMillisFor(newFail);
    if (until > 0) {
      await _storage.setLockedUntilMs(until);
    }
    state = state.copyWith(
      failCount: newFail,
      lockedUntilEpochMs: until,
    );
    return false;
  }

  Future<bool> tryUnlockWithBiometric() async {
    if (!state.biometricEnabled || state.isLockedOut) return false;
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Uygulamayı aç',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok) {
        state = state.copyWith(
          isLocked: false,
          failCount: 0,
          lockedUntilEpochMs: 0,
        );
        await _storage.setFailCount(0);
      }
      return ok;
    } catch (_) {
      // iOS 26 cold-start transient → return false, PIN pad fallback.
      return false;
    }
  }

  Future<void> setupPin(String pin, {bool biometric = false}) async {
    await _storage.setPin(pin);
    await _storage.setBiometricEnabled(biometric);
    state = state.copyWith(
      enabled: true,
      biometricEnabled: biometric,
      isLocked: false,
      failCount: 0,
      lockedUntilEpochMs: 0,
    );
  }

  Future<void> disable() async {
    await _storage.clearAll();
    state = AppLockState.empty.copyWith(initialized: true);
  }

  /// CRITICAL: call this on Supabase/Firebase signedOut event.
  /// Otherwise the next user inherits the previous user's PIN.
  Future<void> clearOnSignOut() => disable();
}

final appLockControllerProvider =
    NotifierProvider<AppLockController, AppLockState>(AppLockController.new);
