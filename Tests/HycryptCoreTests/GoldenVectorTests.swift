import Foundation
import XCTest

@testable import HycryptCore

/// Frozen HYCRYPT2 payloads produced by the 2.0.0 implementation. Every future build must
/// decrypt them unchanged; a failure here means the on-disk format changed.
final class GoldenVectorTests: XCTestCase {
    private var password: SecretBytes {
        try! SecretBytes(utf8: "golden-vector-password-2026")
    }
    private let file =
        "SFlDUllQVDLPftbicVB5T5NmuGDY8oizAAAAABnS1wk47k0dAbqU+ygyIB13AMFzYrdvL8MzHG5IswEhacAXhWRLmwI8vwAA"
        + "AAD/tKhuyIZgWX8S10fZsZTF"
    private let directory =
        "SFlDUllQVDI+ikvlbF50bStQXBP9yJp2AQAAAUyOc0HTJA/GoQFfU+sjo1iAsl66NA8j6VpG4WO5lA3TBXr+WkVM6GIsWOyv"
        + "S6C9NoWBqZOo64N+Nu4eQP9uhdh7Vy9U7tPPsAEWmOI/32AH1EzL1TAezbYNywoE2/C6OEE/JKbQcZTtrmUv5Zds8z+7AGa2"
        + "bGNPe2Y8UxZRoPN2KccOB+Lb2cJbMVKvCo0NSuhxmMweOhoWhdx6dCAI6f4NMm4Tu6Nj4lHJF3BNjMH84QCuECe+AMpT7wgU"
        + "QsBVwOWSY8nfFOBp0DwnRh6cnACbXuCWy7QmxXL5rE8xn9hIAjm5tGiKk+7k+f08dN15ror7rDVHpHyyqiTKcZUDzJbrjhYO"
        + "BdmE6F+ijHs/BmfeDPRugsxqyVyU8wNIXxsxW3t6nJF8zMqkj6+pzCgUd0WyLIcHLTGEybZmHEMvMklTBGP7gJ/l/LJRwLyP"
        + "+XbHQuVYqUUjwNLtURHHZbkAAAAAI6b4ShriGTfUk1PkqZMQ4w=="

    private func decrypt(_ base64: String) throws -> (URL, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("hycrypt-golden-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let source = root.appendingPathComponent("vector.hycrypt")
        try XCTUnwrap(Data(base64Encoded: base64)).write(to: source)
        let output = try HycryptService.run(
            .init(
                operation: .decrypt, source: source, destination: root.appendingPathComponent("restored"),
                password: password))
        return (root, output)
    }

    func testFrozenFilePayloadDecrypts() throws {
        let (root, output) = try decrypt(file)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertEqual(try Data(contentsOf: output), Data("Hycrypt V2 golden vector\n".utf8))
    }

    func testFrozenDirectoryPayloadDecrypts() throws {
        let (root, output) = try decrypt(directory)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertEqual(
            try Data(contentsOf: output.appendingPathComponent("sub/a.txt")), Data("nested file\n".utf8))
    }

    func testFrozenTextPayloadDecrypts() async throws {
        let text = try await TextCipher.process(file, password: password, operation: .decrypt)
        XCTAssertEqual(text, "Hycrypt V2 golden vector\n")
    }
}
