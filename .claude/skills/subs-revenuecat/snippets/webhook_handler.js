// RevenueCat webhook receiver. Pseudocode shape — adapt to your backend
// (Express, Cloudflare Worker, Cloud Function, Hono, etc.).
//
// Critical rules:
//   1. Authenticate every request via the Authorization header you set
//      in the RC dashboard. The old `x-revenuecat-signature` was removed.
//   2. Be idempotent. Dedupe by `event.id` — RC delivers at-least-once.
//   3. Return 2xx fast. Process heavy work async (queue) if needed.
//   4. Never expose this endpoint without auth.
//
// Reference: https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields

const RC_WEBHOOK_SECRET = process.env.RC_WEBHOOK_SECRET; // matches RC dashboard config

async function handleRevenueCatWebhook(req, res) {
  // 1. Auth
  const authHeader = req.headers['authorization'] || req.headers['Authorization'];
  if (authHeader !== RC_WEBHOOK_SECRET) {
    return res.status(401).send('Unauthorized');
  }

  // 2. Parse + sanity
  const body = req.body;
  if (!body || !body.event || !body.event.id || !body.event.type) {
    return res.status(400).send('Bad payload');
  }
  const event = body.event;

  // 3. Idempotency — bail early on duplicates
  const seen = await db.webhookEvents.exists(event.id);
  if (seen) {
    return res.status(200).send('Duplicate, already processed');
  }
  await db.webhookEvents.insert({
    id: event.id,
    type: event.type,
    received_at: new Date(),
  });

  // 4. Switch on event.type
  // See https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields
  try {
    switch (event.type) {
      case 'INITIAL_PURCHASE':
      case 'RENEWAL':
      case 'UNCANCELLATION':
      case 'PRODUCT_CHANGE':
      case 'SUBSCRIPTION_EXTENDED':
      case 'TEMPORARY_ENTITLEMENT_GRANT':
      case 'NON_RENEWING_PURCHASE':
        await grantEntitlement({
          appUserId: event.app_user_id,
          entitlementIds: event.entitlement_ids || [],
          expiresAt: event.expiration_at_ms ? new Date(event.expiration_at_ms) : null,
          productId: event.product_id,
          eventId: event.id,
        });
        break;

      case 'CANCELLATION':
        // Subscription will not auto-renew. Entitlement still active until expiration.
        // Do NOT revoke immediately — just mark as cancelled.
        await markCancelled({
          appUserId: event.app_user_id,
          entitlementIds: event.entitlement_ids || [],
          expiresAt: event.expiration_at_ms ? new Date(event.expiration_at_ms) : null,
        });
        break;

      case 'EXPIRATION':
      case 'SUBSCRIPTION_PAUSED':
        await revokeEntitlement({
          appUserId: event.app_user_id,
          entitlementIds: event.entitlement_ids || [],
        });
        break;

      case 'BILLING_ISSUE':
        // Payment failed but Apple/Google retry for ~16 days. Entitlement
        // may still be active (grace period). Flag for in-app nudge.
        await flagBillingIssue({
          appUserId: event.app_user_id,
          gracePeriodExpiresAt: event.grace_period_expiration_at_ms
            ? new Date(event.grace_period_expiration_at_ms)
            : null,
        });
        break;

      case 'REFUND_REVERSED':
        // Refund was reversed → grant entitlement back.
        await grantEntitlement({
          appUserId: event.app_user_id,
          entitlementIds: event.entitlement_ids || [],
          expiresAt: event.expiration_at_ms ? new Date(event.expiration_at_ms) : null,
          productId: event.product_id,
          eventId: event.id,
        });
        break;

      case 'TRANSFER':
        // Subscription transferred from one app_user_id to another
        // (e.g., user signed in on a new device under different identity).
        await transferEntitlements({
          fromAppUserId: event.transferred_from?.[0],
          toAppUserId: event.transferred_to?.[0],
        });
        break;

      case 'TEST':
        // Sent when you click "Send Test Event" in RC dashboard. No-op.
        break;

      default:
        // Unknown event type — log but don't fail. RC may add new types.
        console.warn('Unhandled RC webhook event type:', event.type);
    }

    return res.status(200).send('OK');
  } catch (err) {
    // Don't ack on error — RC will retry up to 3 times with backoff.
    console.error('Webhook processing failed:', err);
    // Remove the dedup record so retry is processed.
    await db.webhookEvents.delete(event.id);
    return res.status(500).send('Processing failed');
  }
}

// Implement these against your data store + your business logic.
async function grantEntitlement({ appUserId, entitlementIds, expiresAt, productId, eventId }) {
  // UPSERT user_entitlements (user_id, entitlement_id, expires_at, source_product_id, source_event_id)
}
async function markCancelled({ appUserId, entitlementIds, expiresAt }) {
  // UPDATE user_entitlements SET cancelled_at = now() WHERE user_id = ? AND entitlement_id IN ?
}
async function revokeEntitlement({ appUserId, entitlementIds }) {
  // UPDATE user_entitlements SET expired_at = now() WHERE user_id = ? AND entitlement_id IN ?
}
async function flagBillingIssue({ appUserId, gracePeriodExpiresAt }) {
  // INSERT user_flags (user_id, kind='billing_issue', expires_at)
}
async function transferEntitlements({ fromAppUserId, toAppUserId }) {
  // UPDATE user_entitlements SET user_id = toAppUserId WHERE user_id = fromAppUserId
}

module.exports = { handleRevenueCatWebhook };
