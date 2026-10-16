#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source_app="${1:-dist/Hycrypt.app}"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
ditto "$source_app" "$temporary/Hycrypt.app"
for variant in network debugger no-sandbox; do
    cp macOS/Hycrypt.entitlements "$temporary/entitlements.plist"
    case "$variant" in
        network) /usr/libexec/PlistBuddy -c "Add :com.apple.security.network.client bool true" "$temporary/entitlements.plist" ;;
        debugger) /usr/libexec/PlistBuddy -c "Add :com.apple.security.get-task-allow bool true" "$temporary/entitlements.plist" ;;
        no-sandbox) /usr/libexec/PlistBuddy -c "Delete :com.apple.security.app-sandbox" "$temporary/entitlements.plist" ;;
    esac
    /usr/bin/codesign --force --options runtime --entitlements "$temporary/entitlements.plist" --sign - "$temporary/Hycrypt.app" 2>/dev/null
    if bash scripts/verify-app-security.sh "$temporary/Hycrypt.app" > "$temporary/result" 2>&1; then
        echo "Unexpected acceptance: $variant" >&2
        exit 1
    fi
    /usr/bin/grep -q 'unexpected or missing entitlements' "$temporary/result"
done
echo 'Signing regression checks passed: network, debugger and missing sandbox rejected.'
