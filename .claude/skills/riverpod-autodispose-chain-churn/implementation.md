# Implementation — stop the autoDispose churn

## 1. Detect
```bash
grep -rn "autoDispose\|@riverpod\|@Riverpod\|ref.watch" lib/ | \
  grep -iE "current_user|session|auth|progress|stream"
```
Map the chain: which providers watch which. A node is wrong if it is
session/stream-scoped but autoDispose, OR a keepAlive node `ref.watch`es an
autoDispose node.

## 2. Fix the whole chain
- Codegen: `@Riverpod(keepAlive: true)` on session/stream providers.
- Manual: drop `.autoDispose`, or call `ref.keepAlive()` once the value is
  real (e.g. after first successful fetch).
- Replace keepAlive→autoDispose `ref.watch` with `ref.read` (one-shot) or
  promote the dependency to keepAlive.
- For cross-screen streams: one provider owning a single subscription;
  consumers `ref.watch` the provider, not re-create the stream.

## 3. Regression test
Mock the datasource only to COUNT calls. Drive ≥20 rapid rebuilds/invalidate;
assert remote-call-count == 1 (not 20). See `snippets/storm_test.dart`. Then
prove it for real: at INTEGRATION_SMOKE the boot/e2e run + HTTP access log
must show no repeated identical request burst.

## 4. Route
code-reviewer auto-HIGH (keepAlive watches autoDispose / session provider is
autoDispose) → bug-hunter. Fix in IN_PROGRESS, lifecycle regression test by
test-writer (Iron Rule #9), proven at INTEGRATION_SMOKE (HTTP trace shows no
storm).
