#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

BUNDLE_ID="com.surkovroman.glowline"
APP="Glowline.app"

ARCH_FLAGS=(--arch arm64)
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

swift build -c release "${ARCH_FLAGS[@]}"
BIN_DIR="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"
cp "$BIN_DIR/Glowline" "$APP/Contents/MacOS/Glowline"

codesign --force -s - --identifier "$BUNDLE_ID" \
    -r "=designated => identifier \"$BUNDLE_ID\"" \
    "$APP"

echo "Built $APP (bundle id: $BUNDLE_ID, arch: $(lipo -archs "$APP/Contents/MacOS/Glowline"))"
echo "Run it with: ./$APP/Contents/MacOS/Glowline --help"
