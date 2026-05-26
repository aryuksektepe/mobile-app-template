# Account Deletion — Implementation Notes

## Apple Sign in with Apple — token revocation

If your app offers SIWA, Apple Guideline 5.1.1(v) requires revocation. Without it, App Review rejects "deletion is incomplete." The REST flow:

1. On signup, persist the Apple `refreshToken` server-side (NOT just the ID token).
2. On account deletion (step 5 of the canonical order):
   ```
   POST https://appleid.apple.com/auth/revoke
   Content-Type: application/x-www-form-urlencoded
   client_id={your service id}&client_secret={signed JWT from .p8}&token={refresh_token}&token_type_hint=refresh_token
   ```
3. `client_secret` is a JWT signed with your Apple `.p8` key (5-min TTL). Reuse the same signer you built for Sign in with Apple server validation.

Note: this MUST run server-side (the `.p8` key cannot ship to the client).

## RevenueCat user delete

```
DELETE https://api.revenuecat.com/v1/subscribers/{app_user_id}
Authorization: Bearer <SECRET_API_KEY>  # not the public SDK key
```

Returns 200 with `was_deleted: true` even if user didn't exist (idempotent — good).

The SDK call `Purchases.logOut()` on the client is NOT a delete — it just unsets the local user. The REST call above is the actual delete.

## FCM token cleanup

```dart
await FirebaseMessaging.instance.deleteToken();  // device-side
```

Plus a server-side delete of the `(userId, deviceId, token)` row(s) so push targeting can't accidentally re-acquire. The `notifications-fcm` skill explains the multi-device storage shape.

## Analytics + Crash reporter

```dart
await FirebaseAnalytics.instance.setUserId(id: null);
await FirebaseAnalytics.instance.resetAnalyticsData();   // wipes pseudonymous client ID
await FirebaseCrashlytics.instance.setUserIdentifier('');
await Sentry.configureScope((s) => s.setUser(null));
```

Important: `resetAnalyticsData()` does NOT delete historical analytics rows in BigQuery — that's a separate GDPR DSAR (Data Subject Access Request) flow if EU/UK. Document the SLA.

## Server-side soft delete + hard purge

The "soft delete now, hard delete in 30 days" pattern:

- Step 4 sets `status='pending_delete', deleted_at=now()` in your `users` table. All read paths filter `status != 'pending_delete'`.
- A scheduled job (cron / Cloud Scheduler / Supabase cron) runs daily and hard-deletes rows where `deleted_at < now() - interval '30 days'`. See [snippets/purge_pending_deletions.ts](snippets/purge_pending_deletions.ts).
- During the 30-day window, the user CAN sign in again — which restores their account (`status='active'`, clear `deleted_at`). This handles "deleted by mistake" — encourage the UI to mention this.

KVKK/GDPR §17 allows a "reasonable" delay for backups to age out (30-90 days is conventional). Document the policy in your `.project/legal/privacy-policy.md`.

## Reauthentication

Firebase Auth's `user.delete()` throws `requires-recent-login` if the last sign-in was >5 minutes ago. Reauth flow:

```dart
final user = FirebaseAuth.instance.currentUser!;
// For email/pwd:
final cred = EmailAuthProvider.credential(email: user.email!, password: enteredPassword);
await user.reauthenticateWithCredential(cred);
// For Google / Apple / phone: reuse the respective provider's reauthenticate flow.
```

If using biometric reauth (skill: `secure-storage-tokens`), trigger that here instead of password prompt.

## Subscription warning copy

Apple 3.1.1 + Play billing policy: subscriptions are NOT cancelled by deleting the in-app account. The user must cancel in:
- iOS: Settings → Apple ID → Subscriptions
- Android: Play Store → Profile → Payments & subscriptions → Subscriptions

Show this warning BEFORE step 4. Provide deep links (iOS `itms-apps://apps.apple.com/account/subscriptions`, Android `https://play.google.com/store/account/subscriptions`).

## Store-reviewer discoverability

Apple/Play check the deletion flow's reachability during review. Requirements:
- Settings → Account → Delete account (≤ 2 taps from main "Account" screen).
- The button label MUST say "Delete account" (or local equivalent: "Hesabı sil"), NOT "Close account" / "Deactivate".
- The deletion MUST be possible IN-APP — NOT just "email us" / a web form (that's the old failure pattern Apple rejected).

## Compliance agent checklist tie-in

Add to `compliance` agent's per-phase checklist:
- [ ] Account deletion still reachable ≤ 2 taps from main Account UI?
- [ ] All 9 steps still wired (regression after adding a new SDK)?
- [ ] Hard-purge cron last-run timestamp visible?

## Testing the flow

Real-device E2E test in `integration_test/account_deletion_test.dart`:
1. Sign up with a throwaway email + buy a sandbox sub.
2. Trigger Settings → Account → Delete.
3. Verify: typed-confirmation gate, sub warning, reauth, success toast, redirect to /welcome.
4. Try to sign in again with same email → app shows "account scheduled for deletion — sign in to restore" OR account is truly gone (depending on whether you're testing during or after the soft-delete window).
5. Check server: row exists with `status='pending_delete'`. Trigger cron manually → row gone.
