# Implementation — client↔Edge contract parity

## 1. Extract the function's real contract
For each `supabase/functions/<fn>/index.ts`:
- HTTP method guard: `req.method !== 'POST'` → method = POST.
- Body destructure: `const { a, b } = await req.json()` → exact field names.
- Auth expectation (header / verify_jwt).

## 2. Make the client match exactly
`functions.invoke('<fn>', method: HttpMethod.post, body: {'a':…, 'b':…})`.
Field names verbatim. No `token` when the fn wants `otp_token`.

## 3. Contract-parity test (test-writer Iron Rule #9)
Capture the actual invoke arguments and assert method + concrete keys against
the function's contract. `any(named:'body')` is forbidden here. See
`snippets/contract_parity_test.dart`. Better: generate a shared type/OpenAPI
so a mismatch fails codegen, not prod.

## 4. Real call (db-migration §5.5 / INTEGRATION_SMOKE)
`supabase functions serve`; authenticated real call to each new/changed fn;
assert 2xx + expected effect; paste evidence. 400 = field mismatch, 405 =
method mismatch — both are phase findings, not launch surprises.

## 5. Route
code-reviewer auto-HIGH (invoke keys/method ≠ fn destructure/guard) →
bug-hunter. test-writer contract test. db-migration / security gate the real
authenticated call.
