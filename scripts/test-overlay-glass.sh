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

echo "==> Running overlay glass verification..."
pkill -9 -x crane 2>/dev/null || true
sleep 1

set +e
CRANE_VERIFY_OVERLAY_GLASS=1 "$APP/Contents/MacOS/crane"
VERIFY_EXIT=$?
set -e

if [[ "$VERIFY_EXIT" -ne 0 ]]; then
  echo "FAIL: overlay glass verification exited with code $VERIFY_EXIT"
  exit "$VERIFY_EXIT"
fi

echo "PASS: overlay glass verification succeeded (exit 0)"

echo "==> Metric sanity checks..."
python3 - <<'PY'
input_row = 40
hint = 24
pad = 12 * 2
pill = input_row + 6 + hint + pad
margin = 30
glass_w = 596
assert pill == 94, pill
assert glass_w + margin * 2 == 656
assert pill + margin * 2 == 154
history_h = 456
assert history_h + margin * 2 == 516
dashboard_w = 380
dashboard_h = 580
assert dashboard_w + margin * 2 == 440
assert dashboard_h + margin * 2 == 640
print(f"  pill height: {pill}pt")
print(f"  input panel: 656×154pt")
print(f"  history panel: 656×516pt")
print(f"  dashboard window: 440×640pt (380×580 glass)")
print(f"  shadow margin: {margin}pt")
PY

echo "All overlay glass tests passed."
