#!/bin/bash
# Quick build script for iOS simulator without code signing issues
set -e

echo "🧹 Cleaning..."
cd /Users/jannisdietrich/Documents/shoply
flutter clean > /dev/null 2>&1

echo "📦 Getting dependencies..."
flutter pub get > /dev/null 2>&1

echo "🔨 Installing CocoaPods..."
cd ios
rm -rf Pods Podfile.lock
pod install > /dev/null 2>&1

echo "📱 Building for simulator (no code signing)..."
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build 2>&1 | grep -E "(BUILD|error:|warning:)" | tail -20

cd ..

if [ -d "/Users/jannisdietrich/Library/Developer/Xcode/DerivedData/Runner-bewnhldyasdqvybiljtovlmupmuj/Build/Products/Debug-iphonesimulator/Runner.app" ]; then
    echo ""
    echo "✅ BUILD SUCCEEDED!"
    echo ""
    echo "📍 App location:"
    echo "/Users/jannisdietrich/Library/Developer/Xcode/DerivedData/Runner-bewnhldyasdqvybiljtovlmupmuj/Build/Products/Debug-iphonesimulator/Runner.app"
    echo ""
    echo "🚀 To run on simulator, use Xcode or:"
    echo "xcrun simctl install <simulator-id> <path-to-Runner.app>"
    echo "xcrun simctl launch <simulator-id> com.dominik.shoply"
else
    echo ""
    echo "❌ BUILD FAILED - Runner.app not found"
    exit 1
fi
