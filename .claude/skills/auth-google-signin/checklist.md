# Google Sign In — Verification Checklist

## Setup
- [ ] `google_sign_in ^7.2.0` resolved (NEW initialize/authenticate/authorizationClient API)
- [ ] iOS deployment target ≥ 12.0
- [ ] Android `minSdk = 21`
- [ ] Firebase Console → Authentication → Google enabled
- [ ] Web client ID noted for `serverClientId`

## SHA fingerprints (Android)
- [ ] Debug keystore SHA-1 + SHA-256 added to Firebase Console
- [ ] Upload keystore SHA-1 + SHA-256 added to Firebase Console
- [ ] **Play App Signing** SHA-1 + SHA-256 added to Firebase Console (most-missed)
- [ ] `google-services.json` re-downloaded after adding fingerprints
- [ ] Per flavor, the corresponding fingerprints are registered

## iOS plist
- [ ] `REVERSED_CLIENT_ID` URL scheme in `Info.plist`
- [ ] `GoogleService-Info.plist` per flavor present in build

## Initialize
- [ ] `GoogleSignIn.instance.initialize(serverClientId: ...)` awaited in `main()` BEFORE `runApp()`
- [ ] `GOOGLE_WEB_CLIENT_ID` passed via `--dart-define`
- [ ] On Android, `serverClientId` is the WEB client (NOT Android client)

## Sign-in flows
- [ ] First sign-in: account picker shows; user signs in; Firebase user created
- [ ] Same device, second sign-in: auto-signs in last user (one-tap)
- [ ] After `signOut`: account picker shows again? (no — needs `disconnect`)
- [ ] After `disconnect`: explicit re-authorization required
- [ ] `account-exists-with-different-credential` caught + linking flow works

## Build verification
- [ ] Sign-in works in `flutter run` debug
- [ ] Sign-in works in release build installed via Internal Testing on Play Console
- [ ] Sign-in works in release build installed via TestFlight (iOS)
- [ ] Web flow works in Chrome 139+ (FedCM)

## Apple guideline 4.8
- [ ] If shipping with Google on iOS → Sign in with Apple ALSO implemented + visible
- [ ] OR Google sign-in hidden on iOS

## Account deletion
- [ ] In account-deletion flow, `disconnect()` called BEFORE `user.delete()`
- [ ] After deletion, signing in with Google requires explicit re-authorization

## Compliance
- [ ] Privacy policy lists Google as data processor for sign-in
- [ ] Workspace org-policy errors handled gracefully ("contact your admin")
