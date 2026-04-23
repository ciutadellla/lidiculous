#!/bin/bash
set -e

APP_NAME="Lidiculous"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"

echo "🧹  Cleaning build cache…"
swift package clean

echo "🔨  Building $APP_NAME…"
swift build -c release 2>&1

echo "📦  Assembling .app bundle…"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$CONTENTS/Resources"
cp ".build/release/$APP_NAME" "$MACOS/$APP_NAME"
cp "Resources/Info.plist"     "$CONTENTS/Info.plist"

echo "✍️   Code signing…"
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "✅  Done: $(pwd)/$APP_BUNDLE"
echo ""
echo "Install:  cp -r $APP_BUNDLE ~/Applications/"
echo "Launch:   open ~/Applications/$APP_BUNDLE"
echo ""
echo "⚠️  First launch: grant Accessibility in"
echo "   System Settings → Privacy & Security → Accessibility"
