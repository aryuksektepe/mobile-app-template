#!/usr/bin/env bash
# Authenticated Edge-function smoke against the LOCAL stack. Run for EVERY
# new/changed function before leaving INTEGRATION_SMOKE (db-migration §5.5).
# A 401 here = the ADR-031 alg/secret trap, caught in-phase not at launch.
set -euo pipefail

FN="${1:?usage: edge_auth_smoke.sh <function-name>}"
: "${SUPABASE_URL:?run: export SUPABASE_URL=... (from \`supabase status\`)}"
: "${SUPABASE_ANON_KEY:?export SUPABASE_ANON_KEY=...}"
EMAIL="${SMOKE_EMAIL:-integration+edge@example.com}"
PW="${SMOKE_PW:-integration-pw-123}"

echo "==> Sign in against local GoTrue"
TOKEN=$(curl -fsS "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\"}" | jq -r .access_token)

echo "==> Token alg: $(echo "$TOKEN" | cut -d. -f1 | base64 -d 2>/dev/null | jq -r .alg)"

echo "==> Call $FN with the real token"
CODE=$(curl -s -o /tmp/edge_body -w '%{http_code}' \
  -X POST "$SUPABASE_URL/functions/v1/$FN" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{}')

echo "HTTP $CODE"; cat /tmp/edge_body; echo
if [ "$CODE" -ge 200 ] && [ "$CODE" -lt 300 ]; then
  echo "PASS: $FN authenticated 2xx"
else
  echo "FAIL: $FN returned $CODE — likely verify_jwt ES256/HS256 mismatch (ADR-031)" >&2
  exit 1
fi
