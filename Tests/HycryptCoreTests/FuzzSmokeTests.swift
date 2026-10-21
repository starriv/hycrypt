import Foundation
import XCTest

@testable import HycryptCore

/// Deterministic smoke coverage for the byte/path parsers. These are not full fuzzers;
/// they exercise random malformed inputs cheaply on every test run.
final class FuzzSmokeTests: XCTestCase {
    func testRandomPathsNeverEscape() {
        var generator = SystemRandomNumberGenerator()
        let alphabet: [UInt8] = [0x2F, 0x2E, 0x3A, 0x5C, 0x00, 0x61, 0x62, 0xC3, 0xFF, 0x20]
        for _ in 0..<2_000 {
            let length = Int.random(in: 0...64, using: &generator)
            let bytes = (0..<length).map { _ in alphabet.randomElement(using: &generator)! }
            let path = String(decoding: bytes, as: UTF8.self)
            guard let parts = try? DirectoryArchive.safeComponents(path) else { continue }
            XCTAssertFalse(parts.contains(".."))
            XCTAssertFalse(parts.contains("."))
            XCTAssertFalse(parts.contains(where: { $0.isEmpty || $0.contains(":") }))
            XCTAssertLessThanOrEqual(parts.count, DirectoryArchive.maximumDepth)
        }
    }

    func testRandomTextDecryptFailsClosed() async throws {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<100 {
            let length = Int.random(in: 0...64, using: &generator)
            let data = Data((0..<length).map { _ in UInt8.random(in: 0...255, using: &generator) })
            let text = data.base64EncodedString()
            do {
                _ = try await TextCipher.process(
                    text, password: SecretBytes(utf8: "fuzz-only-password"), operation: .decrypt)
                XCTFail("Random payload was accepted")
            } catch {}
        }
    }
}
