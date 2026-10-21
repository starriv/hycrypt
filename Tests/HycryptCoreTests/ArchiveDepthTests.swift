import Foundation
import XCTest
import ZIPFoundation

@testable import HycryptCore

final class ArchiveDepthTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hycrypt-depth-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testSafeComponentsRejectsExcessiveDepthAndLength() {
        let deep = Array(repeating: "d", count: DirectoryArchive.maximumDepth + 1).joined(separator: "/")
        XCTAssertThrowsError(try DirectoryArchive.safeComponents(deep))
        let long = String(repeating: "a", count: DirectoryArchive.maximumPathBytes + 1)
        XCTAssertThrowsError(try DirectoryArchive.safeComponents(long))
    }

    func testDeepSourceIsRejectedBeforeRecursingOutOfControl() throws {
        var current = root.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: current, withIntermediateDirectories: false)
        for _ in 0..<(DirectoryArchive.maximumDepth + 8) {
            current.appendPathComponent("d", isDirectory: true)
            try FileManager.default.createDirectory(at: current, withIntermediateDirectories: false)
        }
        try Data("leaf".utf8).write(to: current.appendingPathComponent("file"))
        let archive = FileManager.default.temporaryDirectory
            .appendingPathComponent("hycrypt-deep-" + UUID().uuidString + ".zip")
        defer { try? FileManager.default.removeItem(at: archive) }
        XCTAssertThrowsError(
            try DirectoryArchive.pack(source: root.appendingPathComponent("source"), destination: archive) { _ in }
        ) { error in
            guard case HycryptError.unsafeArchive = error else {
                return XCTFail("Expected unsafeArchive, got \(error)")
            }
        }
    }

    func testDeepArchivePathIsRejected() throws {
        let archiveURL = root.appendingPathComponent("deep.zip")
        let archive = try Archive(url: archiveURL, accessMode: .create)
        let path = Array(repeating: "d", count: DirectoryArchive.maximumDepth + 1).joined(separator: "/")
        try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(1)) { _, _ in Data([1]) }
        XCTAssertThrowsError(
            try DirectoryArchive.unpack(source: archiveURL, into: root.appendingPathComponent("extract")) { _ in }
        ) { error in
            guard case HycryptError.unsafeArchive = error else {
                return XCTFail("Expected unsafeArchive, got \(error)")
            }
        }
    }

    func testInvalidUTF8NameDecoderFailsClosed() {
        XCTAssertEqual(DirectoryArchive.decodeName(Array("valid-file".utf8)), "valid-file")
        XCTAssertNil(DirectoryArchive.decodeName([0x62, 0x61, 0x64, 0xFF]))
        XCTAssertNil(DirectoryArchive.decodeName([0xC3, 0x28]))
    }

    func testIterativeCleanupHandlesDeepTree() throws {
        var current = root.appendingPathComponent("cleanup")
        try FileManager.default.createDirectory(at: current, withIntermediateDirectories: false)
        for _ in 0..<(DirectoryArchive.maximumDepth + 8) {
            current.appendPathComponent("d", isDirectory: true)
            try FileManager.default.createDirectory(at: current, withIntermediateDirectories: false)
        }
        try Data("leaf".utf8).write(to: current.appendingPathComponent("file"))
        OutputTransaction.removePrivateDirectory(at: root.appendingPathComponent("cleanup"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("cleanup").path))
    }
}
