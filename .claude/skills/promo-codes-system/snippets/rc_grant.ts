// functions/src/grantRevenueCatPromotional.ts
//
// Server-only RevenueCat promotional entitlement grant via REST v2.
// NEVER call this from the client — secret API key would be exposed.
//
// Apple App Store 3.1.1: granting paid digital goods bypassing IAP is rejected.
// RC promotional entitlements are explicitly allowed because RC tracks them
// properly and their dashboard shows the grant origin.
//
// Trigger this AFTER a successful redemption that grants a paid sub.

import fetch from 'node-fetch';

const RC_PROJECT_ID = process.env.RC_PROJECT_ID!;
const RC_SECRET = process.env.RC_SECRET_API_KEY!;   // sk_xxx — NEVER ship in app

interface GrantParams {
  rcAppUserId: string;
  entitlementId: string;        // matches RC dashboard
  durationDays: number;
}

export async function grantRevenueCatPromotional(p: GrantParams): Promise<void> {
  const url =
    `https://api.revenuecat.com/v2/projects/${RC_PROJECT_ID}` +
    `/customers/${encodeURIComponent(p.rcAppUserId)}` +
    `/actions/grant_entitlement`;

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${RC_SECRET}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      entitlement_id: p.entitlementId,
      end_time_ms: Date.now() + p.durationDays * 86400000,
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`RC grant failed ${res.status}: ${body}`);
  }
}
