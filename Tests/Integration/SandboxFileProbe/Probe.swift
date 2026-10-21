import Darwin
import Foundation
import HycryptCore

@main
struct HycryptSandboxFileProbe {
    enum ProbeError: Error {
        case mismatchedFile
        case mismatchedDirectory
    }

    static func main() async {
        do {
            try await run()
            print("Sandbox file probe passed: signed sandbox file and directory round trips.")
        } catch {
            fputs("sandbox file probe failed: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func run() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hycrypt-sandbox-file-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let password = try SecretBytes(utf8: "sandbox-file-probe-password-2026")
        let service = HycryptService()

        let file = root.appendingPathComponent("source.txt")
        let fileBytes = Data("sandbox file probe\n".utf8)
        try fileBytes.write(to: file)
        let encryptedFile = root.appendingPathComponent("source.txt.hycrypt")
        _ = try await service.process(
            .init(operation: .encrypt, source: file, destination: encryptedFile, password: password))
        let restoredFile = root.appendingPathComponent("restored.txt")
        _ = try await service.process(
            .init(operation: .decrypt, source: encryptedFile, destination: restoredFile, password: password))
        guard try Data(contentsOf: restoredFile) == fileBytes else { throw ProbeError.mismatchedFile }

        let folder = root.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let nestedBytes = Data("nested sandbox file\n".utf8)
        try nestedBytes.write(to: folder.appendingPathComponent("nested.txt"))
        let encryptedFolder = root.appendingPathComponent("folder.hycrypt")
        _ = try await service.process(
            .init(operation: .encrypt, source: folder, destination: encryptedFolder, password: password))
        let restoredFolder = root.appendingPathComponent("folder-restored", isDirectory: true)
        _ = try await service.process(
            .init(operation: .decrypt, source: encryptedFolder, destination: restoredFolder, password: password))
        let restoredNested = restoredFolder.appendingPathComponent("nested.txt")
        guard try Data(contentsOf: restoredNested) == nestedBytes else {
            throw ProbeError.mismatchedDirectory
        }
    }
}
