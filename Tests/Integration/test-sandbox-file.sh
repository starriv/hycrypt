#!/bin/bash
# Runs HycryptCore's file and directory round trips inside a signed App Sandbox
# process. This covers the private staging root and descriptor-anchored publish
# path that unit tests (unsandboxed) cannot exercise.
set -euo pipefail
cd "$(dirname "$0")/../.."
product=HycryptSandboxFileProbe
probe_id=net.starriv.hycrypt.sandbox-file-probe
swift build --product "$product"
bin_dir="$(swift build --show-bin-path)"
temporary="$(mktemp -d)"
cleanup() {
    rm -rf "$temporary" "$HOME/Library/Containers/$probe_id" \
        "$HOME/Library/Application Scripts/$probe_id" 2>/dev/null || true
}
trap cleanup EXIT
app="$temporary/$product.app"
mkdir -p "$app/Contents/MacOS"
cp "$bin_dir/$product" "$app/Contents/MacOS/$product"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$probe_id</string>
<key>CFBundleExecutable</key><string>$product</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
/usr/bin/codesign --force --options runtime --entitlements macOS/Hycrypt.entitlements --sign - "$app"
"$app/Contents/MacOS/$product"
