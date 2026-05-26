#!/usr/bin/env bash
# verify-release-shrinking.sh
# Builds the release App Bundle, installs on a connected device, launches,
# and checks logcat for known R8-stripping crash patterns. If app boots clean
# and reaches BOOT_OK marker, gate passes.
#
# Usage:
#   bash .claude/skills/ios-android-hardening/snippets/verify-release-shrinking.sh prod
#
# Exit code 0 on pass, non-zero on failure. CI-friendly.

set -euo pipefail

FLAVOR="${1:-prod}"
VERSION="$(grep -m1 '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)"
SYMBOLS_DIR="build/symbols/${FLAVOR}/${VERSION}"

echo "=== Building release App Bundle (flavor=$FLAVOR, version=$VERSION) ==="
mkdir -p "$SYMBOLS_DIR"
flutter build appbundle \
  --release \
  --flavor "$FLAVOR" \
  --obfuscate \
  --split-debug-info="$SYMBOLS_DIR"

echo ""
echo "=== Verifying R8 mapping file exists ==="
MAPPING="build/app/outputs/mapping/${FLAVOR}Release/mapping.txt"
if [ ! -f "$MAPPING" ]; then
  echo "ERROR: mapping.txt not found at $MAPPING — R8 may not have run"
  exit 2
fi
echo "OK: $MAPPING ($(wc -l < "$MAPPING") rules)"

echo ""
echo "=== Verifying symbols emitted ==="
if ! ls "$SYMBOLS_DIR"/*.symbols >/dev/null 2>&1; then
  echo "ERROR: no .symbols files in $SYMBOLS_DIR — --split-debug-info failed"
  exit 3
fi
ls -la "$SYMBOLS_DIR"

echo ""
echo "=== Installing on connected device ==="
# Use bundletool to convert AAB → device-specific APK set, then install
AAB="build/app/outputs/bundle/${FLAVOR}Release/app-${FLAVOR}-release.aab"
APKS="build/app/outputs/bundle/${FLAVOR}Release/app.apks"

if ! command -v bundletool >/dev/null; then
  echo "bundletool not found — install: brew install bundletool (or download from GitHub)"
  exit 4
fi

bundletool build-apks --bundle="$AAB" --output="$APKS" --connected-device --overwrite
bundletool install-apks --apks="$APKS"

echo ""
echo "=== Launching app + watching logcat for BOOT_OK / crash patterns ==="
PKG="$(grep -m1 'applicationId' android/app/build.gradle | sed 's/.*"\(.*\)".*/\1/')"
# flavor suffix typical: applicationIdSuffix ".$flavor" → adjust if you use one
adb shell am force-stop "$PKG"
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
adb logcat -c
adb logcat -d &
LOGCAT_PID=$!
sleep 15
kill $LOGCAT_PID 2>/dev/null || true

# Tripwires for the most common release-only failures
LOGCAT_OUT=$(adb logcat -d)
echo "$LOGCAT_OUT" | grep -E "NoSuchMethodError|ClassNotFoundException|VerifyError|UnsatisfiedLinkError" && {
  echo ""
  echo "FAIL: release-only crash pattern detected — likely missing keep rule"
  echo "Add the offending class to proguard-rules.pro and re-run"
  exit 5
}

echo "$LOGCAT_OUT" | grep -q "BOOT_OK flavor=$FLAVOR" || {
  echo ""
  echo "FAIL: did not see 'BOOT_OK flavor=$FLAVOR' marker in logcat within 15s"
  echo "Either the app crashed silently, never reached main()'s end,"
  echo "or your main() is missing the debugPrint('BOOT_OK ...') line."
  exit 6
}

echo ""
echo "PASS: release App Bundle boots clean. Ready to upload symbols + ship."
echo "  Symbols: $SYMBOLS_DIR/*.symbols"
echo "  Mapping: $MAPPING"
