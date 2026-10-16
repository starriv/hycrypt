#!/bin/bash
set -euo pipefail
target="${1:?Usage: verify-app-security.sh PATH}"
/usr/bin/codesign --verify --strict "$target"
details="$(/usr/bin/codesign -d --verbose=4 "$target" 2>&1)"
if ! /usr/bin/grep -Eq 'flags=.*\(.*runtime.*\)' <<< "$details"; then
    echo 'Security check failed: Hardened Runtime is required.' >&2
    exit 1
fi
# Exact allowlist: sandbox file grants only. Network, debugging, JIT and runtime
# exceptions must never be introduced implicitly by a signing configuration.
entitlements="$(/usr/bin/codesign -d --entitlements - --xml "$target" 2>/dev/null)"
test -n "$entitlements"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
printf '%s' "$entitlements" > "$temporary/actual.plist"
/usr/bin/plutil -convert xml1 "$temporary/actual.plist"
# Keep the allowlist independent of the input entitlement file.
/usr/bin/swift - "$temporary/actual.plist" <<'SWIFT'
import Foundation
let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let actual = try PropertyListSerialization.propertyList(from: data, format: nil) as? NSDictionary
let expected: NSDictionary = [
    "com.apple.security.app-sandbox": true,
    "com.apple.security.files.user-selected.read-write": true,
    "com.apple.security.files.bookmarks.app-scope": true,
]
guard let actual, actual == expected else {
    fputs("Security check failed: unexpected or missing entitlements.\n", stderr)
    exit(1)
}
SWIFT
echo 'Security check passed: valid signature, Hardened Runtime, sandbox, restricted file access, no network grants.'
