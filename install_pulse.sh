#!/bin/bash
set -e

APP_NAME="Pulse"
OUTPUT_DIR="build"
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"
ICON_SOURCE="/Users/romeet/.gemini/antigravity/brain/7b91f42b-0775-4370-989c-04e46d7e8b0b/app_icon_1765833649065.png"

echo "Building Pulse..."
swift build -c release

echo "Creating App Bundle Structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "Copying Binary..."
cp ".build/release/Pulse" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "Creating Info.plist..."
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.user.Pulse</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/> 
</dict>
</plist>
EOF

# Create Icon
echo "Creating App Icon..."
mkdir -p "$APP_NAME.iconset"
ICON_SOURCE="/Users/romeet/.gemini/antigravity/brain/7b91f42b-0775-4370-989c-04e46d7e8b0b/pulse_icon_gemini_style_1765836990523.png"

# Resize images
sips -z 16 16     "$ICON_SOURCE" --out "$APP_NAME.iconset/icon_16x16.png" --setProperty format png
sips -z 32 32     "$ICON_SOURCE" --out "$APP_NAME.iconset/icon_16x16@2x.png" --setProperty format png
sips -z 32 32     "$ICON_SOURCE" --out "$APP_NAME.iconset/icon_32x32.png" --setProperty format png
sips -z 64 64     "$ICON_SOURCE" --out "$APP_NAME.iconset/icon_32x32@2x.png" --setProperty format png
sips -z 128 128   "$ICON_SOURCE" --out "$APP_NAME.iconset/icon_128x128.png" --setProperty format png
sips -z 256 256   "$ICON_SOURCE" --out "$APP_NAME.iconset/icon_128x128@2x.png" --setProperty format png
sips -z 256 256   "$ICON_SOURCE" --out "$APP_NAME.iconset/icon_256x256.png" --setProperty format png
sips -z 512 512   "$ICON_SOURCE" --out "$APP_NAME.iconset/icon_256x256@2x.png" --setProperty format png
sips -z 512 512   "$ICON_SOURCE" --out "$APP_NAME.iconset/icon_512x512.png" --setProperty format png
sips -z 1024 1024 "$ICON_SOURCE" --out "$APP_NAME.iconset/icon_512x512@2x.png" --setProperty format png

iconutil -c icns "$APP_NAME.iconset" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
rm -rf "$APP_NAME.iconset"

echo "Pulse.app created at $APP_BUNDLE"

# Installation Step
INSTALL_DIR="/Applications"

if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    echo "Existing Pulse.app found. Closing it..."
    pkill "$APP_NAME" || true
    echo "Removing old version..."
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

echo "Installing Pulse to $INSTALL_DIR..."
cp -r "$APP_BUNDLE" "$INSTALL_DIR/"

echo "Installation Complete!"
echo "Opening Pulse..."
open "$INSTALL_DIR/$APP_NAME.app"
