#!/bin/bash
set -e

DEVICE_ID="086A9B73-B0D8-4EDC-A917-64556A1ACCD1"
BUNDLE_ID="com.jonyardley.Intrada"

echo "🏗️  Building app..."
xcodebuild -project Intrada.xcodeproj \
           -scheme Intrada \
           -configuration Debug \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           -sdk iphonesimulator \
           build -quiet

echo "📱 Booting simulator..."
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
sleep 2

echo "📲 Installing app..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name 'Intrada.app' -path '*/Build/Products/Debug-iphonesimulator/*' | head -1)
xcrun simctl install booted "$APP_PATH"

echo "🚀 Launching app..."
open -a Simulator
xcrun simctl launch booted "$BUNDLE_ID" > /dev/null

echo "✅ App launched successfully!"
sleep 3

if xcrun simctl spawn booted launchctl list | grep -i intrada >/dev/null 2>&1; then
    echo "📱 App is running"
else
    echo "⚠️  App may have crashed - run 'iOS Crash Logs' task for details"
fi