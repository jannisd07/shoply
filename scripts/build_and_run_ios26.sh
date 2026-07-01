#!/bin/bash
set -e

echo "🧹 Cleaning build artifacts..."
cd /Users/jannisdietrich/Documents/shoply
rm -rf build/ios
flutter clean > /dev/null 2>&1

echo "📦 Getting dependencies..."
flutter pub get > /dev/null 2>&1

echo "🔨 Building Flutter framework (ignoring codesign errors)..."
# This will fail at codesign, but we'll work around it
flutter build ios --simulator --debug 2>&1 | grep -v "resource fork" || true

echo "🛠️ Manually fixing codesigning issues..."
# Remove extended attributes from all frameworks
find /Users/jannisdietrich/flutter/bin/cache/artifacts/engine -name "*.framework" -type d -exec xattr -cr {} \; 2>/dev/null || true
find build/ios -name "*.framework" -type d -exec xattr -cr {} \; 2>/dev/null || true

echo "🔧 Stripping codesigning from Flutter frameworks..."
# Remove signatures entirely for simulator
find build/ios/Debug-iphonesimulator -name "Flutter.framework" -type d -exec rm -f {}/Flutter.framework/_CodeSignature/CodeResources \; 2>/dev/null || true
find build/ios/Debug-iphonesimulator -name "App.framework" -type d -exec rm -f {}/App.framework/_CodeSignature/CodeResources \; 2>/dev/null || true

echo "📱 Building with Xcode (without codesigning)..."
cd ios
xcodebuild clean build \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -sdk iphonesimulator \
  -configuration Debug \
  -derivedDataPath ../build/ios \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  EXPANDED_CODE_SIGN_IDENTITY="" \
  2>&1 | grep -E "(BUILD|error:)" || true

cd ..

echo "📦 Checking if Runner.app was built..."
if [ -d "build/ios/Build/Products/Debug-iphonesimulator/Runner.app" ]; then
    echo "✅ Runner.app found!"
    
    # Remove any codesigning from the app
    xattr -cr build/ios/Build/Products/Debug-iphonesimulator/Runner.app 2>/dev/null || true
    
    echo "📲 Installing on simulator..."
    xcrun simctl install FE387AD5-63D6-4ECE-89BC-9CE77FF36C30 \
        build/ios/Build/Products/Debug-iphonesimulator/Runner.app
    
    echo "🚀 Launching app..."
    xcrun simctl launch --console FE387AD5-63D6-4ECE-89BC-9CE77FF36C30 com.dominik.shoply
else
    echo "❌ Runner.app not found. Build may have failed."
    exit 1
fi
