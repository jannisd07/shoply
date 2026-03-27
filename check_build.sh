#!/bin/bash

echo "Waiting for IPA build to complete..."
echo "This usually takes 3-5 minutes..."

# Wait for the IPA file to appear
while true; do
    IPA_FILE=$(find /Users/jannisdietrich/Documents/shoply/build -name "*.ipa" -type f 2>/dev/null | head -1)
    
    if [ -n "$IPA_FILE" ]; then
        echo "✅ Build complete!"
        echo "IPA file found at: $IPA_FILE"
        ls -lh "$IPA_FILE"
        exit 0
    fi
    
    # Check if build is still running
    if ! ps aux | grep "flutter build" | grep -v grep > /dev/null; then
        echo "⚠️  Build process not running"
        echo "Checking for archive..."
        
        ARCHIVE=$(find /Users/jannisdietrich/Documents/shoply/build/ios/archive -name "*.xcarchive" -type d 2>/dev/null | head -1)
        if [ -n "$ARCHIVE" ]; then
            echo "Archive found at: $ARCHIVE"
            echo "Attempting to create IPA from archive..."
        else
            echo "❌ No archive found. Build may have failed."
            exit 1
        fi
    fi
    
    echo -n "."
    sleep 5
done
