#!/bin/bash
# Multi-flavor FlutterFire configuration script.
# Run from project root: ./flutterfire-config.sh <dev|stg|prod>
#
# Generates:
#   lib/firebase_options_<flavor>.dart
#   ios/flavors/<flavor>/GoogleService-Info.plist
#   android/app/src/<flavor>/google-services.json
#
# Prerequisites:
#   - npm i -g firebase-tools && firebase login
#   - dart pub global activate flutterfire_cli
#   - separate Firebase project per flavor (myapp-dev, myapp-stg, myapp-prod)
#   - Flutter flavors set up (Android productFlavors + Xcode schemes)

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <dev|stg|prod>"
  exit 1
fi

# CHANGE THESE to your bundle/package IDs and Firebase project IDs:
case $1 in
  dev)
    PROJECT="myapp-dev"
    IOS_BUNDLE="com.acme.myapp.dev"
    ANDROID_PKG="com.acme.myapp.dev"
    ;;
  stg)
    PROJECT="myapp-stg"
    IOS_BUNDLE="com.acme.myapp.stg"
    ANDROID_PKG="com.acme.myapp.stg"
    ;;
  prod)
    PROJECT="myapp-prod"
    IOS_BUNDLE="com.acme.myapp"
    ANDROID_PKG="com.acme.myapp"
    ;;
  *)
    echo "Unknown flavor: $1 (expected dev|stg|prod)"
    exit 1
    ;;
esac

flutterfire configure \
  --project="$PROJECT" \
  --out="lib/firebase_options_$1.dart" \
  --ios-bundle-id="$IOS_BUNDLE" \
  --ios-out="ios/flavors/$1/GoogleService-Info.plist" \
  --android-package-name="$ANDROID_PKG" \
  --android-out="android/app/src/$1/google-services.json" \
  --platforms=android,ios \
  --yes

echo ""
echo "✓ Generated firebase_options_$1.dart and per-flavor service files."
echo "  Run with: flutter run --flavor $1 -t lib/main_$1.dart"
