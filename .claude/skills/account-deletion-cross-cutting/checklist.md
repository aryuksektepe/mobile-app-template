# Account Deletion — Verification Checklist

Owned by `compliance` agent. Run on every phase that touches user data subsystems (auth, payments, push, analytics, crash, storage).

## Discoverability (App Review)
- [ ] "Delete account" button reachable ≤ 2 taps from main Account screen
- [ ] Label is "Delete account" / "Hesabı sil" — NOT "Deactivate" / "Close"
- [ ] In-app actionable (no web/email-only path)
- [ ] iOS + Android both have it (parity)

## Confirmation
- [ ] Modal uses destructive (error-color) UI
- [ ] Typed "DELETE" / "SIL" confirmation gate (anti-mistap)
- [ ] Active sub warning + store deep link present when sub exists
- [ ] Clear copy: "data deleted within 30 days" + "sign in within 30 days to restore"

## Step-by-step coverage
- [ ] 1. Confirmation modal (covered above)
- [ ] 2. Subscription warning + deep link (when applicable)
- [ ] 3. Reauthentication (provider-specific)
- [ ] 4. Server soft-delete (status='pending_delete', deleted_at=now())
- [ ] 5. Apple token revocation (only if SIWA used) — verified server-side
- [ ] 6. RevenueCat user DELETE via REST (server-side, secret key)
- [ ] 7. FCM `deleteToken()` + server row removal
- [ ] 8. Analytics setUserId(null) + resetAnalyticsData + Crashlytics clear + Sentry clear
- [ ] 9. Secure storage deleteAll + Drift wipe + FirebaseAuth.delete

## Server side
- [ ] `users.status = 'pending_delete'` row visible after step 4
- [ ] Read paths filter `status != 'pending_delete'`
- [ ] Hard-purge cron deployed + last-run timestamp visible
- [ ] After 30+ days, expired soft-deletes are gone from DB

## Idempotency
- [ ] Each step retryable without side effects (re-run after network fail = no double charge / double notification)
- [ ] `AccountDeletionError(step, cause)` thrown on each irrecoverable failure

## Privacy policy
- [ ] Policy mentions 30-day retention window
- [ ] Policy mentions BigQuery / analytics historical row DSAR SLA (if EU users)

## E2E test
- [ ] `integration_test/account_deletion_test.dart` runs the full flow on a real device
- [ ] Test asserts: typed gate works, sub warning shows, success redirect to /welcome, server row state correct
