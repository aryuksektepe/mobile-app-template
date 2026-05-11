// functions/src/onUserDelete.ts
//
// Triggered when user.delete() is called from client.
// Purges related data within 30 days (KVKK Art. 7 / GDPR Art. 17).
//
// Alternative: install the Firebase "Delete User Data" extension from
// https://firebase.google.com/docs/extensions/official/delete-user-data
// — handles common patterns (Firestore docs/collections, Storage paths, RTDB).

import { onUserDeleted } from 'firebase-functions/v2/identity';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';

export const onUserDelete = onUserDeleted(async (event) => {
  const uid = event.data.uid;
  const db = getFirestore();
  const bucket = getStorage().bucket();

  // 1. Audit log (write-once, hashed UID for compliance audit)
  const hashedUid = await sha256(uid);
  await db.collection('deletionAudit').add({
    hashedUid,
    deletedAt: FieldValue.serverTimestamp(),
    initiatedBy: 'user',
  });

  // 2. Delete user document + subcollections
  await deleteCollectionRecursive(db, `users/${uid}`);

  // 3. Delete user-owned data in shared collections
  // ADJUST queries to your schema:
  await deleteByQuery(db, db.collection('posts').where('authorUid', '==', uid));
  await deleteByQuery(db, db.collection('redemptions').where('uid', '==', uid));
  await deleteByQuery(db, db.collection('user_fcm_tokens').where('user_id', '==', uid));

  // 4. Delete Storage paths
  await bucket.deleteFiles({ prefix: `users/${uid}/` });
  await bucket.deleteFiles({ prefix: `avatars/${uid}/` });

  // 5. Delete from RevenueCat (if used)
  // await fetch(`https://api.revenuecat.com/v1/subscribers/${uid}`, {
  //   method: 'DELETE',
  //   headers: { Authorization: `Bearer ${process.env.RC_SECRET_API_KEY}` },
  // });

  // 6. Cleanup analytics user identifier (BigQuery) — separate batch job
  // queueAnalyticsScrub(uid);
});

async function deleteCollectionRecursive(db: FirebaseFirestore.Firestore, path: string) {
  const ref = db.doc(path);
  const subcollections = await ref.listCollections();
  for (const sub of subcollections) {
    await deleteByQuery(db, sub);
  }
  await ref.delete();
}

async function deleteByQuery(db: FirebaseFirestore.Firestore, query: FirebaseFirestore.Query) {
  const batchSize = 400;
  while (true) {
    const snap = await query.limit(batchSize).get();
    if (snap.empty) return;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    if (snap.size < batchSize) return;
  }
}

async function sha256(input: string): Promise<string> {
  const { createHash } = await import('crypto');
  return createHash('sha256').update(input).digest('hex');
}
