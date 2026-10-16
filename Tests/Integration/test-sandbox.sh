#!/bin/bash
# Compile a disposable probe with the production sandbox grants. No network server
# is required: a denied connect must fail with EPERM/EACCES, not ECONNREFUSED.
set -euo pipefail
cd "$(dirname "$0")/../.."
temporary="$(mktemp -d)"
probe_id=net.starriv.hycrypt.sandbox-probe
# The probe is disposable; do not leave its sandbox container behind.
trap 'rm -rf "$temporary" "$HOME/Library/Containers/$probe_id" "$HOME/Library/Application Scripts/$probe_id"' EXIT
printf 'public test fixture\n' > "$temporary/denied.txt"
cat > "$temporary/probe.swift" <<'SWIFT'
import Darwin
import Foundation
let path = CommandLine.arguments[1]
let descriptor = open(path, O_RDONLY)
guard descriptor == -1, errno == EPERM || errno == EACCES else {
    if descriptor >= 0 { close(descriptor) }
    fatalError("Sandbox did not deny ungranted file access")
}
let socketFD = socket(AF_INET, SOCK_STREAM, 0)
if socketFD >= 0 {
    defer { close(socketFD) }
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = UInt16(9).bigEndian
    address.sin_addr.s_addr = inet_addr("127.0.0.1")
    let status = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard status == -1, errno == EPERM || errno == EACCES else {
        fatalError("Sandbox did not deny network access")
    }
} else {
    guard errno == EPERM || errno == EACCES else { fatalError("Unexpected socket error") }
}
print("Sandbox probe passed: ungranted file and network access denied.")
SWIFT
app="$temporary/HycryptSandboxProbe.app"
mkdir -p "$app/Contents/MacOS"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$probe_id</string>
<key>CFBundleExecutable</key><string>probe</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
/usr/bin/swiftc "$temporary/probe.swift" -o "$app/Contents/MacOS/probe"
/usr/bin/codesign --force --options runtime --entitlements macOS/Hycrypt.entitlements --sign - "$app"
"$app/Contents/MacOS/probe" "$temporary/denied.txt"
