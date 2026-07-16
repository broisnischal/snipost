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

codesign --force --sign - "$APP"

echo "Built $APP"
echo "Run with: open $APP"
