// scripts/generate_codes.ts
// Admin script to generate N codes with collision check.
// Run via: npx tsx scripts/generate_codes.ts <count> <type> [maxRedemptions]

import { randomBytes } from 'crypto';
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

// Crockford Base32 — no I/L/O/U
const ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

function generateCode(length = 8): string {
  const bytes = randomBytes(length);
  return Array.from(bytes, (b) => ALPHABET[b % 32]).join('');
}

async function generateUnique(length: number, attempts = 5): Promise<string> {
  for (let i = 0; i < attempts; i++) {
    const code = generateCode(length);
    const existing = await db.doc(`promoCodes/${code}`).get();
    if (!existing.exists) return code;
  }
  throw new Error(`Failed to generate unique ${length}-char code after ${attempts} attempts`);
}

async function main() {
  const [, , countArg, type, maxRedemptionsArg] = process.argv;
  const count = parseInt(countArg, 10);
  const maxRedemptions = maxRedemptionsArg ? parseInt(maxRedemptionsArg, 10) : 1;

  if (!count || !type) {
    console.error('Usage: generate_codes <count> <type> [maxRedemptions]');
    console.error('  type ∈ {discount, trial, feature, credit}');
    process.exit(1);
  }

  console.log(`Generating ${count} codes (type=${type}, max=${maxRedemptions})...`);

  const codes: string[] = [];
  const batch = db.batch();
  const expiresAt = Timestamp.fromMillis(Date.now() + 30 * 86400000); // +30d

  for (let i = 0; i < count; i++) {
    const code = await generateUnique(8);
    codes.push(code);
    batch.set(db.doc(`promoCodes/${code}`), {
      type,
      value: 0,                    // override per-code as needed
      maxRedemptions,
      maxRedemptionsPerUser: 1,
      redeemedCount: 0,
      disabled: false,
      regions: [],                 // empty = global
      expiresAt,
      createdAt: FieldValue.serverTimestamp(),
      grantDurationDays: 7,        // for trial type
    });
    if ((i + 1) % 400 === 0) {
      // Firestore batch limit = 500 ops
      await batch.commit();
      console.log(`  committed ${i + 1}/${count}`);
    }
  }
  await batch.commit();

  console.log('Done. Codes:');
  codes.forEach((c) => console.log(c));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
