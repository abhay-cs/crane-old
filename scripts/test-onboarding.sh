#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Build/Products/Debug/crane.app"

echo "==> Building crane (Debug)..."
xcodebuild \
  -project "$ROOT/crane.xcodeproj" \
  -scheme crane \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$ROOT/build" \
  build >/dev/null

echo "==> Running onboarding tour verification..."
pkill -9 -x crane 2>/dev/null || true
sleep 1

set +e
CRANE_VERIFY_ONBOARDING=1 "$APP/Contents/MacOS/crane"
VERIFY_EXIT=$?
set -e

# Sandboxed app support directory lives inside the container.
RESULTS="$HOME/Library/Containers/com.abhaycs.crane/Data/Library/Application Support/com.abhaycs.crane/onboarding-test.json"
if [[ -f "$RESULTS" ]]; then
  echo "Results: $RESULTS"
  cat "$RESULTS"
  echo
fi

if [[ "$VERIFY_EXIT" -ne 0 ]]; then
  echo "FAIL: onboarding verification exited with code $VERIFY_EXIT"
  exit "$VERIFY_EXIT"
fi

echo "PASS: onboarding verification succeeded (exit 0)"
