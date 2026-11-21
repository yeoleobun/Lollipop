#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Lollipop"
VERSION="1.0.0"
APP_BUNDLE="$ROOT_DIR/build/${APP_NAME}.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Building ${APP_NAME} (release)..."
cd "$ROOT_DIR"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"
if [[ ! -f "$BIN_PATH" ]]; then
  echo "Error: Built binary not found at $BIN_PATH" >&2
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
if [[ -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi
if [[ -d "$ROOT_DIR/Sources/Lollipop/Resources/Bridge" ]]; then
  cp -R "$ROOT_DIR/Sources/Lollipop/Resources/Bridge" "$RESOURCES_DIR/Bridge"
fi

cat > "$CONTENTS_DIR/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.lollipop.mac</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.music</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc sign so macOS Gatekeeper / MediaPlayer Now Playing works smoothly locally
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

echo "Packaged: $APP_BUNDLE"

if [[ "${1:-}" == "--dmg" ]]; then
  DMG_PATH="$ROOT_DIR/build/${APP_NAME}-${VERSION}-macOS-arm64.dmg"
  STAGING_DIR="$ROOT_DIR/build/dmg_staging"
  rm -rf "$STAGING_DIR" "$DMG_PATH"
  mkdir -p "$STAGING_DIR"
  cp -R "$APP_BUNDLE" "$STAGING_DIR/"
  ln -s /Applications "$STAGING_DIR/Applications"
  hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH" >/dev/null
  rm -rf "$STAGING_DIR"
  echo "DMG created: $DMG_PATH"
fi

echo "Run with: open \"$APP_BUNDLE\""
