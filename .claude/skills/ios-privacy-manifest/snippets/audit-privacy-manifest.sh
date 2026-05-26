#!/usr/bin/env bash
# audit-privacy-manifest.sh
# Greps the codebase + Pods for Required Reason API symbols.
# Run from project root. Outputs every hit so you can verify the manifest matches.
#
# Usage:
#   bash .claude/skills/ios-privacy-manifest/snippets/audit-privacy-manifest.sh
#
# Exit code 0 always; this is an informational audit, not a gate. Pipe into
# CI as a tripwire for new SDK additions.

set -uo pipefail

ROOT="$(pwd)"
echo "=== Privacy Manifest Required Reason API audit — $ROOT ==="
echo ""

scan() {
  local label="$1"; shift
  local reason="$1"; shift
  local pattern="$1"; shift
  local hits
  hits=$(grep -rEn "$pattern" \
    --include='*.swift' \
    --include='*.m' \
    --include='*.mm' \
    --include='*.h' \
    --include='*.dart' \
    ios/ lib/ 2>/dev/null | wc -l | tr -d ' ')
  # Pods scan separately (massive; only flag presence)
  local pod_hits
  pod_hits=$(grep -rEln "$pattern" \
    --include='*.swift' \
    --include='*.m' \
    --include='*.mm' \
    --include='*.h' \
    ios/Pods/ 2>/dev/null | wc -l | tr -d ' ')
  printf "[%s] %-20s app: %3s hits  pods: %3s files\n" "$reason" "$label" "$hits" "$pod_hits"
}

scan "UserDefaults"   "CA92.1 / 1C8F.1"  "NSUserDefaults|UserDefaults\.standard|shared_preferences"
scan "FileTimestamp"  "3B52.1 / C617.1"  "fileModificationDate|creationDate|getattr|stat\(|attributesOfItemAtPath|NSFileModificationDate"
scan "DiskSpace"      "7D9E.1 / B728.1"  "volumeAvailableCapacityForImportantUsage|systemFreeSize|NSFileSystemFreeSize"
scan "SystemBootTime" "35F9.1"           "systemUptime|mach_absolute_time|kern.boottime"
scan "ActiveKeyboards" "54BD.1"          "activeInputModes|UITextInputMode"

echo ""
echo "=== Third-party Pods that ship a manifest ==="
find ios/Pods -name 'PrivacyInfo.xcprivacy' 2>/dev/null | sed 's|^ios/Pods/||' | sort -u

echo ""
echo "=== Third-party Pods MISSING a manifest (audit each — file vendor issue if needed) ==="
for pod in ios/Pods/*/; do
  name=$(basename "$pod")
  case "$name" in
    Headers|Local\ Podspecs|Manifest.lock|Pods.xcodeproj|Target\ Support\ Files) continue ;;
  esac
  if ! find "$pod" -name 'PrivacyInfo.xcprivacy' -print -quit | grep -q .; then
    echo "  $name"
  fi
done

echo ""
echo "Done. Reconcile each hit with a reason code in PrivacyInfo.xcprivacy."
