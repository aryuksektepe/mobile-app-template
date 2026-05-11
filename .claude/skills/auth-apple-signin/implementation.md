# Sign in with Apple — Implementation Guide

## 1. Prerequisites
- **Apple Developer Program** (paid, $99/yr — Sign in with Apple is restricted)
- `firebase-core-setup` complete
- `auth-firebase-email` complete (for `linkWithCredential` + delete flow)

## 2. Add packages

```bash
flutter pub add sign_in_with_apple crypto
cd ios && pod install
```

## 3. Apple Developer Portal

### 3.1 Enable on App ID
1. Apple Developer → Certificates, Identifiers & Profiles → Identifiers.
2. Click your iOS App ID → Edit → enable **Sign in with Apple** capability → Save.

### 3.2 Create Service ID (only needed for Android/Web)
1. Identifiers → + → **Services IDs**.
2. Identifier: `com.acme.myapp.signin` (different from your App ID).
3. Enable Sign In with Apple → Configure.
4. **Primary App ID**: your iOS App ID.
5. **Domains and Subdomains**: your Firebase project's auth domain (e.g., `your-project.firebaseapp.com`) — NO `https://` prefix.
6. **Return URLs**: full URL `https://your-project.firebaseapp.com/__/auth/handler`.

### 3.3 Create Key
1. Keys → + → enable **Sign In with Apple** → Configure → choose Primary App ID.
2. **Download the `.p8` file ONCE** (cannot re-download).
3. Note **Key ID** (10 chars) and **Team ID** (10 chars from Membership).

### 3.4 Configure Email Sources (only if using Hide My Email)
1. Certificates, Identifiers & Profiles → More → Configure (under Sign in with Apple).
2. Add your sender email domain.
3. Add SPF + DKIM records to your DNS for deliverability.
4. Verify domain (Apple sends a test email).

## 4. Firebase Console

1. Authentication → Sign-in method → enable **Apple**.
2. (Only for Android/Web) Fill in Service ID + Apple Team ID + Key ID + paste private key contents.
3. (For Android/Web only) Authorized domains → ensure your Firebase auth domain is listed.

## 5. iOS Xcode setup

1. Open `ios/Runner.xcworkspace` → Runner target → Signing & Capabilities.
2. **+ Capability → Sign in with Apple**.
3. Confirm provisioning profile regenerates (Xcode usually auto-handles).
4. Set iOS deployment target ≥ 13.0.

## 6. Wire repo + providers

Use:
- [snippets/apple_auth_repository.dart](snippets/apple_auth_repository.dart) — nonce dance + name capture + persist authorizationCode
- [snippets/apple_providers.dart](snippets/apple_providers.dart) — Riverpod

Pass via `--dart-define`:
- `APPLE_SERVICE_ID` (only needed for Android/Web)
- `APPLE_REDIRECT_URI` (e.g., `https://your-project.firebaseapp.com/__/auth/handler`)

Sign-in button:
```dart
SignInWithAppleButton(
  onPressed: () async {
    try {
      await ref.read(appleAuthRepoProvider).signInWithApple();
    } on AuthException catch (e) {
      // show error
    }
  },
)
```

⚠ Hide on Android if you only support iOS Apple Sign-In:
```dart
if (Platform.isIOS) SignInWithAppleButton(...)
```

## 7. Cloud Function for revocation

Use [snippets/revokeAppleToken.ts](snippets/revokeAppleToken.ts).

Set env vars:
```bash
firebase functions:config:set \
  apple.team_id="ABCD123456" \
  apple.service_id="com.acme.myapp.signin" \
  apple.key_id="XYZAB12345" \
  apple.private_key="$(cat AuthKey_XYZAB12345.p8)"

firebase deploy --only functions:storeAppleAuthCode
```

Call `revokeAppleRefreshToken(uid)` from your `onUserDelete` Cloud Function (chain it before Firestore purge).

## 8. Account deletion flow

Use [snippets/apple_delete.dart](snippets/apple_delete.dart). Critical sequence:
1. Force fresh sign-in (gets a usable authorizationCode — original is stale).
2. Reauthenticate Firebase (recent-login requirement).
3. Call `firebase.revokeTokenWithAuthorizationCode(code)` — Apple App Review enforces.
4. `user.delete()`.
5. Cloud Function `onUserDelete` purges data.

Without step 3, Apple App Review rejects with: "Your app supports Sign in with Apple, but it doesn't revoke the user's Apple ID grant when they delete their account."

## 9. Hide My Email handling

When user picks "Hide My Email", Apple returns a relay address like `xyz@privaterelay.appleid.com`. Treat this as the user's primary contact:
- Send transactional emails to the relay (Apple forwards).
- Register your sender domain (step 3.4) or emails bounce.
- Do NOT show the relay address in UI as if it were the user's "real" email — say "your private Apple ID email".

## 10. Verify

Run [checklist.md](checklist.md). Critical:
- Test deletion flow end-to-end on TestFlight build before submission.
- Verify in Apple ID Settings → Apps Using Apple ID → app is removed after deletion.
