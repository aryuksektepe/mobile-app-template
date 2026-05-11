# Sign in with Apple — Verification Checklist

## Apple Developer Portal
- [ ] Apple Developer Program membership active (paid)
- [ ] Sign in with Apple capability enabled on App ID
- [ ] (For Android/Web) Service ID created with Domains + Return URLs
- [ ] Key created and `.p8` file safely stored (cannot re-download!)
- [ ] (If Hide-My-Email) Sender domain registered + SPF + DKIM verified

## Firebase Console
- [ ] Apple sign-in method enabled
- [ ] (For Android/Web) Service ID + Team ID + Key ID + private key entered

## iOS setup
- [ ] Xcode → Signing & Capabilities → Sign in with Apple capability added
- [ ] iOS deployment target ≥ 13.0
- [ ] Provisioning profile regenerated after capability change

## Code wiring
- [ ] Nonce dance correct: SHA256(rawNonce) → Apple `nonce`, raw → Firebase `rawNonce`
- [ ] Name capture runs ONLY on first sign-in (givenName/familyName non-null)
- [ ] Name persisted to BOTH Firestore + `user.updateDisplayName` with retry
- [ ] `authorizationCode` sent to `storeAppleAuthCode` Cloud Function on every sign-in
- [ ] Email scope included (`AppleIDAuthorizationScopes.email`)

## Cloud Functions (revocation)
- [ ] `storeAppleAuthCode` deployed with App Check enforced
- [ ] Apple env vars set (Team ID, Service ID, Key ID, private key)
- [ ] JWT client_secret signed with ES256, exp ≤ 6 months
- [ ] Refresh token stored encrypted in `users/{uid}/private/apple`
- [ ] `revokeAppleRefreshToken` callable from `onUserDelete`

## Account deletion (App Review enforces)
- [ ] Delete flow forces fresh sign-in to get usable authorizationCode
- [ ] `firebase.revokeTokenWithAuthorizationCode(...)` called BEFORE `user.delete()`
- [ ] After deletion, app no longer appears in Settings → Apple ID → Sign-In & Security → Apps Using Apple ID
- [ ] TestFlight build tested for full delete + revoke + re-sign-in cycle

## Apple Guideline 4.8
- [ ] If shipping with Google or any third-party social login on iOS → Sign in with Apple ALSO present
- [ ] SIWA button visible alongside other social options (NOT hidden)
- [ ] Email scope and FullName scope both requested

## Hide My Email
- [ ] Sender domain registered with Apple
- [ ] Test email to a Hide-My-Email relay address arrives within 1 min
- [ ] Bounce notification handled (user re-prompted for primary email)

## Fail-safe
- [ ] User cancels Apple flow → graceful handling (no error toast)
- [ ] Network failure during sign-in → retryable error message
- [ ] `invalid OAuth response` regression test (rotate one of nonce hash/raw → confirm error appears)

## Compliance
- [ ] Privacy policy mentions Apple ID + relay address as data we may collect
- [ ] KVKK Aydınlatma Metni references Apple sign-in path
- [ ] Audit log entry on each successful revocation (hashed UID + timestamp)
