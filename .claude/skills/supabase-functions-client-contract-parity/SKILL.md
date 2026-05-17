---
name: supabase-functions-client-contract-parity
description: The Flutter client and an Edge Function disagree on HTTP method or request body field names, so the feature is dead in production while every mocked test passes. Use whenever client code calls functions.invoke / an Edge endpoint, or an Edge fn destructures req body / checks req.method.
triggers: [functions.invoke, edge function contract, POST vs GET, otp_token, body field mismatch, detect_region, account deletion fails prod, client server contract, req.method 405, supabase function 400]
platforms: [ios, android]
last_verified: 2026-05-16
flutter_min: "3.19.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: [supabase-local-verify-jwt-es256-hs256]
---

# Supabase Functions — client↔Edge contract parity

## What this skill does

Fixes ADR-032 and ADR-035, one class:

- **ADR-032:** client calls `detect_region` with **POST**, the function is
  **GET-only** → GDPR/region banner NEVER shows in prod.
- **ADR-035:** client sends `{ token: … }`, the function destructures
  `{ otp_token }` → account deletion is **impossible** in prod.

Both passed every test because the mock accepted `any(named: 'body')` / any
method — the mock **encoded the bug instead of verifying the contract**.

## Why it ships green

`when(() => client.functions.invoke(any(), body: any(named: 'body')))
.thenAnswer(...)` matches ANY method and ANY body. The test asserts the Dart
code "calls the function" — never that it calls it the way the function
actually expects. Green, broken.

## The contract is two-sided — pin both

Source of truth = the Edge function itself:
```ts
// supabase/functions/delete_account/index.ts
if (req.method !== 'POST') return new Response('method', { status: 405 });
const { otp_token } = await req.json();   // <- the exact field name
```
Client MUST match method + field names exactly:
```dart
await supabase.functions.invoke(
  'delete_account',
  method: HttpMethod.post,
  body: {'otp_token': otpToken},   // not 'token'
);
```

## The rule (enforced)

- Every `functions.invoke` / REST call has a **contract test** asserting the
  HTTP method + body field names against the real function signature (read
  `supabase/functions/<fn>/index.ts`) or the OpenAPI schema. `any(named:
  'body')` at this boundary is FORBIDDEN (test-writer Iron Rule #9,
  code-reviewer auto-HIGH).
- INTEGRATION_SMOKE / db-migration §5.5: a real authenticated call to each new
  function, 2xx, evidence pasted. A 400/405 here is a phase finding.
- Keep a generated contract (shared TS type → Dart, or an OpenAPI doc) so
  drift fails the build, not production.

## Code patterns
| Need | File |
|---|---|
| Edge fn with explicit method+body contract | [snippets/delete_account_index.ts](snippets/delete_account_index.ts) |
| Client call matching the contract | [snippets/account_repository.dart](snippets/account_repository.dart) |
| Contract-parity test (method+fields asserted) | [snippets/contract_parity_test.dart](snippets/contract_parity_test.dart) |

## Known pitfalls
→ [pitfalls.md](pitfalls.md)

## Verification
→ [checklist.md](checklist.md)

## Skill metadata
- Validation status: **pre-seeded** (ADR-032/035)
- Last verified: 2026-05-16
