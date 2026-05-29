#!/usr/bin/env bash
# iOS release build + install helper for iOS 18.4+ physical devices.
# Why release-only: see ../SKILL.md (mprotect/JIT iOS 26 issue).
#
# Usage:
#   ./install-ios-release.sh                  # auto-detect first physical device
#   ./install-ios-release.sh <UDID>           # specific device
#   ./install-ios-release.sh <UDID> .env.staging
#
# Pre-req: project root with pubspec.yaml + .env file. Codesigning configured in Xcode.

set -euo pipefail

ENV_FILE="${2:-.env}"
APP_BUNDLE="build/ios/iphoneos/Runner.app"

# Sanity: project root
if [ ! -f pubspec.yaml ]; then
  echo "ERR: run from Flutter project root (pubspec.yaml not found)" >&2
  exit 1
fi
if [ ! -f "$ENV_FILE" ]; then
  echo "ERR: $ENV_FILE missing — copy from .env.example" >&2
  exit 1
fi

# Resolve UDID
if [ "${1:-}" != "" ]; then
  UDID="$1"
else
  UDID=$(xcrun devicectl list devices --json-output - 2>/dev/null \
    | python3 -c "import sys, json; d=json.load(sys.stdin); \
        devs=[x for x in d.get('result',{}).get('devices',[]) if x.get('connectionProperties',{}).get('pairingState')=='paired']; \
        print(devs[0]['hardwareProperties']['udid']) if devs else sys.exit(1)" \
    2>/dev/null || true)
  if [ -z "$UDID" ]; then
    echo "ERR: no paired iOS device found. Pass UDID explicitly:" >&2
    xcrun devicectl list devices >&2
    exit 1
  fi
  echo "→ Using auto-detected device: $UDID"
fi

# Build release with signing (Xcode-managed)
echo "→ flutter build ios --release --dart-define-from-file=$ENV_FILE"
flutter build ios --release --dart-define-from-file="$ENV_FILE"

# Absolute path (devicectl sandbox needs full path OR cwd-relative)
ABS_APP="$(pwd)/$APP_BUNDLE"
if [ ! -d "$ABS_APP" ]; then
  echo "ERR: $ABS_APP not found after build" >&2
  exit 1
fi

echo "→ Installing $ABS_APP to $UDID"
xcrun devicectl device install app --device "$UDID" "$ABS_APP"

echo ""
echo "✓ Installed. Open the app manually from the Home screen."
echo "  (Release mode: no debug attach, no DevTools, no hot reload.)"
echo "  For logs: idevicesyslog | grep -i runner   (brew install libimobiledevice)"
