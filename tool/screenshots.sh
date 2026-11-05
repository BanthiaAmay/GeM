#!/usr/bin/env bash
# App Store screenshots on the iPhone and iPad simulators.
#   tool/screenshots.sh            -> build/screenshots/{iphone,ipad}/NN-screen.png
# Uses Apple's required sizes: iPhone 6.9" (iPhone 17 Pro Max, 1320x2868) and
# iPad 13" (iPad Pro 13-inch, 2064x2752). Needs Xcode and config/env.json.
set -euo pipefail
cd "$(dirname "$0")/.."

shoot() {  # <folder> <simulator name>
  local folder=$1 name=$2 udid
  udid=$(xcrun simctl list devices available | grep -F "    $name (" | head -1 | grep -oE '[0-9A-F-]{36}')
  [ -n "$udid" ] || { echo "No simulator named '$name' (Xcode → Settings → Components)." >&2; exit 1; }
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  open -a Simulator
  # Apple-style status bar: 9:41, full battery and signal.
  xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged \
    --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi
  SIM_UDID=$udid SCREENSHOT_DIR="build/screenshots/$folder" flutter drive \
    --target=test_driver/screenshots.dart --driver=test_driver/screenshots_test.dart \
    --dart-define-from-file=config/env.json -d "$udid"
  xcrun simctl status_bar "$udid" clear
}

shoot iphone "iPhone 17 Pro Max"
shoot ipad "iPad Pro 13-inch (M5)"
echo "Screenshots: build/screenshots/"
