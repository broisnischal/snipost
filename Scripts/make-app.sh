#!/bin/bash
# Builds Snipost in release mode and assembles dist/Snipost.app (ad-hoc signed).
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release

APP="dist/Snipost.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/Snipost "$APP/Contents/MacOS/Snipost"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Prefer a real signing identity: it stays stable across rebuilds, so macOS
# keeps the Screen Recording permission. Ad-hoc (-) changes every build and
# resets TCC each time.
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -o '"Apple Development: [^"]*"' | head -1 | tr -d '"')
if [ -n "$IDENTITY" ]; then
    echo "Signing with: $IDENTITY"
    codesign --force --sign "$IDENTITY" "$APP"
else
    echo "No Apple Development identity found; ad-hoc signing"
    codesign --force --sign - "$APP"
fi

echo "Built $APP"
echo "Run with: open $APP"
