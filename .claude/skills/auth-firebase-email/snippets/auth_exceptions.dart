// Typed exceptions mapped from FirebaseAuthException codes.
// Calling layer matches on type, not on string code.

sealed class AuthException implements Exception {
  const AuthException();
}

/// Email format invalid (client-side check failed OR server rejected).
class InvalidEmailException extends AuthException {
  const InvalidEmailException();
}

/// Wrong password OR no user with that email — UNDIFFERENTIATED due to
/// Firebase email enumeration protection (default since 2023-09-15).
/// UI should show: "E-posta veya şifre hatalı."
class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException();
}

class WeakPasswordException extends AuthException {
  const WeakPasswordException();
}

class EmailTakenException extends AuthException {
  const EmailTakenException();
}

class AccountDisabledException extends AuthException {
  const AccountDisabledException();
}

/// Too many requests — backoff + retry later.
class RateLimitedException extends AuthException {
  const RateLimitedException();
}

/// Network error — show "Bağlantı sorunu, tekrar deneyin."
class NetworkException extends AuthException {
  const NetworkException();
}

/// Sensitive operation (password change, delete) requires fresh login.
/// Caller should prompt for password + retry the operation.
class ReauthRequiredException extends AuthException {
  const ReauthRequiredException();
}

/// Action code (password reset / email verification) expired or already used.
class InvalidActionCodeException extends AuthException {
  const InvalidActionCodeException();
}

/// Provider exists for that email but with different credential type.
/// Caller should ask user to sign in with original method, then link.
class AccountExistsWithDifferentCredentialException extends AuthException {
  const AccountExistsWithDifferentCredentialException();
}

class BiometricFailedException extends AuthException {
  const BiometricFailedException();
}

class UnknownAuthException extends AuthException {
  const UnknownAuthException(this.code);
  final String code;
}
