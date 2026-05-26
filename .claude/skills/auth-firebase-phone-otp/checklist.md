# Phone OTP — Verification Checklist

- [ ] Firebase Console → Auth → Phone → Sign-in enabled
- [ ] Android: Play Integrity API enabled + SHA-256 added for every flavor (debug + upload + Play App Signing)
- [ ] iOS: APNs auth key (.p8) uploaded to Firebase
- [ ] iOS: Capabilities → Background Modes → Push Notifications + Remote notifications ON
- [ ] iOS: reCAPTCHA fallback configured (for simulator testing)
- [ ] Test phone numbers added in BOTH dev + prod Firebase projects
- [ ] `country_code_picker` defaults from device locale (not hardcoded)
- [ ] `pinput` 6-digit; paste from clipboard works
- [ ] Resend countdown 60s; resend uses `forceResendingToken`
- [ ] Auto-fill on Android tested (real device, fresh SMS)
- [ ] `verificationId` persisted in Riverpod state (survives UI rebuild)
- [ ] Error mapping covers: invalid-phone-number, invalid-verification-code, session-expired, too-many-requests, app-not-authorized, missing-client-identifier
- [ ] Account linking with email/Google/Apple works (per `auth-firebase-email`)
- [ ] Real-device E2E test: cold start → enter phone → receive SMS → enter code → home
