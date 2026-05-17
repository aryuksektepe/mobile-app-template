#!/usr/bin/env bash
# Pre-push guard: fail if committed generated code drifts from a fresh
# build_runner. Prevents CI red-failing on stale codegen and keeps the
# generated-clean gate meaningful. Wire into .githooks/pre-push.
set -euo pipefail

echo "==> Regenerating code…"
dart run build_runner build --delete-conflicting-outputs >/dev/null

# Deterministic generated paths MUST match. (Non-deterministic artifacts are
# excluded — keep this list in sync with ci.yml's generated-clean step.)
if ! git diff --quiet -- \
  'lib/**/*.g.dart' 'lib/**/*.freezed.dart' 'lib/**/*.gr.dart' \
  'lib/l10n/**' ; then
  echo "FAIL: generated code is stale. Regenerate + commit before pushing:" >&2
  git --no-pager diff --stat -- 'lib/**/*.g.dart' 'lib/**/*.freezed.dart' >&2
  exit 1
fi

echo "PASS: generated code clean. (Tip: batch pushes — one CI run per batch.)"
