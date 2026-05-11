# Promo Codes — Implementation Guide

## 1. Prerequisites
- `firebase-core-setup` complete (App Check enabled)
- `deeplinks-go-router` complete (for referral landing pages)
- (If granting paid subs) `subs-revenuecat` complete

## 2. Add packages

**Flutter:**
```bash
flutter pub add cloud_functions firebase_app_check crypto
```

**Backend (Cloud Functions):**
```bash
cd functions
npm install firebase-functions firebase-admin node-fetch
npm install --save-dev tsx  # for admin scripts
```

## 3. Firestore schema

| Collection | Doc ID | Fields |
|---|---|---|
| `promoCodes` | `<CODE>` | `type`, `value`, `maxRedemptions`, `maxRedemptionsPerUser`, `redeemedCount`, `disabled`, `regions[]`, `expiresAt`, `grantDurationDays`, `createdAt` |
| `redemptions` | `<CODE>_<UID>` | `uid`, `code`, `redeemedAt`, `type`, `value`, `country` |
| `users/{uid}/entitlements` | `<TYPE>` | `grantedBy`, `code`, `value`, `grantedAt`, `expiresAt` |
| `rateLimits` | `promo_<UID>` | `attempts: number[]` |
| `referrals/{referrerUid}/referees` | `<refereeUid>` | `code`, `signedUpAt`, `convertedAt`, `creditedAt` |

Composite ID `{code}_{uid}` makes redemption idempotent — concurrent attempts can't double-write.

## 4. Deploy security rules

Use [snippets/firestore.rules](snippets/firestore.rules). Critical rules:
- `promoCodes` read=write=`false` (force redemption via Cloud Function)
- `redemptions` read=own, write=Admin SDK only
- `entitlements` read=own, write=Admin SDK only

```bash
firebase deploy --only firestore:rules
```

## 5. Deploy redemption Cloud Function

Use [snippets/redeem_function.ts](snippets/redeem_function.ts). Key features:
- `enforceAppCheck: true` — blocks emulator/script abuse.
- Region pinned to `europe-west1` for KVKK.
- Validates Crockford Base32 alphabet (no I/L/O/U).
- Per-user rate limit (5 attempts/min sliding window).
- Atomic transaction: read code + check redemption → write both atomically.
- Handles expiry, exhaustion, region gate, per-user cap.

Deploy:
```bash
firebase deploy --only functions:redeemPromoCode
```

## 6. Generate codes

Use [snippets/code_generator.ts](snippets/code_generator.ts) admin script. Run with service account credentials:
```bash
GOOGLE_APPLICATION_CREDENTIALS=./service-account.json npx tsx scripts/generate_codes.ts 100 trial 1
```

Generates 100 trial codes, max 1 redemption each, 8 chars long, 30-day expiry.

For BRANDED single codes (`LAUNCH2026`), create directly in Firebase Console → Firestore → `promoCodes` collection → add document with ID `LAUNCH2026`.

## 7. Wire Riverpod controller + UI

Use [snippets/promo_controller.dart](snippets/promo_controller.dart). Key behaviors:
- Auto-uppercase, allowlist Crockford alphabet via `inputFormatters`.
- Logs `promo_redeem_attempt` / `_success` / `_failure` with `code_hash`, NOT raw code (privacy + leak prevention).
- Refreshes entitlement state on success.

Sample screen:
```dart
class RedeemPromoScreen extends ConsumerStatefulWidget { ... }

class _State extends ConsumerState<RedeemPromoScreen> {
  String _code = '';
  @override
  Widget build(ctx) {
    final state = ref.watch(promoControllerProvider);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          PromoInput(onChanged: (v) => setState(() => _code = v)),
          FilledButton(
            onPressed: state.isLoading ? null : () =>
              ref.read(promoControllerProvider.notifier).redeem(_code),
            child: const Text('Kullan'),
          ),
          if (state.hasError) Text('Hata: ${state.error}', style: TextStyle(color: Colors.red)),
          if (state.valueOrNull != null) const Text('Başarılı! Yeni özelliklerin aktif.'),
        ]),
      ),
    );
  }
}
```

## 8. Referral codes

### 8.1 Generate user-specific codes

When user opens "Refer a friend" screen:
```typescript
// functions/src/createReferralCode.ts
export const createReferralCode = onCall(
  { enforceAppCheck: true },
  async (req) => {
    if (!req.auth) throw new HttpsError('unauthenticated', '');
    const uid = req.auth.uid;
    // Deterministic per user (so same user sees same code)
    const code = `REF${shortHashOf(uid).toUpperCase()}`;  // e.g. REF7K9MQR
    await db.doc(`promoCodes/${code}`).set({
      type: 'referral_credit',
      value: 50,                  // credits granted to referee
      maxRedemptions: 1000,
      maxRedemptionsPerUser: 1,
      referrerUid: uid,
      disabled: false,
      grantDurationDays: 0,
    }, { merge: true });
    return { code };
  },
);
```

### 8.2 Deep link share

Build URL: `https://yourdomain.com/r/REF7K9MQR` (handled by `deeplinks-go-router` skill).

Share via Flutter `share_plus` package.

### 8.3 Defer crediting referrer

When referee redeems, **don't credit referrer immediately**. Watch for conversion event:
```typescript
export const onRefereeConvert = onDocumentCreated(
  'users/{uid}/subscriptions/{subId}',
  async (event) => {
    const refereeUid = event.params.uid;
    // find any redemption by this referee with type=referral_credit
    const redemptions = await db.collection('redemptions')
      .where('uid', '==', refereeUid)
      .where('type', '==', 'referral_credit')
      .get();
    for (const r of redemptions.docs) {
      const code = r.data().code;
      const codeDoc = await db.doc(`promoCodes/${code}`).get();
      const referrerUid = codeDoc.data()?.referrerUid;
      if (referrerUid && !r.data().referrerCreditedAt) {
        // grant credits to referrer
        await db.doc(`users/${referrerUid}/credits/balance`).set({
          amount: FieldValue.increment(100),
        }, { merge: true });
        await r.ref.update({ referrerCreditedAt: FieldValue.serverTimestamp() });
      }
    }
  },
);
```

## 9. RevenueCat promotional grants

For paid sub unlocks: use [snippets/rc_grant.ts](snippets/rc_grant.ts) AFTER successful redemption. Triggered from Firestore onCreate of `users/{uid}/entitlements/{type}`:

```typescript
export const onEntitlementGranted = onDocumentCreated(
  'users/{uid}/entitlements/{type}',
  async (event) => {
    const data = event.data?.data();
    if (data?.grantedBy === 'promo' && data?.type === 'pro_monthly') {
      await grantRevenueCatPromotional({
        rcAppUserId: event.params.uid,
        entitlementId: 'pro',
        durationDays: data.grantDurationDays || 30,
      });
    }
  },
);
```

## 10. Verify

Run [checklist.md](checklist.md). Critical:
- App Check enforced — call from emulator without debug token → rejected.
- Concurrent double-redeem rejected (composite ID + transaction).
- Region gate enforced server-side, NOT just client.
- Referrer credited only AFTER referee converts.
