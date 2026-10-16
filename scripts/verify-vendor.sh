#!/bin/bash
# Vendored sources were compared with their upstream commits (see Vendor/*/UPSTREAM.md)
# when Vendor/SHA256SUMS was recorded. Any later change must update both deliberately.
set -euo pipefail
cd "$(dirname "$0")/../Vendor"
expected="$(LC_ALL=C sort SHA256SUMS)"
actual="$(find argon2 bip39 -type f ! -name '.DS_Store' | LC_ALL=C sort | xargs shasum -a 256 | LC_ALL=C sort)"
if [ "$expected" != "$actual" ]; then
    diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") >&2 || true
    echo 'Vendor check failed: vendored files differ from Vendor/SHA256SUMS.' >&2
    exit 1
fi
echo 'Vendor check passed: vendored sources match recorded checksums.'
