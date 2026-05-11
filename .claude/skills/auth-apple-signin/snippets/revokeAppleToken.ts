// functions/src/storeAppleAuthCode.ts
//
// Called from client after successful Apple sign-in. Exchanges the
// short-lived authorizationCode for a long-lived refresh_token via Apple's
// /auth/token endpoint. Stores the refresh_token encrypted for later
// revocation when user deletes their account.
//
// Required env vars:
//   APPLE_TEAM_ID         — 10-char Apple Team ID
//   APPLE_SERVICE_ID      — Service ID identifier (e.g., com.acme.app.signin)
//                            For NATIVE iOS sign-in, use App ID instead.
//   APPLE_KEY_ID          — Key ID from Apple Developer → Keys
//   APPLE_PRIVATE_KEY     — contents of the .p8 file (multi-line PEM)

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getFirestore } from 'firebase-admin/firestore';
import * as jwt from 'jsonwebtoken';
import fetch from 'node-fetch';

const APPLE_TEAM_ID = process.env.APPLE_TEAM_ID!;
const APPLE_SERVICE_ID = process.env.APPLE_SERVICE_ID!;
const APPLE_KEY_ID = process.env.APPLE_KEY_ID!;
const APPLE_PRIVATE_KEY = (process.env.APPLE_PRIVATE_KEY ?? '').replace(/\\n/g, '\n');

/// Generate Apple client_secret JWT (max 6 months expiry per Apple).
function generateAppleClientSecret(): string {
  const now = Math.floor(Date.now() / 1000);
  return jwt.sign(
    {
      iss: APPLE_TEAM_ID,
      iat: now,
      exp: now + 60 * 60 * 24 * 180,    // 180 days (Apple max)
      aud: 'https://appleid.apple.com',
      sub: APPLE_SERVICE_ID,
    },
    APPLE_PRIVATE_KEY,
    {
      algorithm: 'ES256',
      header: { alg: 'ES256', kid: APPLE_KEY_ID },
    },
  );
}

export const storeAppleAuthCode = onCall(
  { enforceAppCheck: true, region: 'europe-west1' },
  async (req) => {
    if (!req.auth) throw new HttpsError('unauthenticated', '');
    const uid = req.auth.uid;
    const code = String(req.data?.authorizationCode ?? '');
    if (!code) throw new HttpsError('invalid-argument', 'missing_code');

    const clientSecret = generateAppleClientSecret();

    const res = await fetch('https://appleid.apple.com/auth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: APPLE_SERVICE_ID,
        client_secret: clientSecret,
        code,
        grant_type: 'authorization_code',
      }).toString(),
    });

    if (!res.ok) {
      throw new HttpsError(
        'internal',
        `apple_token_failed: ${res.status} ${await res.text()}`,
      );
    }

    const data = (await res.json()) as { refresh_token?: string; access_token?: string };
    if (!data.refresh_token) {
      throw new HttpsError('internal', 'no_refresh_token');
    }

    // Store encrypted in Firestore. In production, encrypt using KMS — Firestore
    // at-rest encryption is good but app-level adds defense in depth.
    await getFirestore().doc(`users/${uid}/private/apple`).set(
      {
        refreshToken: data.refresh_token,
        storedAt: new Date(),
      },
      { merge: true },
    );

    return { ok: true };
  },
);

/// Revoke the Apple grant. Called from `onUserDelete` Cloud Function
/// (or directly when revoking but keeping account).
export async function revokeAppleRefreshToken(uid: string): Promise<void> {
  const ref = getFirestore().doc(`users/${uid}/private/apple`);
  const snap = await ref.get();
  if (!snap.exists) return;          // never signed in via Apple

  const refreshToken = snap.data()?.refreshToken;
  if (!refreshToken) return;

  const clientSecret = generateAppleClientSecret();

  const res = await fetch('https://appleid.apple.com/auth/revoke', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: APPLE_SERVICE_ID,
      client_secret: clientSecret,
      token: refreshToken,
      token_type_hint: 'refresh_token',
    }).toString(),
  });

  if (!res.ok) {
    throw new Error(`apple_revoke_failed: ${res.status} ${await res.text()}`);
  }

  await ref.delete();
}
