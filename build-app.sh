#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

BUNDLE_ID="com.surkovroman.skydimoambient"
APP="SkydimoAmbient.app"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"
cp .build/release/SkydimoAmbient "$APP/Contents/MacOS/SkydimoAmbient"

codesign --force -s - --identifier "$BUNDLE_ID" \
    -r "=designated => identifier \"$BUNDLE_ID\"" \
    "$APP"

echo "Built $APP (bundle id: $BUNDLE_ID)"
echo "Run it with: ./$APP/Contents/MacOS/SkydimoAmbient --help"
