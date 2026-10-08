#!/bin/sh
# Builds the app and wraps it into build/bgpbar.app. Pass --install to copy it to ~/Applications and (re)start it.
set -eu
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/bgpbar"

APP=build/bgpbar.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/bgpbar"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>bgpbar</string>
    <key>CFBundleDisplayName</key><string>bgpbar</string>
    <key>CFBundleIdentifier</key><string>dev.stasiandr.bgpbar</string>
    <key>CFBundleExecutable</key><string>bgpbar</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
    pkill -x bgpbar || true
    rm -rf ~/Applications/bgpbar.app
    cp -R "$APP" ~/Applications/
    open ~/Applications/bgpbar.app
    echo "Installed ~/Applications/bgpbar.app"
fi
