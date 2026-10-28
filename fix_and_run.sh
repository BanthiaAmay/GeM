#!/bin/zsh
# GeM BizReady: sync the fixed code into ~/Developer/GeM-BizReady, verify, and run.
set -e
SRC="$HOME/Library/CloudStorage/OneDrive-Personal/Desktop/AMAY BANTHIA/GeM BizReady/GeM"
DST="$HOME/Developer/GeM-BizReady"
STAMP=$(date +%Y%m%d-%H%M%S)

echo "▶ 1/6 Backing up current Developer copy → ${DST}.backup-$STAMP"
rsync -a --exclude build --exclude .dart_tool --exclude ios/Pods --exclude macos/Pods "$DST/" "${DST}.backup-$STAMP/"

echo "▶ 2/6 Copying fixed code into Developer copy"
rsync -a --delete \
  --exclude .git --exclude build --exclude .dart_tool \
  --exclude ios/Pods --exclude ios/Podfile.lock --exclude ios/.symlinks \
  --exclude macos/Pods --exclude macos/Podfile.lock \
  --exclude 'ios/Flutter/Generated.xcconfig' --exclude 'ios/Flutter/flutter_export_environment.sh' \
  --exclude '**/ephemeral' --exclude .flutter-plugins --exclude .flutter-plugins-dependencies \
  --exclude pubspec.lock --exclude fix_and_run.sh \
  "$SRC/" "$DST/"

cd "$DST"
echo "▶ 3/6 Clean + fresh dependencies"
flutter clean >/dev/null
rm -rf ios/Pods ios/Podfile.lock macos/Pods macos/Podfile.lock pubspec.lock
flutter pub get

if grep -qE "super_clipboard|super_native_extensions|irondash" pubspec.lock; then
  echo "✖ super_clipboard is still being pulled in:"; flutter pub deps | grep -B3 super_; exit 1
fi
echo "✔ super_clipboard / Rust toolchain fully removed"

echo "▶ 4/6 Dart analysis (errors only)"
flutter analyze --no-fatal-infos --no-fatal-warnings

echo "▶ 5/6 CocoaPods"
(cd ios && pod install --repo-update)

echo "▶ 6/6 Launching on iOS simulator"
flutter run
