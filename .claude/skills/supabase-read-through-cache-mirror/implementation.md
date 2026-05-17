# Implementation — read-through cache mirror

## 1. Detect
For every repository method that reads a Drift/local mirror:
```bash
grep -rn "mirror\|localDb\|drift\|\.get(\|select()" lib/src/**/data/ -l
```
Flag any read that returns the local result without a remote fallback on
empty/miss, and without backfilling the mirror.

## 2. Implement read-through
- Fast path: return non-empty local.
- Miss: query Supabase, upsert into the mirror, return remote.
- Keep fresh: realtime subscription or pull-to-refresh writes the mirror;
  reads stay local.
- Map errors to `Failure` (offline + empty mirror → a real `Failure`, not a
  silent `[]`).

## 3. Prove it (non-mocked, mandatory)
`supabase start`, leave the mirror empty, call the method, assert it returns
server rows AND the mirror was backfilled (second call hits local). A mocked
fake repo MUST NOT stand in for this — that is exactly what hid ADR-027. Mark
`// CONTRACT-UNTESTED` and defer to INTEGRATION_SMOKE if a fake is unavoidable
in unit scope.

## 4. Route
test-writer Iron Rule #8 (non-mocked backend test) + #9 (repo read-through).
Proven at INTEGRATION_SMOKE: fresh-install run shows real content, not an
empty state.
