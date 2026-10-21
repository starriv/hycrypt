.PHONY: build test app run format lint check security-check vendor-check release sanitize sanitize-smoke
format:
	swift format format --in-place --recursive Sources Tests Package.swift scripts/BuildIcon.swift

lint:
	swift format lint --strict --recursive Sources Tests Package.swift scripts/BuildIcon.swift

check: vendor-check lint test

vendor-check:
	./scripts/verify-vendor.sh

build:
	swift build

test:
	swift test --enable-code-coverage

app:
	./scripts/build-app.sh

run: app
	open dist/Hycrypt.app

security-check: app
	./Tests/Integration/test-app-security.sh
	./Tests/Integration/test-sandbox.sh
	./Tests/Integration/test-sandbox-file.sh
	./Tests/Integration/test-argon2-cleanup.sh

# Signed and notarized distribution; publishing is a separate step.
release: check
	RELEASE=1 ./scripts/build-app.sh

# Optional: ASan run for the Swift test suite. Not part of check because Argon2's
# 256 MiB workspace makes sanitizer runs slow.
sanitize:
	swift test --disable-sandbox --sanitize=address

sanitize-smoke:
	swift test --sanitize=address --filter HycryptCoreTests.FuzzSmokeTests
