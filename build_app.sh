#!/usr/bin/env zsh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "🔨 Building release binary..."
swift build -c release

APP_NAME="MonMove"
BUILD_BIN=".build/release/monmove"
APP_BUNDLE="${APP_NAME}.app"

echo "📦 Packaging ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_BIN}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

cat << 'EOF' > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MonMove</string>
    <key>CFBundleIdentifier</key>
    <string>com.user.MonMove</string>
    <key>CFBundleName</key>
    <string>MonMove</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ App bundle created successfully: ${DIR}/${APP_BUNDLE}"
echo "💡 You can launch the Menu Bar App with: open ${APP_BUNDLE}"
echo "💡 You can also copy 'monmove' executable to /usr/local/bin: sudo cp ${BUILD_BIN} /usr/local/bin/monmove"
