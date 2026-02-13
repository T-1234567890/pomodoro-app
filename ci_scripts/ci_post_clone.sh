#!/bin/sh
set -e

echo "Restoring Firebase GoogleService-Info.plist..."

TARGET="${SRCROOT}/macos/Pomodoro/Pomodoro/GoogleService-Info.plist"

if [ -z "$FIREBASE_PLIST_BASE64" ]; then
  echo "No FIREBASE_PLIST_BASE64 found. Using dummy file."
  exit 0
fi

mkdir -p "$(dirname "$TARGET")"

echo "Decoding Firebase config..."

echo "$FIREBASE_PLIST_BASE64" | base64 -d > "$TARGET" 2>/dev/null || \
echo "$FIREBASE_PLIST_BASE64" | base64 -D > "$TARGET"

# sanity check
if [ ! -s "$TARGET" ]; then
  echo "❌ Firebase plist decode failed!"
  exit 1
fi

echo "✅ Firebase config restored to $TARGET"