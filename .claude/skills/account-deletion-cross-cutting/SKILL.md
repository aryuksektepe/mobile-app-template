---
name: account-deletion-cross-cutting
description: Production-grade "Delete My Account" flow — coordinates ALL the subsystems that hold user data (auth provider, server DB, RevenueCat user, FCM token, analytics, crash reporter, secure storage, Drift mirror, in-flight subscriptions cancellation prompt). Apple Guideline 5.1.1(v) since Jun 30 2022 + Play "Data deletion" Dec 2023 mandates an in-app deletion option that ACTUALLY deletes (not just a support email). Use whenever the app has accounts / paid subscriptions / persisted user data.
triggers: [account deletion, delete my account, delete account, KVKK silme, GDPR erasure, right to be forgotten, hesap sil, data deletion, 5.1.1(v), play account deletion, deletion flow, deletion orchestration, scrub user data]
platforms: [ios, android]
last_verified: 2026-05-26
flutter_min: "3.22.0"
ios_min: "13.0"
android_min_sdk: 24
package_versions:
  firebase_auth: "^6.0.0"
  purchases_flutter: "^9.0.0"
  firebase_messaging: "^16.0.0"
  flutter_secure_storage: "^10.0.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: [auth-firebase-email, secure-storage-tokens, subs-revenuecat, notifications-fcm, crash-monitor-dual, analytics-firebase]
---

# Account Deletion — Cross-Cutting Orchestration

## What this skill does

- A single `AccountDeletionService` that runs **9 deletion steps in correct order** with idempotent retry per step.
- Reauthentication gate (Firebase Auth `requires-recent-login` errors otherwise).
- Subscription warning — Apple/Play do NOT auto-cancel subs when account deleted; user is told to cancel in store first.
- Reachable from at least one in-app screen ≤ 2 taps from main account UI (Apple/Play requirement).
- 30-day grace window (soft delete) with hard purge job — KVKK/GDPR §17 + Apple's "actually deleted" requirement.
- Apple Sign in with Apple token **revocation** via REST (App Review enforces this — `auth-apple-signin` skill has the token detail).
- RevenueCat user delete via REST (`/v1/subscribers/{user_id}`) — DELETE method.
- FCM token deletion on the device + server-side `(userId, deviceId, token)` row removal.
- Analytics user property reset + Crashlytics user clear.
- Secure storage + Drift local mirror wipe.

## What this skill does NOT do

- Does NOT implement the server-side hard-purge cron (orchestrator's territory; provide a Cloud Function / Edge Function example).
- Does NOT handle data export ("download my data" — separate flow, also GDPR §15 mandated).
- Does NOT decide soft-delete window length — legal/product call (default 30 days here).

## The 9 steps (canonical order)

```
1. Confirm intent (modal with destructive-action UI + typed confirmation)
2. Warn about active subscriptions (NOT auto-cancelled)
3. Reauthenticate (Firebase: recent login required for delete())
4. Mark user soft-deleted server-side (status='pending_delete', deleted_at=now())
5. Revoke Apple token (REST POST to appleid.apple.com/auth/revoke) — if SIWA was used
6. Delete RevenueCat user (REST DELETE /v1/subscribers/{user_id})
7. Delete FCM token on device + server (userId, deviceId, token) row
8. Clear analytics + Crashlytics + Sentry user
9. Wipe local: Drift DB drop, secure storage delete all, then call FirebaseAuth.delete()
   → on success: sign out (router redirects to /welcome)
```

Each step is **idempotent** — re-runnable on failure without side effects.

## Quick start

```bash
# No new packages — uses existing auth + RC + secure storage + analytics deps
```

## Code patterns

| Need | File |
|---|---|
| AccountDeletionService (orchestrates 9 steps with retry) | [snippets/account_deletion_service.dart](snippets/account_deletion_service.dart) |
| Confirmation modal with typed "DELETE" gate | [snippets/delete_confirmation_modal.dart](snippets/delete_confirmation_modal.dart) |
| Server-side hard-purge Edge Function (Supabase) example | [snippets/purge_pending_deletions.ts](snippets/purge_pending_deletions.ts) |

For Apple token revocation REST signature + RC REST auth header → [implementation.md](implementation.md).

## Known pitfalls

→ [pitfalls.md](pitfalls.md) (10 entries). Top 5:
1. Step ordering wrong — `FirebaseAuth.delete()` called first → no auth context to call RC/Apple revoke REST after.
2. `requires-recent-login` → flow dies; reauth gate (step 3) is non-negotiable.
3. Apple token revocation skipped — App Review reject for SIWA-enabled apps (Apple checks).
4. Active subscriptions not warned about — user thinks deleting the account cancels billing, gets surprise charge.
5. FCM token left on server → push lands on a now-deleted user's device → wrong-account leak.

## Verification

→ [checklist.md](checklist.md) (15 items: delete is ≤ 2 taps from main account UI, each step succeeds + retries idempotently, soft-delete row visible in DB, hard-purge cron runs, store reviewer can find the flow).

## Skill metadata
- Validation status: **pre-seeded** (composed from Apple 5.1.1(v) + Play deletion policy + RC REST + FlutterFire docs)
- Last verified: 2026-05-26
- Depends on: `auth-firebase-email` + `secure-storage-tokens` + `subs-revenuecat` + `notifications-fcm` + `crash-monitor-dual` + `analytics-firebase` (each owns its sub-deletion)
