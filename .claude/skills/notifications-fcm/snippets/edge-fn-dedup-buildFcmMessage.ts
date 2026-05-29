// Deno (Supabase Edge Function) — build an FCM HTTP v1 message with OS-level
// dedup keys so duplicate sends collapse on the device instead of stacking.
// Pairs with the Flutter side's local-notification ID generator
// (notification_service.dart).
//
// Pitfall: hybrid local-scheduled + server-FCM can fire 2 notifications for
// the same slot if local fires first then FCM arrives — cancel-after-fire is
// impossible. OS-level dedup is the only reliable layer.
//
//   iOS:     apns-collapse-id header → newest replaces previous
//   Android: notification.tag        → newest replaces previous

interface SendTarget {
  fcm_token: string;
  subscription_id: string;
  days_until: number;   // -7..3 etc
  title: string;
  body: string;
  channel_id: string;   // Android channel
  deep_link?: string;
}

export function buildFcmMessage(target: SendTarget) {
  // Deterministic dedup key — MUST match across local + FCM for the same slot.
  const dedupKey = `sub_${target.subscription_id}_day_${target.days_until}`;

  return {
    message: {
      token: target.fcm_token,
      notification: { title: target.title, body: target.body },
      data: target.deep_link ? { deep_link: target.deep_link } : undefined,
      apns: {
        headers: {
          // iOS collapses notifications sharing this id into the latest one.
          "apns-collapse-id": dedupKey,
        },
        payload: {
          aps: {
            alert: { title: target.title, body: target.body },
            sound: "default",
          },
        },
      },
      android: {
        priority: "high",
        notification: {
          channel_id: target.channel_id,
          // Same-tag notifications replace in the shade.
          tag: dedupKey,
        },
      },
    },
  };
}
