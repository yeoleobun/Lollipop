#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Lollipop"
VERSION="${VERSION:-1.0.2}"
SIGN_IDENTITY="${SIGN_IDENTITY:-yeoleobun}"
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

# Sign with configured certificate when available (falls back to ad-hoc locally)
if [[ "$SIGN_IDENTITY" != "-" ]] && security find-identity -v -p codesigning 2>/dev/null | grep -Fq "\"$SIGN_IDENTITY\""; then
  echo "Signing ${APP_NAME}.app with identity: ${SIGN_IDENTITY}"
  codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
else
  echo "Identity '${SIGN_IDENTITY}' not found; ad-hoc signing ${APP_NAME}.app"
  codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true
fi

echo "Packaged: $APP_BUNDLE"

if [[ "${1:-}" == "--dmg" || "${1:-}" == "--release" || "${PACKAGE_DMG:-0}" == "1" ]]; then
  ZIP_PATH="$ROOT_DIR/build/${APP_NAME}-${VERSION}-macOS-arm64.zip"
  DMG_PATH="$ROOT_DIR/build/${APP_NAME}-${VERSION}-macOS-arm64.dmg"
  STAGING_DIR="$ROOT_DIR/build/dmg_staging"

  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
  echo "ZIP created: $ZIP_PATH"

  rm -rf "$STAGING_DIR" "$DMG_PATH"
  mkdir -p "$STAGING_DIR"
  cp -R "$APP_BUNDLE" "$STAGING_DIR/"
  ln -s /Applications "$STAGING_DIR/Applications"
  hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH" >/dev/null
  rm -rf "$STAGING_DIR"
  echo "DMG created: $DMG_PATH"

  (cd "$ROOT_DIR/build" && shasum -a 256 "$(basename "$ZIP_PATH")" "$(basename "$DMG_PATH")" > SHA256SUMS.txt)
  echo "Checksums: $ROOT_DIR/build/SHA256SUMS.txt"
fi

echo "Run with: open \"$APP_BUNDLE\""
