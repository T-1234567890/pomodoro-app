#!/bin/sh
set -e

echo "Restoring Firebase GoogleService-Info.plist…"

TARGET="${SRCROOT}/macos/Pomodoro/Pomodoro/GoogleService-Info.plist"

if [ -z "$FIREBASE_PLIST_BASE64" ]; then
  echo "No FIREBASE_PLIST_BASE64 found."
  exit 0
fi

mkdir -p "$(dirname "$TARGET")"

if base64 --help 2>&1 | grep -q -- '--decode'; then
  printf "%s" "$FIREBASE_PLIST_BASE64" | base64 --decode > "$TARGET"
else
  printf "%s" "$FIREBASE_PLIST_BASE64" | base64 -D > "$TARGET"
fi

echo "Firebase config restored to $TARGET"