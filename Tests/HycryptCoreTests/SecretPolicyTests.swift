import CryptoKit
import Foundation
import XCTest

@testable import HycryptCore

final class SecretPolicyTests: XCTestCase {
    func testEmptyPasswordsAreRejectedButOldPasswordsRemainReadable() async throws {
        for password in [""] {
            do {
                _ = try await TextCipher.process("secret", password: SecretBytes(utf8: password), operation: .encrypt)
                XCTFail("Weak password accepted")
            } catch {}
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source")
        let destination = root.appendingPathComponent("encrypted")
        try Data("secret".utf8).write(to: source)
        XCTAssertThrowsError(
            try HycryptService.run(
                .init(
                    operation: .encrypt, source: source, destination: destination, password: SecretBytes(utf8: ""))))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["source"])

        // Construct an old V2 payload independently of the new encryption policy.
        let salt = Data(0..<16)
        let header = FileCipher.magic + salt + Data([0])
        let key = try KeyDerivation.derive(password: SecretBytes(utf8: "old"), salt: salt)
        var data = header
        for (index, bytes) in [Data("old secret".utf8), Data()].enumerated() {
            let sequence = FileCipher.encode(UInt64(index))
            let length = FileCipher.encode(UInt32(bytes.count))
            let nonce = try AES.GCM.Nonce(data: Data(repeating: 0, count: 4) + sequence)
            let sealed = try AES.GCM.seal(bytes, using: key, nonce: nonce, authenticating: header + sequence + length)
            data.append(length + sealed.ciphertext + sealed.tag)
        }
        let result = try await TextCipher.process(
            data.base64EncodedString(), password: SecretBytes(utf8: "old"), operation: .decrypt)
        XCTAssertEqual(result, "old secret")
        try data.write(to: source)
        _ = try HycryptService.run(
            .init(operation: .decrypt, source: source, destination: destination, password: SecretBytes(utf8: "old")))
        XCTAssertEqual(try Data(contentsOf: destination), Data("old secret".utf8))
    }

    func testNonemptyPasswordsHaveNoComplexityRequirements() {
        for weak in [
            "a", "short", String(repeating: "x", count: 2048), "1234567890123456", "abcdefghijklmnop",
            "ponmlkjihgfedcba", String(repeating: "ab12", count: 6),
            "aaaabbbbccccdddd", String(repeating: "长口令", count: 6), "qwertyuiopQWERTY", "0987654321098765",
        ] {
            XCTAssertNoThrow(try SecretPolicy.validatePassword(weak, operation: .encrypt), weak)
            XCTAssertNoThrow(try SecretPolicy.validatePassword(weak, operation: .decrypt), weak)
        }
        for accepted in ["test-only-password-2026", "River!lantern8meadow", "测试-password-2026-🔐"] {
            XCTAssertNoThrow(try SecretPolicy.validatePassword(accepted, operation: .encrypt), accepted)
        }
        XCTAssertTrue(SecretPolicy.mayDependOnInputMethod("测试-password-2026-🔐"))
        XCTAssertFalse(SecretPolicy.mayDependOnInputMethod("test-only-password-2026"))
    }

    func testEncryptionPasswordLengthAndWhitespacePolicy() throws {
        let long = String(repeating: "a", count: SecretPolicy.maximumPasswordBytes + 1)
        XCTAssertThrowsError(try SecretPolicy.validatePassword(long, operation: .encrypt))
        XCTAssertNoThrow(try SecretPolicy.validatePassword(long, operation: .decrypt))
        XCTAssertThrowsError(
            try SecretPolicy.validatePassword(SecretBytes(utf8: long), operation: .encrypt))
        XCTAssertNoThrow(
            try SecretPolicy.validatePassword(SecretBytes(utf8: long), operation: .decrypt))
        XCTAssertThrowsError(
            try SecretPolicy.validatePassword(SecretBytes(utf8: "a\tb"), operation: .encrypt))
        XCTAssertThrowsError(
            try SecretPolicy.validatePassword(SecretBytes(utf8: "a\u{00a0}b"), operation: .encrypt))
        XCTAssertNoThrow(
            try SecretPolicy.validatePassword(SecretBytes(utf8: "a\tb"), operation: .decrypt))
    }

    func testMnemonicPreservesExactBytesAndRejectsWrongShape() async throws {
        let input = "  " + Array(repeating: "abandon", count: 23).joined(separator: " ") + "\nart\t"
        let password = try SecretBytes(utf8: "a")
        let encrypted = try await TextCipher.process(input, password: password, operation: .encrypt, kind: .mnemonic)
        let restored = try await TextCipher.process(encrypted, password: password, operation: .decrypt, kind: .mnemonic)
        XCTAssertEqual(restored, input)
        let text = try await TextCipher.process(encrypted, password: password, operation: .decrypt)
        XCTAssertEqual(text, input)
        XCTAssertThrowsError(try SecretPolicy.TextKind.mnemonic.validate("only two"))
        XCTAssertThrowsError(try SecretPolicy.TextKind.mnemonic.validate(String(repeating: "word ", count: 1_000)))
        let ordinary = try await TextCipher.process("ordinary text", password: password, operation: .encrypt)
        do {
            _ = try await TextCipher.process(ordinary, password: password, operation: .decrypt, kind: .mnemonic)
            XCTFail("Invalid mnemonic accepted")
        } catch BIP39.Failure.invalidWordCount {}
    }

    func testReplacedDestinationParentCannotRedirectPublication() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let parent = root.appendingPathComponent("parent")
        let moved = root.appendingPathComponent("moved")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let transaction = try OutputTransaction(destination: parent.appendingPathComponent("result"))
        let payload = transaction.directory.appendingPathComponent("payload")
        try Data("secret".utf8).write(to: payload)
        try FileManager.default.moveItem(at: parent, to: moved)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        XCTAssertThrowsError(try transaction.commit(payload))
        transaction.cleanUp()
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: parent.path), [])
    }
}
