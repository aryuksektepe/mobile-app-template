# Firebase Auth (Email/Password) — Implementation Guide

## 1. Prerequisites
- `firebase-core-setup` complete
- `secure-storage-tokens` for logout flow

## 2. Add packages

```bash
flutter pub add firebase_auth local_auth
flutterfire reconfigure
cd ios && pod install
```

## 3. Firebase Console setup

1. Authentication → Get started.
2. Sign-in method → enable **Email/Password** (and toggle **Email link** if you want passwordless).
3. Settings → User actions → keep **Email enumeration protection** ON (default for projects since 2023-09-15). It hides which emails are registered. Affects pitfall #2 — read implementation note in §6.
4. Settings → Password policy → set min length, character classes (matches `WeakPasswordException` server-side mapping).
5. Templates → customize Email Verification + Password Reset:
   - Set **Action URL** to your Firebase Hosting custom domain (Firebase Dynamic Links is dead).
   - Customize subject + body in Turkish + English.
6. SMTP settings → optionally configure custom sending domain (improves deliverability — pitfall #7).

## 4. Firebase Hosting + email link handling

Email verification + password reset links arrive at your `actionCodeSettings.url`. To handle in-app:

1. Set up Firebase Hosting custom domain: `auth.yourdomain.com`.
2. Configure Universal Links / App Links for that domain (use `deeplinks-go-router` skill).
3. AASA + assetlinks must include the auth domain.
4. App receives `?mode=verifyEmail&oobCode=...` or `?mode=resetPassword&oobCode=...`.
5. Parse the mode, route to handler:
   ```dart
   final mode = uri.queryParameters['mode'];
   final oobCode = uri.queryParameters['oobCode'];
   switch (mode) {
     case 'verifyEmail':
       await FirebaseAuth.instance.applyActionCode(oobCode!);
       await FirebaseAuth.instance.currentUser?.reload();
       break;
     case 'resetPassword':
       // Show password reset form, then call confirmPasswordReset
       await FirebaseAuth.instance.confirmPasswordReset(code: oobCode!, newPassword: newPwd);
       break;
   }
   ```

## 5. Wire AuthRepository + providers

Use:
- [snippets/auth_repository.dart](snippets/auth_repository.dart) — all flows
- [snippets/auth_providers.dart](snippets/auth_providers.dart) — Riverpod
- [snippets/auth_exceptions.dart](snippets/auth_exceptions.dart) — typed exceptions

Calling code matches on type:
```dart
try {
  await ref.read(authRepoProvider).signIn(email: e, password: p);
} on InvalidCredentialsException {
  showSnack(l10n.invalidCredentials);   // "E-posta veya şifre hatalı"
} on NetworkException {
  showSnack(l10n.networkError);
} on RateLimitedException {
  showSnack(l10n.tooManyTries);
} on AuthException catch (e) {
  showSnack(l10n.unknownError);
  Sentry.captureMessage('Auth: $e');
}
```

## 6. Email enumeration protection — anonymous upgrade workaround

If enumeration protection is ON (default), `linkWithCredential` for anonymous → email throws `operation-not-allowed` because Firebase can't safely check existence.

Two options:
- **Disable enumeration protection** in Console (lowers security, accept tradeoff).
- **Accept-sign-up-on-link**: catch the error, sign user up fresh with the credentials, manually copy any anonymous data server-side via Cloud Function trigger.

Document your choice in `.project/decisions.md`.

## 7. GoRouter integration

Use [snippets/auth_router_gate.dart](snippets/auth_router_gate.dart). Combine with onboarding-flow's redirect:
```dart
GoRouter(
  refreshListenable: GoRouterRefreshStream(
    ref.read(firebaseAuthProvider).authStateChanges(),
  ),
  redirect: (ctx, state) {
    final ob = onboardingRedirect(ctx, state, ref);
    if (ob != null) return ob;
    return authRedirect(ctx, state, ref);
  },
);
```

## 8. Account deletion

Use [snippets/delete_account.dart](snippets/delete_account.dart):
1. Biometric reauth (if available).
2. Password reauth.
3. Vendor cleanup (RC, Apple Sign-In token revoke).
4. `user.delete()`.
5. Local cleanup (secure storage, push token, analytics, crash user).
6. Cloud Function `onUserDelete` purges Firestore + Storage data.

Deploy [snippets/onUserDelete.ts](snippets/onUserDelete.ts):
```bash
firebase deploy --only functions:onUserDelete
```

OR install the official **Delete User Data** Firebase Extension (recommended for common patterns).

## 9. Logout — clear EVERYTHING

```dart
Future<void> signOut(WidgetRef ref) async {
  await ref.read(authRepoProvider).signOut();
  await ref.read(tokenRepoProvider).clearAll();
  await clearCrashUser();
  await FirebaseMessaging.instance.deleteToken();
  await FirebaseAnalytics.instance.setUserId(id: null);
  // Sign out of any OAuth providers (Google, Apple) here.
}
```

## 10. Verify

Run [checklist.md](checklist.md). Critical: account deletion verified via Cloud Function logs + Firestore inspection.
