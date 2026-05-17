# Pitfalls — client↔Edge contract parity

## P1 — `any(named: 'body')` / any-method mocks
The root cause. The mock accepts the wrong shape, so the test encodes the bug.
Assert the concrete method + field names.

## P2 — Field-name drift (`token` vs `otp_token`)
A rename on one side only. Silent: client gets a generic 400 it often
swallows. Pin both sides; ideally generate a shared type.

## P3 — Method drift (POST vs GET-only)
Client POSTs to a GET-only fn → 405; feature simply never happens (ADR-032:
GDPR banner never shown). Assert method in the parity test.

## P4 — Function returns 2xx on bad input
If the fn silently ignores unknown fields and returns 200, the mismatch is
invisible even in a real call. Make the fn REJECT wrong method/missing field
(405/400) so tests and INTEGRATION_SMOKE fail loudly.

## P5 — Only mocked, never called for real
Even a strict mock can drift from the deployed fn. db-migration §5.5 /
INTEGRATION_SMOKE require a real authenticated 2xx call.

---

### Findings log
- 2026-05-16 — pre-seeded from ADR-032 (POST vs GET) + ADR-035 (token vs otp_token).
