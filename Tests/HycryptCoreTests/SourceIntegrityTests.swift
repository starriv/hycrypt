import Foundation
import XCTest
import ZIPFoundation

@testable import HycryptCore

/// Sources that change while being read must fail instead of producing valid ciphertext
/// of content the user did not select.
final class SourceIntegrityTests: XCTestCase {
    private var root: URL!
    private var password: SecretBytes {
        try! SecretBytes(utf8: "test-only-password-2026")
    }

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("hycrypt-integrity-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    private func url(_ name: String) -> URL { root.appendingPathComponent(name) }

    private func assertNoOutputOrStaging(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: url(name).path), file: file, line: line)
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".hycrypt-") },
            file: file, line: line)
    }

    func testReplacedAncestorCannotRedirectArchiveReads() throws {
        let manager = FileManager.default
        let source = url("source")
        let nested = source.appendingPathComponent("nested")
        let outside = url("outside")
        try manager.createDirectory(at: nested, withIntermediateDirectories: true)
        try manager.createDirectory(at: outside, withIntermediateDirectories: true)
        // "a" sorts first: the swap happens after "nested" is open but before "file" is.
        try Data("first".utf8).write(to: nested.appendingPathComponent("a"))
        try Data("INSIDE!".utf8).write(to: nested.appendingPathComponent("file"))
        try Data("OUTSIDE".utf8).write(to: outside.appendingPathComponent("file"))
        let archiveURL = url("packed.zip")
        let moved = url("moved")
        let swapped = Locked(false)
        try DirectoryArchive.pack(source: source, destination: archiveURL) { update in
            guard update.phase == .archiving("nested/a"), !swapped.value else { return }
            swapped.value = true
            try! FileManager.default.moveItem(at: nested, to: moved)
            try! FileManager.default.createSymbolicLink(at: nested, withDestinationURL: outside)
        }
        XCTAssertTrue(swapped.value)
        let archive = try Archive(url: archiveURL, accessMode: .read)
        let entry = try XCTUnwrap(archive["source/nested/file"])
        var restored = Data()
        _ = try archive.extract(entry) { restored.append($0) }
        XCTAssertEqual(restored, Data("INSIDE!".utf8))
    }

    func testTruncationDuringEncryptionIsRejected() throws {
        let source = url("source")
        try Data(repeating: 65, count: FileCipher.chunkSize * 2).write(to: source)
        XCTAssertThrowsError(
            try HycryptService.run(
                .init(operation: .encrypt, source: source, destination: url("out"), password: password)
            ) { update in
                if update.phase == .encrypting && update.fraction == 0.5 {
                    let handle = try! FileHandle(forWritingTo: source)
                    try! handle.truncate(atOffset: UInt64(FileCipher.chunkSize))
                    try! handle.close()
                }
            }
        ) { assertSourceChanged($0) }
        try assertNoOutputOrStaging("out")
    }

    func testGrowthDuringEncryptionIsRejected() throws {
        let source = url("source")
        try Data(repeating: 65, count: FileCipher.chunkSize * 2).write(to: source)
        XCTAssertThrowsError(
            try HycryptService.run(
                .init(operation: .encrypt, source: source, destination: url("out"), password: password)
            ) { update in
                if update.phase == .encrypting && update.fraction == 0.5 {
                    let handle = try! FileHandle(forWritingTo: source)
                    try! handle.seekToEnd()
                    try! handle.write(contentsOf: Data(repeating: 66, count: 10))
                    try! handle.close()
                }
            }
        ) { assertSourceChanged($0) }
        try assertNoOutputOrStaging("out")
    }

    func testFileTruncatedWhileArchivingIsRejected() throws {
        let folder = url("folder")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let file = folder.appendingPathComponent("large")
        try Data(repeating: 65, count: FileIO.bufferSize * 3).write(to: file)
        let truncated = Locked(false)
        XCTAssertThrowsError(
            try HycryptService.run(
                .init(operation: .encrypt, source: folder, destination: url("out"), password: password)
            ) { update in
                guard update.phase == .archiving("large"), !truncated.value else { return }
                truncated.value = true
                let handle = try! FileHandle(forWritingTo: file)
                try! handle.truncate(atOffset: 10)
                try! handle.close()
            }
        ) { assertSourceChanged($0) }
        try assertNoOutputOrStaging("out")
    }

    func testSameSizeRewriteWithRestoredModificationTimeIsRejected() throws {
        let source = url("source")
        try Data(repeating: 65, count: FileCipher.chunkSize * 2).write(to: source)
        let modified = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: source.path)[.modificationDate] as? Date)
        XCTAssertThrowsError(
            try HycryptService.run(
                .init(operation: .encrypt, source: source, destination: url("out"), password: password)
            ) { update in
                guard update.phase == .encrypting, update.fraction == 0.5 else { return }
                let handle = try! FileHandle(forWritingTo: source)
                try! handle.seek(toOffset: 0)
                try! handle.write(contentsOf: Data(repeating: 66, count: FileCipher.chunkSize))
                try! handle.close()
                try! FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: source.path)
            }
        ) { assertSourceChanged($0) }
        try assertNoOutputOrStaging("out")
    }

    func testPrivateStagingIsOutsideTheDestinationFolder() throws {
        let parent = url("dest")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let transaction = try OutputTransaction(destination: parent.appendingPathComponent("out"))
        defer { transaction.cleanUp() }
        let stagingParent = transaction.directory.deletingLastPathComponent().resolvingSymlinksInPath()
        let destinationParent = parent.resolvingSymlinksInPath()
        XCTAssertNotEqual(stagingParent, destinationParent)
        XCTAssertFalse(stagingParent.path.hasPrefix(destinationParent.path + "/"))
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(atPath: parent.path).contains { $0.hasPrefix(".hycrypt-") })
    }
}

private func assertSourceChanged(_ error: Error, file: StaticString = #filePath, line: UInt = #line) {
    guard case .sourceChanged? = error as? HycryptError else {
        return XCTFail("Expected sourceChanged, got \(error)", file: file, line: line)
    }
}

/// Progress handlers are @Sendable; tests mutate a flag from inside them.
private final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value
    init(_ value: Value) { stored = value }
    var value: Value {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

final class StagingRecoveryTests: XCTestCase {
    func testAbandonedLocalScratchIsRemovedButLiveScratchIsPreserved() throws {
        let manager = FileManager.default
        let live = try OutputTransaction.makeLocalScratch()
        defer { live.remove() }
        try Data("synthetic plaintext".utf8).write(to: live.directory.appendingPathComponent("payload"))
        try manager.setAttributes(
            [.creationDate: Date().addingTimeInterval(-3_600)], ofItemAtPath: live.directory.path)

        let stale = manager.temporaryDirectory.appendingPathComponent(
            OutputTransaction.scratchPrefix + UUID().uuidString, isDirectory: true)
        try manager.createDirectory(
            at: stale, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        try Data("stale plaintext".utf8).write(to: stale.appendingPathComponent("payload"))
        try manager.setAttributes(
            [.creationDate: Date().addingTimeInterval(-3_600)], ofItemAtPath: stale.path)
        defer { try? manager.removeItem(at: stale) }

        OutputTransaction.removeAbandonedScratch()
        XCTAssertTrue(manager.fileExists(atPath: live.directory.path))
        XCTAssertFalse(manager.fileExists(atPath: stale.path))
        live.remove()
        XCTAssertFalse(manager.fileExists(atPath: live.directory.path))
    }

    func testOnlyAbandonedStagingIsRemoved() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("hycrypt-staging-" + UUID().uuidString)
        try manager.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: root) }
        let probe = try OutputTransaction(destination: root.appendingPathComponent("probe"))
        let stagingParent = probe.directory.deletingLastPathComponent()
        probe.cleanUp()

        func staging(_ name: String, age: TimeInterval) throws -> URL {
            let directory = stagingParent.appendingPathComponent(name)
            try manager.createDirectory(at: directory, withIntermediateDirectories: false)
            try Data("synthetic plaintext".utf8).write(to: directory.appendingPathComponent("payload"))
            try manager.setAttributes([.creationDate: Date().addingTimeInterval(-age)], ofItemAtPath: directory.path)
            return directory
        }
        let abandoned = try staging(".hycrypt-" + UUID().uuidString, age: 3_600)
        let fresh = try staging(".hycrypt-" + UUID().uuidString, age: 0)
        let unrelated = try staging(".hycrypt-notes", age: 3_600)
        let live = try staging(".hycrypt-" + UUID().uuidString, age: 3_600)
        defer {
            for url in [fresh, unrelated, live] where manager.fileExists(atPath: url.path) {
                try? manager.removeItem(at: url)
            }
        }
        let liveFD = open(live.path, O_RDONLY | O_DIRECTORY)
        XCTAssertGreaterThanOrEqual(liveFD, 0)
        defer { close(liveFD) }
        XCTAssertEqual(flock(liveFD, LOCK_EX | LOCK_NB), 0)

        let source = root.appendingPathComponent("source")
        try Data([1, 2, 3]).write(to: source)
        try HycryptService.run(
            .init(
                operation: .encrypt, source: source, destination: root.appendingPathComponent("out"),
                password: SecretBytes(utf8: "test-only-password-2026")))

        XCTAssertFalse(manager.fileExists(atPath: abandoned.path))
        XCTAssertTrue(manager.fileExists(atPath: fresh.path))
        XCTAssertTrue(manager.fileExists(atPath: unrelated.path))
        XCTAssertTrue(manager.fileExists(atPath: live.path))
        XCTAssertFalse(
            try manager.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".hycrypt-") })
    }
}
