#!/bin/bash

# Fix Codesign Attributes Script
# Strips extended attributes (iCloud Drive, Finder info, resource forks)
# from build products. Required because project lives in iCloud Drive (~/Documents).

if [ -d "$BUILT_PRODUCTS_DIR" ]; then
  xattr -cr "$BUILT_PRODUCTS_DIR" 2>/dev/null
fi

if [ -d "$CODESIGNING_FOLDER_PATH" ]; then
  xattr -cr "$CODESIGNING_FOLDER_PATH" 2>/dev/null
fi

exit 0
