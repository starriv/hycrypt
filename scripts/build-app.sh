#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${CONFIGURATION:-release}"
if [ "${RELEASE:-0}" = "1" ]; then
    case "${SIGNING_IDENTITY:-}" in
        "Developer ID Application: "*) ;;
        *) echo 'Release requires a Developer ID Application SIGNING_IDENTITY.' >&2; exit 1 ;;
    esac
    : "${NOTARY_PROFILE:?Release requires a saved NOTARY_PROFILE}"
    configuration=release
fi
swift build -c "$configuration"
bin_dir="$(swift build -c "$configuration" --show-bin-path)"
app="$PWD/dist/Hycrypt.app"
# Recreate the generated bundle so removed resources cannot survive a rebuild.
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/Hycrypt" "$app/Contents/MacOS/Hycrypt"
cp macOS/Info.plist "$app/Contents/Info.plist"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
swift scripts/BuildIcon.swift "$temporary/AppIcon.iconset"
iconutil -c icns "$temporary/AppIcon.iconset" -o "$app/Contents/Resources/AppIcon.icns"
for resource in "$bin_dir"/ZIPFoundation*.bundle; do
    if [ -d "$resource" ]; then
        ditto "$resource" "$app/Contents/Resources/$(basename "$resource")"
    fi
done
install -m 644 Vendor/argon2/LICENSE "$app/Contents/Resources/Argon2-LICENSE.txt"
install -m 644 Vendor/bip39/OneKey-LICENSE "$app/Contents/Resources/BIP39-OneKey-LICENSE.txt"
install -m 644 Vendor/bip39/Trezor-LICENSE "$app/Contents/Resources/BIP39-Trezor-LICENSE.txt"
install -m 644 .build/checkouts/ZIPFoundation/LICENSE "$app/Contents/Resources/ZIPFoundation-LICENSE.txt"
# Set SIGNING_IDENTITY to a local Apple Development or Developer ID identity when available.
signing_identity="${SIGNING_IDENTITY:--}"
timestamp=()
# Notarization requires a secure timestamp; ad-hoc signatures cannot carry one.
if [ "$signing_identity" != "-" ]; then timestamp=(--timestamp); fi
codesign --force --options runtime ${timestamp[@]+"${timestamp[@]}"} --entitlements macOS/Hycrypt.entitlements \
    --sign "$signing_identity" "$app"
bash scripts/verify-app-security.sh "$app"
# Opt-in: NOTARY_PROFILE names a `xcrun notarytool store-credentials` keychain profile.
# Credentials are never read from the environment or written by this script.
if [ -n "${NOTARY_PROFILE:-}" ]; then
    if [ "$signing_identity" = "-" ]; then
        echo 'Notarization requires SIGNING_IDENTITY set to a Developer ID Application identity.' >&2
        exit 1
    fi
    archive="$temporary/Hycrypt-notarize.zip"
    rm -f "$archive"
    ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
    xcrun notarytool submit "$archive" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$app"
    xcrun stapler validate "$app"
    spctl --assess --type execute --verbose=2 "$app"
    rm -f "$archive"
fi
if [ "${RELEASE:-0}" = "1" ]; then
    version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' macOS/Info.plist)
    archive="$PWD/dist/Hycrypt-$version-$(uname -m).zip"
    ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
    (cd dist && shasum -a 256 "$(basename "$archive")" > "$(basename "$archive").sha256")
    printf 'Release archive: %s\n' "$archive"
fi
printf 'Built: %s\n' "$app"
