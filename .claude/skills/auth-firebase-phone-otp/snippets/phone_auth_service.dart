// PhoneAuthService — Firebase phone OTP with callback model + Riverpod state.
// State: idle → sendingCode → codeSent → verifying → verified/failed.
//
// Usage:
//   await ref.read(phoneAuthServiceProvider).sendCode('+905551234567');
//   await ref.read(phoneAuthServiceProvider).verifyCode('123456');

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PhoneAuthStep { idle, sendingCode, codeSent, verifying, verified, failed }

class PhoneAuthState {
  const PhoneAuthState({
    required this.step,
    this.verificationId,
    this.resendToken,
    this.errorMessage,
    this.autoRetrievedCode,
  });
  final PhoneAuthStep step;
  final String? verificationId;
  final int? resendToken;
  final String? errorMessage;
  final String? autoRetrievedCode; // Android auto-retrieval

  PhoneAuthState copyWith({
    PhoneAuthStep? step,
    String? verificationId,
    int? resendToken,
    String? errorMessage,
    String? autoRetrievedCode,
  }) =>
      PhoneAuthState(
        step: step ?? this.step,
        verificationId: verificationId ?? this.verificationId,
        resendToken: resendToken ?? this.resendToken,
        errorMessage: errorMessage,
        autoRetrievedCode: autoRetrievedCode ?? this.autoRetrievedCode,
      );
}

class PhoneAuthService extends StateNotifier<PhoneAuthState> {
  PhoneAuthService() : super(const PhoneAuthState(step: PhoneAuthStep.idle));

  final _auth = FirebaseAuth.instance;

  /// Send the SMS. Verification happens via callbacks set on the
  /// FirebaseAuth instance — codeSent triggers UI to show OTP entry.
  Future<void> sendCode(String e164PhoneNumber) async {
    state = state.copyWith(step: PhoneAuthStep.sendingCode, errorMessage: null);
    await _auth.verifyPhoneNumber(
      phoneNumber: e164PhoneNumber,
      timeout: const Duration(seconds: 60),
      // Auto-retrieval / instant verification (Android only)
      verificationCompleted: (PhoneAuthCredential cred) async {
        // Silent sign-in (Android auto-retrieved the SMS) — credential ready
        await _auth.signInWithCredential(cred);
        state = state.copyWith(step: PhoneAuthStep.verified);
      },
      verificationFailed: (FirebaseAuthException e) {
        state = state.copyWith(
          step: PhoneAuthStep.failed,
          errorMessage: _mapError(e.code),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        state = state.copyWith(
          step: PhoneAuthStep.codeSent,
          verificationId: verificationId,
          resendToken: resendToken,
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Android only — auto-retrieval window (60s) expired. UI stays on
        // OTP entry; user types the code manually.
        state = state.copyWith(verificationId: verificationId);
      },
      forceResendingToken: state.resendToken,
    );
  }

  Future<void> verifyCode(String smsCode) async {
    final id = state.verificationId;
    if (id == null) {
      state = state.copyWith(step: PhoneAuthStep.failed, errorMessage: 'no-verification-id');
      return;
    }
    state = state.copyWith(step: PhoneAuthStep.verifying);
    try {
      final cred = PhoneAuthProvider.credential(verificationId: id, smsCode: smsCode);
      await _auth.signInWithCredential(cred);
      state = state.copyWith(step: PhoneAuthStep.verified);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(step: PhoneAuthStep.failed, errorMessage: _mapError(e.code));
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'invalid-phone-number': return 'Geçersiz telefon numarası';
      case 'invalid-verification-code': return 'Hatalı kod';
      case 'session-expired': return 'Kodun süresi doldu. Yeni kod iste.';
      case 'too-many-requests': return 'Çok fazla deneme. Birazdan tekrar dene.';
      case 'app-not-authorized': return 'Uygulama doğrulanamadı. App Check ayarı yapılmamış olabilir.';
      case 'missing-client-identifier': return 'Yapılandırma eksik (Play Integrity / APNs).';
      default: return 'Doğrulama başarısız: $code';
    }
  }
}

final phoneAuthServiceProvider = StateNotifierProvider<PhoneAuthService, PhoneAuthState>(
  (ref) => PhoneAuthService(),
);
