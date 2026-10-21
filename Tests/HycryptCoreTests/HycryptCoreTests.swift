import CryptoKit
import Foundation
import XCTest
import ZIPFoundation

@testable import HycryptCore

final class HycryptCoreTests: XCTestCase {
    private var root: URL!
    private var password: SecretBytes!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("hycrypt-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        password = try SecretBytes(utf8: "测试-password-2026-🔐")
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    private func url(_ name: String) -> URL { root.appendingPathComponent(name) }
    private func write(_ data: Data, _ name: String) throws -> URL {
        let path = url(name)
        try data.write(to: path)
        return path
    }
    @discardableResult
    private func run(
        _ operation: CryptOperation, _ source: URL, _ name: String, password: SecretBytes? = nil
    ) throws -> URL {
        try HycryptService.run(
            .init(
                operation: operation, source: source, destination: url(name),
                password: password ?? self.password
            ))
    }
    private func assertNoStaging(file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".hycrypt-") },
            file: file, line: line)
    }

    func testMultichunkRoundTripAndEmptyFile() throws {
        for (index, data) in [Data(), Data((0..<(FileCipher.chunkSize * 2 + 37)).map { UInt8($0 % 251) })].enumerated()
        {
            let source = try write(data, "input-\(index)")
            let encrypted = try run(.encrypt, source, "encrypted-\(index)")
            let restored = try run(.decrypt, encrypted, "restored-\(index)")
            XCTAssertEqual(try Data(contentsOf: restored), data)
            XCTAssertEqual(try Data(contentsOf: source), data)
            XCTAssertEqual(try Data(contentsOf: encrypted).prefix(8), FileCipher.magic)
        }
        try assertNoStaging()
    }

    func testRandomSaltProducesDifferentCiphertexts() throws {
        let source = try write(Data("same contents".utf8), "source")
        let first = try run(.encrypt, source, "first")
        let second = try run(.encrypt, source, "second-test-password-2026")
        XCTAssertNotEqual(try Data(contentsOf: first), try Data(contentsOf: second))
    }

    func testWrongPasswordTamperingAndTruncationNeverPublishOutput() throws {
        let source = try write(Data(repeating: 0x42, count: FileCipher.chunkSize + 25), "source")
        let encrypted = try run(.encrypt, source, "encrypted")
        let original = try Data(contentsOf: encrypted)
        XCTAssertThrowsError(try run(.decrypt, encrypted, "wrong-password", password: try SecretBytes(utf8: "wrong")))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url("wrong-password").path))
        var damagedHeader = original
        damagedHeader[24] ^= 1
        var damagedCiphertext = original
        damagedCiphertext[30] ^= 1
        var damagedSecondChunk = original
        damagedSecondChunk[FileCipher.headerSize + 4 + FileCipher.chunkSize + 16 + 4] ^= 1
        var damagedTag = original
        damagedTag[damagedTag.count - 1] ^= 1
        var oversized = original
        oversized.replaceSubrange(25..<29, with: [0xff, 0xff, 0xff, 0xff])
        let mutations = [
            damagedHeader, damagedCiphertext, damagedSecondChunk, damagedTag, oversized,
            Data(original.dropLast(20)), Data(original.dropLast()), original + Data([1]),
        ]
        for (index, mutation) in mutations.enumerated() {
            let corrupt = try write(mutation, "corrupt-\(index)")
            XCTAssertThrowsError(try run(.decrypt, corrupt, "bad-\(index)"))
            XCTAssertFalse(FileManager.default.fileExists(atPath: url("bad-\(index)").path))
            try assertNoStaging()
        }
    }

    func testDirectoryRoundTripPreservesNestedEmptyAndHiddenFiles() throws {
        let folder = url("资料")
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("nested/empty"), withIntermediateDirectories: true)
        let bytes = Data("hello\0世界".utf8)
        try bytes.write(to: folder.appendingPathComponent("nested/文档.txt"))
        try Data().write(to: folder.appendingPathComponent(".hidden"))
        let encrypted = try run(.encrypt, folder, "folder.hycrypt")
        let restored = try run(.decrypt, encrypted, "恢复")
        XCTAssertEqual(try Data(contentsOf: restored.appendingPathComponent("nested/文档.txt")), bytes)
        XCTAssertTrue(FileManager.default.fileExists(atPath: restored.appendingPathComponent("nested/empty").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: restored.appendingPathComponent(".hidden").path))
        try assertNoStaging()
    }

    func testEmptyDirectoryRoundTrip() throws {
        let folder = url("empty")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let encrypted = try run(.encrypt, folder, "folder.hycrypt")
        let restored = try run(.decrypt, encrypted, "restored")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: restored.path), [])
    }

    func testKeyDerivationKnownAnswer() throws {
        // Cross-implementation Argon2id vector for the fixed V2 parameters.
        let derived = try KeyDerivation.derive(password: try SecretBytes(utf8: "legacy-test-密码"), salt: Data(0..<16))
        let hex = derived.withUnsafeBytes { buffer in buffer.map { String(format: "%02x", $0) }.joined() }
        XCTAssertEqual(hex, "da14a80bad0a507573b0d489b25da455c6678f48e35c2fe7f2a4e76c41219ab8")
    }

    func testUnsupportedFormatsNeverPublishOutput() throws {
        let inputs = [
            Data(), Data("HYCRYPT1".utf8), Data("HYCRYPT3".utf8),
            Data(repeating: 0x42, count: 64), Data("HYCRYPT2".utf8),
        ]
        for (index, bytes) in inputs.enumerated() {
            let source = try write(bytes, "unsupported-\(index)")
            XCTAssertThrowsError(try run(.decrypt, source, "output-\(index)")) { error in
                guard case HycryptError.invalidFormat = error else {
                    return XCTFail("Expected invalid format, got \(error)")
                }
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: url("output-\(index)").path))
            try assertNoStaging()
        }
    }

    func testExistingDestinationSourceAndDanglingLinkAreNeverOverwritten() throws {
        let source = try write(Data("original".utf8), "source")
        let destination = try write(Data("keep".utf8), "destination")
        XCTAssertThrowsError(try run(.encrypt, source, "source"))
        XCTAssertThrowsError(try run(.encrypt, source, "destination"))
        try FileManager.default.createSymbolicLink(at: url("link"), withDestinationURL: url("absent"))
        XCTAssertThrowsError(try run(.encrypt, source, "link"))
        XCTAssertEqual(try Data(contentsOf: source), Data("original".utf8))
        XCTAssertEqual(try Data(contentsOf: destination), Data("keep".utf8))
    }

    func testRejectOutputWithinSourceIncludingParentSymlink() throws {
        let folder = url("folder")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: url("alias"), withDestinationURL: folder)
        XCTAssertThrowsError(try run(.encrypt, folder, "folder/output.hycrypt"))
        XCTAssertThrowsError(try run(.encrypt, folder, "alias/output.hycrypt"))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), [])
    }

    func testRejectSymlinkSourcesAndDirectoryChildren() throws {
        let source = try write(Data([1]), "source")
        let folder = url("folder")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let link = folder.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        XCTAssertThrowsError(try run(.encrypt, link, "output"))
        XCTAssertThrowsError(try run(.encrypt, folder, "output"))
        try assertNoStaging()
    }

    func testCancellationCleansUpAndNeverPublishes() async throws {
        let source = try write(Data(repeating: 0x42, count: FileCipher.chunkSize * 3), "source")
        let destination = url("cancelled")
        let request = OperationRequest(
            operation: .encrypt, source: source, destination: destination, password: password)
        let task = Task.detached {
            try HycryptService.run(request) { update in
                if update.fraction != nil { withUnsafeCurrentTask { $0?.cancel() } }
            }
        }
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        try assertNoStaging()
    }

    func testDestinationCreatedDuringWorkIsPreserved() throws {
        let source = try write(Data([1, 2, 3]), "source")
        let destination = url("raced")
        XCTAssertThrowsError(
            try HycryptService.run(
                .init(operation: .encrypt, source: source, destination: destination, password: password)
            ) { update in
                if update.phase == .saving { try? Data("keep".utf8).write(to: destination) }
            })
        XCTAssertEqual(try Data(contentsOf: destination), Data("keep".utf8))
        try assertNoStaging()
    }

    func testUnsafeArchivePathsAndSymlinksAreRejected() throws {
        for path in [
            "../escape", "/absolute", "root/../escape", "root//file", "root/./file", "root\\file", "root/file:stream",
            "",
        ] {
            XCTAssertThrowsError(try DirectoryArchive.safeComponents(path), path)
        }
        let archiveURL = url("evil.zip")
        let archive = try Archive(url: archiveURL, accessMode: .create)
        let bytes = Data("../outside".utf8)
        try archive.addEntry(with: "root/link", type: .symlink, uncompressedSize: Int64(bytes.count)) { _, _ in bytes }
        XCTAssertThrowsError(try DirectoryArchive.unpack(source: archiveURL, into: url("extract"), progress: { _ in }))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url("extract").path))
    }

    func testZIPTraversalDuplicateAndMultipleRootsAreRejected() throws {
        for (index, names) in [["../escape"], ["root/file", "root/file"], ["one/file", "two/file"]].enumerated() {
            let archiveURL = url("bad-\(index).zip")
            let archive = try Archive(url: archiveURL, accessMode: .create)
            for name in names {
                try archive.addEntry(with: name, type: .file, uncompressedSize: Int64(1)) { _, _ in Data([1]) }
            }
            XCTAssertThrowsError(
                try DirectoryArchive.unpack(source: archiveURL, into: url("extract-\(index)"), progress: { _ in }))
            XCTAssertFalse(FileManager.default.fileExists(atPath: url("extract-\(index)").path))
        }
    }

    func testEmptyPasswordAndMalformedInputAreRejected() throws {
        let source = try write(Data([1, 2, 3]), "source")
        XCTAssertThrowsError(try run(.encrypt, source, "empty", password: try SecretBytes(utf8: "")))
        XCTAssertThrowsError(try run(.decrypt, source, "bad"))
        try assertNoStaging()
    }

    func testSuggestedOutputNames() {
        XCTAssertEqual(CryptOperation.encrypt.suggestedOutputName(for: url("report.txt")), "report.txt.hycrypt")
        XCTAssertEqual(CryptOperation.decrypt.suggestedOutputName(for: url("report.txt.hycrypt")), "report.txt")
        XCTAssertEqual(CryptOperation.decrypt.suggestedOutputName(for: url("archive.bin")), "archive.bin.restored")
    }
    func testLargeFileStreamingRoundTrip() throws {
        let source = url("large")
        let output = try FileIO.createOutput(source)
        let chunk = Data(repeating: 0xA7, count: FileCipher.chunkSize)
        var expected = SHA256()
        for _ in 0..<64 {
            try output.write(contentsOf: chunk)
            expected.update(data: chunk)
        }
        try output.close()
        let encrypted = try run(.encrypt, source, "large.hycrypt")
        let restored = try run(.decrypt, encrypted, "large-restored")
        let input = try FileIO.openInput(restored)
        defer { try? input.close() }
        var actual = SHA256()
        while let bytes = try input.read(upToCount: FileCipher.chunkSize), !bytes.isEmpty { actual.update(data: bytes) }
        XCTAssertEqual(actual.finalize(), expected.finalize())
        try assertNoStaging()
    }

    func testPartiallyReadableZIPIsRejected() throws {
        let archiveURL = url("partial.zip")
        do {
            let archive = try Archive(url: archiveURL, accessMode: .create)
            for name in ["root/", "root/file"] {
                try archive.addEntry(
                    with: name, type: name.hasSuffix("/") ? .directory : .file,
                    uncompressedSize: Int64(0)
                ) { _, _ in Data() }
            }
        }
        var bytes = try Data(contentsOf: archiveURL)
        let signature = Data([0x50, 0x4b, 0x01, 0x02])
        let first = try XCTUnwrap(bytes.range(of: signature))
        let second = try XCTUnwrap(bytes.range(of: signature, in: first.upperBound..<bytes.count))
        bytes[second.lowerBound] = 0
        try bytes.write(to: archiveURL)
        XCTAssertThrowsError(try DirectoryArchive.unpack(source: archiveURL, into: url("partial"), progress: { _ in }))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url("partial").path))
    }

    func testUnsupportedNamesFailBeforeEncryption() throws {
        let source = url("folder")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
        try Data([1]).write(to: source.appendingPathComponent("a:b"))
        XCTAssertThrowsError(try run(.encrypt, source, "output.hycrypt"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url("output.hycrypt").path))
        try assertNoStaging()
    }

    func testTruncatedZIP64LocatorCannotUnderflow() throws {
        var bytes = Data(repeating: 0, count: 42)
        bytes.replaceSubrange(0..<4, with: [0x50, 0x4b, 0x06, 0x07])
        bytes[16] = 1
        bytes.replaceSubrange(20..<24, with: [0x50, 0x4b, 0x05, 0x06])
        let source = try write(bytes, "short-zip64.zip")
        XCTAssertThrowsError(try ZIPValidation.entryCount(at: source))
    }

    @MainActor
    func testAsyncServiceRoundTripFromMainActor() async throws {
        let source = try write(Data("async service".utf8), "source")
        let service = HycryptService()
        let encrypted = try await service.process(
            .init(
                operation: .encrypt, source: source,
                destination: url("encrypted"), password: password))
        let restored = try await service.process(
            .init(
                operation: .decrypt, source: encrypted,
                destination: url("restored"), password: password))
        XCTAssertEqual(try Data(contentsOf: restored), Data("async service".utf8))
        try assertNoStaging()
    }

    func testAsyncServiceForwardsCallerCancellationAndWaitsForCleanup() async throws {
        let source = try write(Data([1, 2, 3]), "source")
        let destination = url("cancelled")
        let request = OperationRequest(
            operation: .encrypt, source: source, destination: destination, password: password)
        let (updates, continuation) = AsyncStream<OperationProgress>.makeStream()
        let task = Task {
            defer { continuation.finish() }
            return try await HycryptService().process(request) { continuation.yield($0) }
        }
        for await update in updates {
            if update.phase == .derivingKey {
                task.cancel()
                break
            }
        }
        do {
            _ = try await task.value
            XCTFail("Expected caller cancellation")
        } catch is CancellationError {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        try assertNoStaging()
    }

    func testDigestAndCopyHonorCancellation() async throws {
        let source = try write(Data(repeating: 0x41, count: 4_096), "cancel-source")
        let digestTask = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            let handle = try FileIO.openInput(source)
            defer { try? handle.close() }
            return try FileIO.digest(handle, count: 4_096)
        }
        do {
            _ = try await digestTask.value
            XCTFail("Expected digest cancellation")
        } catch is CancellationError {}
        let destination = url("cancel-copy")
        let copyTask = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try FileIO.copy(source, to: destination)
        }
        do {
            try await copyTask.value
            XCTFail("Expected copy cancellation")
        } catch is CancellationError {}
    }

    func testCommitRejectsSymlinkResult() throws {
        let destination = url("symlink-out")
        let transaction = try OutputTransaction(destination: destination)
        defer { transaction.cleanUp() }
        let result = transaction.directory.appendingPathComponent("payload")
        let target = try write(Data("target".utf8), "target")
        try FileManager.default.createSymbolicLink(at: result, withDestinationURL: target)
        XCTAssertThrowsError(try transaction.commit(result))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testProgressFractionsAreBounded() {
        XCTAssertEqual(OperationProgress(.encrypting, fraction: -1).fraction, 0)
        XCTAssertEqual(OperationProgress(.encrypting, fraction: 2).fraction, 1)
        XCTAssertEqual(OperationProgress(.encrypting, fraction: .nan).fraction, 0)
        XCTAssertNil(OperationProgress(.derivingKey).fraction)
    }

}
