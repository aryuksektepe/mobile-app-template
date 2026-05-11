// functions/src/redeemPromoCode.ts
//
// Cloud Function (TypeScript, Node 22). Callable, App Check enforced.
// Atomic redemption via Firestore transaction.
//
// Returns:
//   { ok: true, type, value } on success
// Throws HttpsError on:
//   unauthenticated, invalid_format, code_not_found, code_disabled,
//   code_expired, code_exhausted, already_redeemed, region_blocked,
//   rate_limited

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { initializeApp } from 'firebase-admin/app';

initializeApp();

// Crockford Base32 alphabet — no I/L/O/U
const VALID_CODE = /^[0-9A-HJKMNP-TV-Z]{4,16}$/;

export const redeemPromoCode = onCall(
  {
    enforceAppCheck: true,                 // BLOCKS scripts/emulators
    region: 'europe-west1',                // KVKK / EU residency
    cors: false,                            // callable handles CORS
  },
  async (req) => {
    if (!req.auth) {
      throw new HttpsError('unauthenticated', 'auth_required');
    }
    const uid = req.auth.uid;

    const raw = String(req.data?.code ?? '');
    const code = raw.trim().toUpperCase().replace(/\s+/g, '');
    if (!VALID_CODE.test(code)) {
      throw new HttpsError('invalid-argument', 'invalid_format');
    }

    // Per-user rate limit (sliding window 5 attempts / minute)
    await checkRateLimit(uid);

    const db = getFirestore();
    const codeRef = db.doc(`promoCodes/${code}`);
    const redemptionRef = db.doc(`redemptions/${code}_${uid}`);

    return await db.runTransaction(async (tx) => {
      const [codeSnap, redemptionSnap] = await Promise.all([
        tx.get(codeRef),
        tx.get(redemptionRef),
      ]);

      if (!codeSnap.exists) throw new HttpsError('not-found', 'code_not_found');
      const c = codeSnap.data()!;

      if (c.disabled) throw new HttpsError('failed-precondition', 'code_disabled');

      if (c.expiresAt && (c.expiresAt as Timestamp).toMillis() < Date.now()) {
        throw new HttpsError('failed-precondition', 'code_expired');
      }

      if (c.maxRedemptions && c.redeemedCount >= c.maxRedemptions) {
        throw new HttpsError('resource-exhausted', 'code_exhausted');
      }

      if (redemptionSnap.exists) {
        // Composite ID makes this an idempotent retry: bail without re-charging.
        return { ok: true, type: c.type, value: c.value, idempotent: true };
      }

      // Region gate (Cloud Functions geolocation; spoofable but better than client locale).
      const country = (req.rawRequest.headers['x-appengine-country'] as string | undefined)?.toUpperCase();
      if (Array.isArray(c.regions) && c.regions.length > 0 && country && !c.regions.includes(country)) {
        throw new HttpsError('failed-precondition', 'region_blocked');
      }

      // Per-user redemption cap (e.g., max 1 per user for branded codes)
      if (c.maxRedemptionsPerUser) {
        const userRedemptionsQ = await db
          .collection('redemptions')
          .where('uid', '==', uid)
          .where('code', '==', code)
          .limit(c.maxRedemptionsPerUser + 1)
          .get();
        if (userRedemptionsQ.size >= c.maxRedemptionsPerUser) {
          throw new HttpsError('failed-precondition', 'user_cap_reached');
        }
      }

      // Atomic write
      tx.set(redemptionRef, {
        uid,
        code,
        redeemedAt: FieldValue.serverTimestamp(),
        type: c.type,
        value: c.value,
        country: country ?? null,
      });

      tx.update(codeRef, {
        redeemedCount: FieldValue.increment(1),
        lastRedeemedAt: FieldValue.serverTimestamp(),
      });

      // Grant entitlement.
      // For PAID subscriptions, call RevenueCat REST grant from a separate
      // post-redemption hook — see snippets/rc_grant.ts. Don't do REST inside
      // a transaction (transactions only support Firestore reads/writes).
      tx.set(
        db.doc(`users/${uid}/entitlements/${c.type}`),
        {
          grantedBy: 'promo',
          code,
          value: c.value,
          grantedAt: FieldValue.serverTimestamp(),
          expiresAt: c.grantDurationDays
            ? Timestamp.fromMillis(Date.now() + c.grantDurationDays * 86400000)
            : null,
        },
        { merge: true },
      );

      return { ok: true, type: c.type, value: c.value };
    });
  },
);

async function checkRateLimit(uid: string): Promise<void> {
  const db = getFirestore();
  const ref = db.doc(`rateLimits/promo_${uid}`);
  const now = Date.now();
  const windowStart = now - 60_000;          // 1 min window

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const attempts: number[] = (snap.exists ? snap.data()?.attempts ?? [] : [])
      .filter((t: number) => t >= windowStart);

    if (attempts.length >= 5) {
      throw new HttpsError('resource-exhausted', 'rate_limited');
    }

    attempts.push(now);
    tx.set(ref, { attempts }, { merge: true });
  });
}
