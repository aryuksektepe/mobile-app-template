# Google Sign In + Firebase Auth — Implementation Guide

## 1. Prerequisites
- `firebase-core-setup` complete
- `auth-firebase-email` complete (Firebase Auth wired)
- (iOS) Apple Developer account — Sign in with Apple required if shipping with Google (`auth-apple-signin`)

## 2. Add packages

```bash
flutter pub add google_sign_in
cd ios && pod install
```

## 3. Firebase Console

1. Authentication → Sign-in method → enable **Google**.
2. Set the project support email.
3. Note the auto-created **Web client ID** (will be used as `serverClientId` for Android).

Find the Web client ID later via: Firebase Console → Authentication → Sign-in method → click Google → "Web SDK configuration" → Web client ID.

## 4. iOS setup

1. Verify `ios/Runner/GoogleService-Info.plist` exists (per flavor).
2. Find `REVERSED_CLIENT_ID` in that plist. Add to `Info.plist` as URL scheme — see [snippets/Info.plist.snippet.xml](snippets/Info.plist.snippet.xml).
3. Set iOS deployment target ≥ 12.0.

## 5. Android setup — SHA fingerprints

You need **THREE SHA-256 fingerprints** registered in Firebase Console (per flavor's app config):

1. **Debug keystore** (works on `flutter run`):
   ```bash
   cd android && ./gradlew signingReport
   ```
   Look for `Variant: debug` → SHA1 + SHA256.

2. **Upload keystore** (your release signing config):
   ```bash
   keytool -list -v -keystore /path/to/upload-keystore.jks -alias upload
   ```

3. **Play App Signing** (most-missed; required when distributed via Play Store):
   - Play Console → Your app → Release → Setup → App signing.
   - "App signing key certificate" → SHA-256.
   - This is DIFFERENT from your upload key. Without it, Google Sign In code 12500 in production.

Add ALL THREE per flavor in Firebase Console → Project Settings → Your Android app → Add fingerprint.

After adding fingerprints: **re-download `google-services.json`** (or run `flutterfire reconfigure`).

## 6. Web setup (optional)

1. Google Cloud Console → APIs & Services → Credentials → identify the Web OAuth client (auto-created by Firebase).
2. Add your domain to Authorized JavaScript origins.
3. In `web/index.html`:
   ```html
   <script src="https://accounts.google.com/gsi/client" async defer></script>
   <meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com">
   ```
4. **FedCM mandatory since Chrome M139 (Aug 2025)**: ensure `gsi/client` script is current; FedCM is opt-out.

## 7. Initialize in main()

Use [snippets/init_google_signin.dart](snippets/init_google_signin.dart). Call from your `bootstrap()` AFTER `Firebase.initializeApp()`:

```dart
await initGoogleSignIn();
```

Pass IDs via `--dart-define`:
```bash
flutter run --flavor prod -t lib/main_prod.dart \
  --dart-define=GOOGLE_WEB_CLIENT_ID=1234-abc.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=5678-def.apps.googleusercontent.com
```

## 8. Wire repo + providers

Use [snippets/google_auth_repository.dart](snippets/google_auth_repository.dart) and [snippets/google_providers.dart](snippets/google_providers.dart).

Sign-in button:
```dart
ElevatedButton.icon(
  icon: Image.asset('assets/google.png', height: 18),
  label: const Text('Google ile devam et'),
  onPressed: () async {
    try {
      await ref.read(googleAuthRepoProvider).signInWithGoogle();
    } on AuthException catch (e) {
      // show error
    }
  },
)
```

## 9. Account linking

If user previously signed up with email and now signs in with Google for same email, you'll get `AccountExistsWithDifferentCredentialException`. Handle:

```dart
on AccountExistsWithDifferentCredentialException {
  // Prompt user to sign in with email first, then link:
  // 1. authRepo.signIn(email: existingEmail, password: ...);
  // 2. googleCredential = saved from above
  // 3. firebaseAuth.currentUser!.linkWithCredential(googleCredential);
}
```

## 10. Logout vs disconnect

```dart
// Standard logout — Credential Manager remembers user
await ref.read(googleAuthRepoProvider).signOut();

// Account deletion — revoke OAuth grant
await ref.read(googleAuthRepoProvider).disconnect();
```

In account-deletion flow (`auth-firebase-email`'s `deleteAccountFlow`), call `disconnect()` BEFORE `user.delete()`.

## 11. Apple App Review prep

Apple guideline 4.8: shipping with Google but not Sign in with Apple = rejection. Implement `auth-apple-signin` skill in parallel before submitting.

Hide Google sign-in on iOS if you somehow ship without Apple:
```dart
if (Platform.isAndroid || (Platform.isIOS && hasAppleSignIn)) {
  GoogleSignInButton(),
}
```

## 12. Verify

Run [checklist.md](checklist.md). Critical: works on Play Store internal testing build (proves Play App Signing SHA registered).
