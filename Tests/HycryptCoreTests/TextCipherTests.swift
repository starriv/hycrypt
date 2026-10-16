import Foundation
import XCTest

@testable import HycryptCore

final class TextCipherTests: XCTestCase {
    func testUnicodeWhitespaceRoundTripAndFileCompatibility() async throws {
        let original = "  第一行 🔐\nsecond line\t\n"
        let encrypted = try await TextCipher.process(
            original, password: try SecretBytes(utf8: "test-only-password-2026"), operation: .encrypt)
        let restored = try await TextCipher.process(
            "\n" + encrypted + "\n", password: try SecretBytes(utf8: "test-only-password-2026"), operation: .decrypt)
        XCTAssertEqual(restored, original)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("text.hycrypt")
        try XCTUnwrap(Data(base64Encoded: encrypted)).write(to: source)
        let output = root.appendingPathComponent("plain")
        _ = try HycryptService.run(
            .init(
                operation: .decrypt, source: source, destination: output,
                password: try SecretBytes(utf8: "test-only-password-2026")))
        XCTAssertEqual(try String(contentsOf: output, encoding: .utf8), original)
        let file = root.appendingPathComponent("file.hycrypt")
        _ = try HycryptService.run(
            .init(
                operation: .encrypt, source: output, destination: file,
                password: try SecretBytes(utf8: "test-only-password-2026")))
        let fileText = try await TextCipher.process(
            Data(contentsOf: file).base64EncodedString(), password: try SecretBytes(utf8: "test-only-password-2026"),
            operation: .decrypt)
        XCTAssertEqual(fileText, original)
    }

    func testWrongPasswordTamperingAndTruncationAreRejected() async throws {
        let encrypted = try await TextCipher.process(
            "secret", password: try SecretBytes(utf8: "test-only-password-2026"), operation: .encrypt)
        var damaged = try XCTUnwrap(Data(base64Encoded: encrypted))
        damaged[30] ^= 1
        let bytes = try XCTUnwrap(Data(base64Encoded: encrypted))
        for (input, passwordString) in [
            (encrypted, "wrong"), (damaged.base64EncodedString(), "test-only-password-2026"),
            (bytes.dropLast().base64EncodedString(), "test-only-password-2026"),
            ((bytes + Data([0])).base64EncodedString(), "test-only-password-2026"),
            ("not base64!", "test-only-password-2026"),
        ] {
            do {
                _ = try await TextCipher.process(
                    input, password: SecretBytes(utf8: passwordString), operation: .decrypt)
                XCTFail("Expected rejection")
            } catch {}
        }
    }

    func testEmptyAndMaximumTextRoundTrip() async throws {
        for original in ["", String(repeating: "a", count: TextCipher.maximumBytes)] {
            let encrypted = try await TextCipher.process(
                original, password: try SecretBytes(utf8: "test-only-password-2026"), operation: .encrypt)
            let restored = try await TextCipher.process(
                encrypted, password: try SecretBytes(utf8: "test-only-password-2026"), operation: .decrypt)
            XCTAssertEqual(restored, original)
        }
    }

    func testLimitAndCancellation() async throws {
        do {
            _ = try await TextCipher.process(
                String(repeating: "x", count: TextCipher.maximumBytes + 1),
                password: try SecretBytes(utf8: "test-only-password-2026"),
                operation: .encrypt)
            XCTFail("Expected size limit")
        } catch TextCipher.TextError.tooLarge {}
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await TextCipher.process(
                "secret", password: try SecretBytes(utf8: "test-only-password-2026"), operation: .encrypt)
        }
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
    }
}
