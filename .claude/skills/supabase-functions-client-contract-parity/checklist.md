# Verification Checklist — client↔Edge contract parity

- [ ] For each `functions.invoke`: HTTP method matches the fn's `req.method` guard
- [ ] Body field names match the fn's `await req.json()` destructure EXACTLY
- [ ] Contract-parity test asserts concrete method + keys (NO `any(named:'body')`)
- [ ] Function rejects wrong method (405) and missing/extra required field (400) loudly
- [ ] Real authenticated call to each new/changed fn returns 2xx (db-migration §5.5), evidence pasted
- [ ] Shared type / OpenAPI keeps client↔fn in sync (drift fails build, not prod) — or documented why not
- [ ] code-reviewer flagged any invoke/fn mismatch as auto-HIGH
- [ ] INTEGRATION_SMOKE: the feature (e.g. account deletion, region banner) actually works end-to-end
