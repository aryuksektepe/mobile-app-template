# Verification Checklist — autoDispose chain churn

- [ ] Session/identity providers (currentUser, auth, flags) are `keepAlive`
- [ ] Cross-screen stream providers are `keepAlive` with a single subscription
- [ ] No `keepAlive` provider `ref.watch`es an `autoDispose` provider (use `ref.read` or promote)
- [ ] Whole dependency chain audited, not a single node
- [ ] Per-screen ephemeral providers remain `autoDispose` (no memory leak from over-correction)
- [ ] Storm regression test: ≥20 rebuilds ⇒ exactly 1 remote call
- [ ] INTEGRATION_SMOKE HTTP access log shows no repeated identical request burst
- [ ] code-reviewer flagged original as auto-HIGH
