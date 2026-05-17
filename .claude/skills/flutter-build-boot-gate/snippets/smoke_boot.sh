#!/usr/bin/env bash
# Persistent boot-smoke harness. Installed by app-bootstrap at tool/smoke_boot.sh
# and reused by EVERY phase's INTEGRATION_SMOKE gate.
#
# Builds the given flavor, starts a headless emulator/simulator, installs the
# app, and waits for the BOOT_OK marker. The marker is emitted by the app:
# add `debugPrint('BOOT_OK flavor=<flavor>');` as the last line of each
# main_<flavor>() (or the shared bootstrap()).
#
# Usage:  tool/smoke_boot.sh dev
# Exit 0 = booted (BOOT_OK seen ≤ TIMEOUT). Exit 1 = failed (+ last 50 logs).
set -euo pipefail

FLAVOR="${1:-dev}"
TARGET="lib/main_${FLAVOR}.dart"
TIMEOUT="${BOOT_TIMEOUT:-60}"
MARKER="BOOT_OK flavor=${FLAVOR}"

echo "==> Building ${FLAVOR} (real compile)…"
flutter build apk --flavor "${FLAVOR}" --debug --target "${TARGET}"

echo "==> Ensuring a device/emulator is online…"
if ! flutter devices | grep -qiE 'emulator|simulator|device'; then
  echo "FAIL: no device/emulator online. Start one (CI: android-emulator-runner / xcrun simctl boot)." >&2
  exit 1
fi

echo "==> Launching ${FLAVOR}, waiting ≤${TIMEOUT}s for: ${MARKER}"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

# Run the app; tee logs so we can grep for the marker and dump tail on failure.
( flutter run --flavor "${FLAVOR}" --target "${TARGET}" -d emulator \
    --no-hot --pid-file /tmp/smoke.pid >"$LOG" 2>&1 & )

elapsed=0
while [ "$elapsed" -lt "$TIMEOUT" ]; do
  if grep -qF "$MARKER" "$LOG"; then
    echo "PASS: '${MARKER}' seen after ${elapsed}s."
    [ -f /tmp/smoke.pid ] && kill "$(cat /tmp/smoke.pid)" 2>/dev/null || true
    exit 0
  fi
  sleep 2
  elapsed=$((elapsed + 2))
done

echo "FAIL: '${MARKER}' not seen within ${TIMEOUT}s. Last 50 log lines:" >&2
tail -n 50 "$LOG" >&2
[ -f /tmp/smoke.pid ] && kill "$(cat /tmp/smoke.pid)" 2>/dev/null || true
exit 1
