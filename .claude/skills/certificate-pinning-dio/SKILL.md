---
name: certificate-pinning-dio
description: Certificate / public-key pinning for production API calls via Dio — pins the server's leaf or intermediate public key, debug-build bypass for dev, fallback secondary pin for rotation safety, MITM detection that fails closed (no silent retry). MASVS-NETWORK-1. Use whenever the app talks to a production REST/GraphQL backend that handles auth, payments, or PII.
triggers: [certificate pinning, public key pinning, ssl pinning, MITM, man in the middle, mas vs, MASVS, dio interceptor pinning, SecurityContext, HandshakeException, pin rotation, badCertificateCallback, network security config]
platforms: [ios, android]
last_verified: 2026-05-26
flutter_min: "3.22.0"
package_versions:
  dio: "^5.7.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: [secure-storage-tokens]
---

# Certificate Pinning — Dio

## What this skill does

- Adds **public-key pinning** (NOT cert pinning — keys outlive cert rotation) to Dio via custom `SecurityContext` + `HttpClient.badCertificateCallback` with SPKI hash verification.
- **Two pins** (primary + backup) so cert rotation never bricks the app.
- **Debug-build bypass** so Charles/Proxyman work in `flutter run`.
- **Fail-closed** — pin mismatch → request rejected, NOT silently fall through.
- Optional native fallback: iOS `NSAppTransportSecurity` ATS pin + Android `network_security_config.xml` declarative pin (defense in depth).
- Documents the rotation runbook (you MUST rotate the backup pin BEFORE the primary cert expires, ship via Remote Config or new app version).

## What this skill does NOT do

- Does NOT bypass system trust — bad CA bundle = bad pinning. Use trusted CAs.
- Does NOT pin custom-cert APIs (banks with self-signed) — that's a different setup; this skill is for public-CA endpoints.

## Decision tree

**Q1: Leaf cert, intermediate, or root pin?**
- LEAF — most secure; breaks every cert renewal. Avoid unless ultra-high-risk app.
- INTERMEDIATE — recommended balance; intermediate CAs rotate every 2-5 years.
- ROOT — convenient but kills the whole pinning value (root rotates rarely; broad trust).

**Q2: Pin certificate or public key?**
- PUBLIC KEY (SPKI hash) — recommended. Survives cert reissuance if same keypair. Standard `sha256/base64==` format.
- CERTIFICATE — easier to extract; breaks on every renewal.

**Q3: Single pin or backup?**
- BACKUP IS MANDATORY — without it, missing the rotation = bricked app for everyone.

## Quick start

1. Extract the SPKI hash of your production endpoint:
   ```bash
   openssl s_client -servername api.yourdomain.com -connect api.yourdomain.com:443 < /dev/null 2>/dev/null \
     | openssl x509 -pubkey -noout \
     | openssl pkey -pubin -outform der \
     | openssl dgst -sha256 -binary \
     | openssl enc -base64
   ```
   That's your **primary pin**. Repeat against your CDN/backup origin for the **backup pin**.

2. Apply [snippets/pinned_dio.dart](snippets/pinned_dio.dart). Wire as your app's Dio instance.

3. Verify: turn on Charles/Proxyman in front of a release build → request must fail with `HandshakeException`. (Debug build still works — bypass intentional.)

## Code patterns

| Need | File |
|---|---|
| Pinned Dio factory + SPKI verification | [snippets/pinned_dio.dart](snippets/pinned_dio.dart) |
| Android network_security_config.xml | [snippets/network_security_config.xml](snippets/network_security_config.xml) |

## Known pitfalls

→ [pitfalls.md](pitfalls.md). Top 5:
1. Single pin shipped → cert rotated → entire user base bricked. ALWAYS include backup pin.
2. Pinned cert (not public key) → cert reissuance breaks pinning even though key didn't change.
3. Debug bypass left enabled in release → pinning silently OFF in prod.
4. `badCertificateCallback` returns `true` unconditionally as a "temporary fix" → pinning permanently off.
5. Forgot to extract pin from PROD endpoint — used staging cert → first prod call rejects.

## Verification

→ [checklist.md](checklist.md).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-26
- Depends on: `secure-storage-tokens` (same Dio instance pattern)
