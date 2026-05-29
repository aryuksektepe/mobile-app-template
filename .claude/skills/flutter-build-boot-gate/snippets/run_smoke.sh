#!/usr/bin/env bash
# Canonical INTEGRATION_SMOKE artifact producer. Installed by app-bootstrap at
# tool/run_smoke.sh and run by the `coder` agent (Bash + emulator) EVERY phase
# at INTEGRATION_SMOKE — locally in the auto-loop AND by CI (single source of
# truth; ci.yml calls this same script).
#
# It turns the runtime gate from self-reported ("BOOT_OK ✓" typed by the agent)
# into PROOF-OF-WORK: a captured log that the verify-smoke.py hook validates.
#
# Usage:  bash tool/run_smoke.sh <phase_id> [flavor]
#   e.g.  bash tool/run_smoke.sh 03 dev
#
# Produces:  .project/qa-runs/smoke-<phase_id>-<sha>-<ts>.log
# The log MUST contain (emitted by the running app + this script):
#   BOOT_OK flavor=<f> sha=<sha> ts=…      (app main() last line)
#   FIRST_SCREEN_OK route=… sha=<sha>      (app post-first-frame callback)
#   SMOKE_RESULT exit=0 sha=<sha>          (this script, only on full pass)
# verify-smoke.py blocks the phase from leaving INTEGRATION_SMOKE unless this
# artifact exists, the sha matches HEAD, it is fresher than lib/, and all three
# markers are present. (CLAUDE.md §3, decisions.md ADR-011.)
set -uo pipefail

PHASE="${1:?usage: run_smoke.sh <phase_id> [flavor]}"
FLAVOR="${2:-dev}"
TARGET="lib/main_${FLAVOR}.dart"
SHA="$(git rev-parse --short HEAD 2>/dev/null || echo UNKNOWN)"
TS="$(date +%s)"
QA_DIR=".project/qa-runs"
LOG="${QA_DIR}/smoke-${PHASE}-${SHA}-${TS}.log"

mkdir -p "${QA_DIR}"
: > "${LOG}"
log() { echo "$@" | tee -a "${LOG}"; }

log "==> SMOKE phase=${PHASE} flavor=${FLAVOR} sha=${SHA} ts=${TS}"

# 1. Real compile (catches native/Gradle/Kotlin/desugaring/manifest defects).
log "==> Build (real compile, GIT_SHA injected)…"
if ! flutter build apk --flavor "${FLAVOR}" --debug \
      --target "${TARGET}" --dart-define=GIT_SHA="${SHA}" 2>&1 | tee -a "${LOG}"; then
  log "SMOKE_RESULT exit=1 sha=${SHA}  # build failed"
  exit 1
fi

# 2. A device/emulator must be online (auto-loop machine or CI emulator runner).
if ! flutter devices 2>&1 | tee -a "${LOG}" | grep -qiE 'emulator|simulator|device'; then
  log "FAIL: no device/emulator online. Start one (local: flutter emulators --launch; CI: android-emulator-runner / xcrun simctl boot)."
  log "SMOKE_RESULT exit=1 sha=${SHA}  # no device"
  exit 1
fi

# 3. Boot + first-screen + the phase's NON-MOCKED e2e on a real device. The app
#    emits BOOT_OK + FIRST_SCREEN_OK during this run (integration_test surfaces
#    debugPrint). --dart-define carries the sha into the markers.
log "==> Integration smoke on device (boot + first screen + non-mocked e2e)…"
flutter test integration_test/ --dart-define=GIT_SHA="${SHA}" 2>&1 | tee -a "${LOG}"
RC=${PIPESTATUS[0]}

# 4. Assert the proof-of-work markers actually appeared (app truly booted).
fail=0
grep -qE "BOOT_OK[^\n]*sha=${SHA}"      "${LOG}" || { log "MISSING marker: BOOT_OK sha=${SHA}"; fail=1; }
grep -qE "FIRST_SCREEN_OK"              "${LOG}" || { log "MISSING marker: FIRST_SCREEN_OK"; fail=1; }
grep -qE "All tests passed"            "${LOG}" || { log "tests did not all pass"; fail=1; }

if [ "${RC}" -ne 0 ] || [ "${fail}" -ne 0 ]; then
  log "SMOKE_RESULT exit=1 sha=${SHA}  # rc=${RC} markers_ok=$((1-fail))"
  echo "SMOKE FAILED — see ${LOG}" >&2
  exit 1
fi

log "SMOKE_RESULT exit=0 sha=${SHA}"
echo "SMOKE PASS — artifact: ${LOG}"
echo "Reference this path in the phase archive's ## Integration Smoke section."
