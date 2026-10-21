# Argon2 reference implementation

Source: https://github.com/P-H-C/phc-winner-argon2
Tag: 20190702
Commit: 62358ba2123abd17fccf2a108a301d4b52c01a7c

Unmodified include/ and src/ directories. The Swift package compiles only the
portable reference implementation and its dependencies. See LICENSE.

Verified identical to the upstream commit on 2026-10-16; `scripts/verify-vendor.sh`
pins the files via `Vendor/SHA256SUMS`. Hycrypt does not patch this directory: the
`CArgon2Shim` target supplies allocation callbacks and executes Argon2 with
`context.threads = 1` while retaining the format's lanes, so upstream's
`ARGON2_THREAD_FAIL` join-failure paths are unreachable. A failed derivation still
wipes and frees the workspace. `Tests/Integration/test-argon2-cleanup.sh` verifies
that no worker thread is created, successful cleanup, and allocation-failure output
zeroing.
