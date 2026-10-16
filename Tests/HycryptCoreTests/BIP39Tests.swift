import Foundation
import XCTest

@testable import HycryptCore

final class BIP39Tests: XCTestCase {
    private var password: SecretBytes {
        try! SecretBytes(utf8: "test-only-password-2026")
    }

    func testAllPublishedEnglishVectors() throws {
        XCTAssertEqual(BIP39Vectors.english.count, 24)
        for (hex, expected) in BIP39Vectors.english {
            let entropy = try decodeHex(hex)
            let actual = try BIP39.mnemonicBytes(entropy: entropy)
            XCTAssertEqual(String(data: actual, encoding: .utf8), expected)
            XCTAssertNoThrow(try BIP39.validate(expected))
            XCTAssertNoThrow(try BIP39.validate(words: expected.split(separator: " ").map(String.init)))
        }
    }

    func testPlaintextGenerationUsesSystemEntropyAndFailsClosed() throws {
        let words = try BIP39.generateWords { buffer in
            XCTAssertEqual(buffer.count, 32)
            buffer.initializeMemory(as: UInt8.self, repeating: 0)
        }
        XCTAssertEqual(words, Array(repeating: "abandon", count: 23) + ["art"])
        XCTAssertThrowsError(try BIP39.generateWords { _ in throw HycryptError.cryptoFailure(-1) })
        let generated = try BIP39.generateWords()
        XCTAssertEqual(generated.count, 24)
        XCTAssertNoThrow(try BIP39.validate(words: generated, requiredWordCount: 24))
    }

    func testPinnedWordListFailsClosedOnTampering() throws {
        let list = try BIP39.WordList(text: BIP39English.text)
        XCTAssertEqual(list.words.count, 2_048)
        XCTAssertEqual(list.words.first, "abandon")
        XCTAssertEqual(list.words.last, "zoo")
        for changed in [
            "", BIP39English.text + "extra\n", BIP39English.text.replacingOccurrences(of: "abandon", with: "ability"),
        ] {
            XCTAssertThrowsError(try BIP39.WordList(text: changed))
        }
        XCTAssertFalse(BIP39.contains("Abandon"))
        XCTAssertFalse(BIP39.contains("аbandon"))  // Cyrillic a
        XCTAssertFalse(BIP39.contains("abandon\0"))
    }

    func testWordArrayValidationRejectsMalformedDrafts() {
        let valid = Array(repeating: "abandon", count: 23) + ["art"]
        XCTAssertNoThrow(try BIP39.validate(words: valid, requiredWordCount: 24))
        XCTAssertThrowsError(try BIP39.validate(words: Array(valid.dropLast()), requiredWordCount: 24))
        XCTAssertThrowsError(try BIP39.validate(words: Array(repeating: "abandon", count: 24)))
        for invalid in ["abandon art", "Abandon", "", String(repeating: "a", count: 4097)] {
            var words = valid
            words[0] = invalid
            XCTAssertThrowsError(try BIP39.validate(words: words))
        }
    }

    func testWordCountVocabularyAndChecksumAreIndependentlyChecked() throws {
        let zero = Array(repeating: "abandon", count: 23).joined(separator: " ") + " art"
        XCTAssertNoThrow(try BIP39.validate(zero, requiredWordCount: 24))
        XCTAssertThrowsError(try BIP39.validate(Array(repeating: "abandon", count: 24).joined(separator: " "))) {
            XCTAssertTrue($0 is BIP39.Failure)
        }
        XCTAssertThrowsError(try BIP39.validate(zero.replacingOccurrences(of: "art", with: "notaword")))
        XCTAssertThrowsError(try BIP39.validate(zero + " zoo"))
        XCTAssertThrowsError(try BIP39.validate(BIP39Vectors.english[0].1, requiredWordCount: 24))
        XCTAssertThrowsError(try BIP39.validate(String(repeating: "x", count: 4_097)))
        for size in [0, 1, 15, 17, 31, 33, 64] {
            XCTAssertThrowsError(try BIP39.mnemonicBytes(entropy: Data(count: size)))
        }
    }

    func testEntireLastWordSpaceChecksAllEightChecksumBits() throws {
        let list = try BIP39.WordList(text: BIP39English.text)
        let prefix = Array(repeating: "abandon", count: 23).joined(separator: " ") + " "
        var valid = 0
        for word in list.words {
            if (try? BIP39.validate(prefix + word, requiredWordCount: 24)) != nil { valid += 1 }
        }
        // 11 bits per last word = 3 entropy bits + 8 checksum bits -> exactly eight valid endings.
        XCTAssertEqual(valid, 8)
    }

    func testSuggestionsAreBoundedExactAndCompleteForFourLetterPrefixes() throws {
        let list = try BIP39.WordList(text: BIP39English.text)
        for word in list.words {
            let prefix = String(word.prefix(4))
            XCTAssertTrue(BIP39.suggestions(for: prefix).contains(word))
        }
        XCTAssertEqual(BIP39.suggestions(for: "aban"), ["abandon"])
        XCTAssertEqual(BIP39.suggestions(for: "a", limit: Int.max).count, 8)
        XCTAssertEqual(BIP39.suggestions(for: "a", limit: 0), [])
        for prefix in ["", "A", "а", "ab\0", "abandon ", String(repeating: "x", count: 10_000)] {
            XCTAssertEqual(BIP39.suggestions(for: prefix), [])
        }
    }

    func testPrefixLookupPerformance() {
        measure {
            for _ in 0..<1_000 { _ = BIP39.suggestions(for: "ab") }
        }
    }

    func testGenerationEncryptsKnownEntropyWithoutReturningPlaintext() async throws {
        let encrypted = try TextCipher.encryptNewMnemonic(password: password) { bytes in
            XCTAssertEqual(bytes.count, 32)
            bytes.initializeMemory(as: UInt8.self, repeating: 0)
        }
        XCTAssertFalse(encrypted.contains("abandon"))
        let restored = try await TextCipher.process(encrypted, password: password, operation: .decrypt, kind: .mnemonic)
        XCTAssertEqual(restored, Array(repeating: "abandon", count: 23).joined(separator: " ") + " art")
    }

    func testSystemGenerationProducesDistinctValidPhrases() async throws {
        let first = try await TextCipher.generateMnemonic(password: password)
        let second = try await TextCipher.generateMnemonic(password: password)
        let a = try await TextCipher.process(first, password: password, operation: .decrypt, kind: .mnemonic)
        let b = try await TextCipher.process(second, password: password, operation: .decrypt, kind: .mnemonic)
        XCTAssertFalse(a == b)  // Do not print randomly generated secrets in diagnostics.
        XCTAssertEqual(a.split(separator: " ").count, 24)
        XCTAssertEqual(b.split(separator: " ").count, 24)
    }

    func testRandomFailureNeverFallsBackAndEmptyPasswordDoesNotGenerate() {
        var called = false
        XCTAssertThrowsError(try TextCipher.encryptNewMnemonic(password: SecretBytes(utf8: "")) { _ in called = true })
        XCTAssertFalse(called)
        XCTAssertThrowsError(
            try TextCipher.encryptNewMnemonic(password: password) { buffer in
                buffer[0] = 42
                throw HycryptError.cryptoFailure(-1)
            })
    }

    func testCancellationBeforeGenerationDoesNotConsumeEntropy() async {
        let password = password
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try TextCipher.encryptNewMnemonic(password: password) { _ in
                XCTFail("Cancelled generation must not request entropy")
            }
        }
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {} catch { XCTFail("Unexpected error type") }
    }

    private func decodeHex(_ hex: String) throws -> Data {
        var bytes = Data()
        var offset = hex.startIndex
        while offset < hex.endIndex {
            let end = hex.index(offset, offsetBy: 2)
            bytes.append(try XCTUnwrap(UInt8(hex[offset..<end], radix: 16)))
            offset = end
        }
        return bytes
    }
}
