import CryptoKit
import Darwin
import Foundation
import ZIPFoundation

/// Only regular files and directories are accepted; links are never followed or restored.
enum DirectoryArchive {
    static let maximumEntries = 100_000
    static let maximumDepth = 256
    static let maximumPathBytes = 65_535
    static let maximumExpandedBytes: UInt64 = 100 * 1_024 * 1_024 * 1_024

    static func pack(source: URL, destination: URL, progress: ProgressHandler) throws {
        let source = source.resolvingSymlinksInPath()
        let rootName = source.lastPathComponent
        // Every later lookup is relative to a verified directory descriptor, so replacing an
        // ancestor with a symlink while packing cannot redirect reads outside the source.
        let rootFD = open(source.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard rootFD >= 0 else { throw HycryptError.invalidSource }
        defer { close(rootFD) }
        let archive = try Archive(url: destination, accessMode: .create)
        try withoutActuallyEscaping(progress) { progress in
            var walk = Walk(archive: archive, progress: progress)
            try walk.addDirectory(path: rootName + "/")
            try walk.visit(directory: rootFD, relative: [rootName])
        }
    }

    private struct Walk {
        let archive: Archive
        let progress: ProgressHandler
        var count = 0
        var bytes: UInt64 = 0

        init(archive: Archive, progress: @escaping ProgressHandler) {
            self.archive = archive
            self.progress = progress
        }

        mutating func visit(directory: Int32, relative: [String]) throws {
            guard relative.count <= DirectoryArchive.maximumDepth else {
                throw HycryptError.unsafeArchive
            }
            for name in try Self.names(in: directory) {
                try Task.checkCancellation()
                var info = stat()
                guard fstatat(directory, name, &info, AT_SYMLINK_NOFOLLOW) == 0 else {
                    throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
                }
                let kind = info.st_mode & S_IFMT
                guard kind == S_IFDIR || kind == S_IFREG else { throw HycryptError.invalidSource }
                count += 1
                bytes += kind == S_IFREG ? UInt64(max(info.st_size, 0)) : 0
                guard count < maximumEntries, bytes <= maximumExpandedBytes else { throw HycryptError.unsafeArchive }
                let components = relative + [name]
                let path = components.joined(separator: "/")
                let phase = OperationProgress.Phase.archiving(components.dropFirst().joined(separator: "/"))
                if kind == S_IFDIR {
                    progress(.init(phase))
                    let child = openat(directory, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                    guard child >= 0 else { throw HycryptError.invalidSource }
                    defer { close(child) }
                    var opened = stat()
                    guard fstat(child, &opened) == 0, opened.st_dev == info.st_dev, opened.st_ino == info.st_ino
                    else { throw HycryptError.sourceChanged }
                    try addDirectory(path: path + "/")
                    try visit(directory: child, relative: components)
                } else {
                    let input = try FileIO.openInput(at: directory, name, expected: info)
                    defer { try? input.close() }
                    let before = try FileIO.Snapshot(input)
                    progress(.init(phase))
                    try addFile(input, before: before, path: path)
                }
            }
        }

        func addDirectory(path: String) throws {
            let path = try archivePath(path)
            try archive.addEntry(with: path, type: .directory, uncompressedSize: Int64(0), provider: { _, _ in Data() })
        }

        private func addFile(_ input: FileHandle, before: FileIO.Snapshot, path: String) throws {
            let path = try archivePath(path)
            var content = SHA256()
            var hashed: UInt64 = 0
            // ZIPFoundation consumes provider chunks synchronously. Keep the previous chunk
            // alive only until the next request (or addEntry return), then wipe the local copy.
            // ZIPFoundation's own compression buffers remain outside this best effort.
            var previousChunk: Data?
            defer {
                if previousChunk != nil {
                    var chunk = previousChunk!
                    SecretMemory.wipe(&chunk)
                    previousChunk = nil
                }
            }
            do {
                try archive.addEntry(
                    with: path, type: .file, uncompressedSize: Int64(before.size),
                    compressionMethod: .deflate, bufferSize: FileIO.bufferSize
                ) { position, size in
                    try Task.checkCancellation()
                    if previousChunk != nil {
                        var chunk = previousChunk!
                        SecretMemory.wipe(&chunk)
                        previousChunk = nil
                    }
                    guard position >= 0, UInt64(position) == hashed else { throw HycryptError.sourceChanged }
                    try input.seek(toOffset: UInt64(position))
                    let data = try FileIO.readExactly(input, count: size)
                    content.update(data: data)
                    hashed += UInt64(data.count)
                    previousChunk = data
                    return data
                }
            } catch HycryptError.invalidFormat {
                throw HycryptError.sourceChanged
            }
            guard hashed == before.size, try FileIO.Snapshot(input) == before,
                try FileIO.digest(input, count: before.size) == content.finalize()
            else { throw HycryptError.sourceChanged }
        }

        private func archivePath(_ relative: String) throws -> String {
            _ = try safeComponents(relative)
            return relative
        }

        /// Sorted for deterministic archives; "." and ".." are never returned.
        private static func names(in directory: Int32) throws -> [String] {
            let duplicate = dup(directory)
            guard duplicate >= 0, let stream = fdopendir(duplicate) else {
                if duplicate >= 0 { close(duplicate) }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            defer { closedir(stream) }
            var names: [String] = []
            while true {
                errno = 0
                guard let entry = readdir(stream) else {
                    if errno != 0 { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
                    break
                }
                let name = withUnsafeBytes(of: entry.pointee.d_name) { raw in
                    DirectoryArchive.decodeName(raw.prefix(Int(entry.pointee.d_namlen)))
                }
                guard let name else { throw HycryptError.invalidSource }
                if name != "." && name != ".." {
                    names.append(name)
                    if names.count >= DirectoryArchive.maximumEntries {
                        throw HycryptError.unsafeArchive
                    }
                }
            }
            return names.sorted()
        }
    }

    static func unpack(source: URL, into destination: URL, progress: ProgressHandler) throws -> URL {
        let expectedEntries = try ZIPValidation.entryCount(at: source)
        let archive = try Archive(url: source, accessMode: .read)
        let manager = FileManager.default
        var paths = Set<String>()
        var roots = Set<String>()
        var expanded: UInt64 = 0
        var entries = 0
        // Validate the complete central directory before writing any archive contents.
        for entry in archive {
            try Task.checkCancellation()
            entries += 1
            let components = try safeComponents(entry.path)
            let normalized = components.joined(separator: "/")
            guard paths.insert(normalized).inserted,
                entry.type == .file || entry.type == .directory,
                entries <= maximumEntries,
                entry.uncompressedSize <= maximumExpandedBytes - expanded
            else { throw HycryptError.unsafeArchive }
            expanded += entry.uncompressedSize
            roots.insert(components[0])
        }
        guard entries > 0, entries == expectedEntries, roots.count == 1 else { throw HycryptError.unsafeArchive }
        let available = try? destination.deletingLastPathComponent().resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        ).volumeAvailableCapacityForImportantUsage
        if let available, available > 0,
            UInt64(available) < expanded + 256 * 1_024 * 1_024
        {
            throw HycryptError.unsafeArchive
        }
        try manager.createDirectory(
            at: destination, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700])
        var restored: UInt64 = 0
        for entry in archive {
            try Task.checkCancellation()
            let components = try safeComponents(entry.path)
            let target = components.reduce(destination) { $0.appendingPathComponent($1) }
            progress(.init(.restoring(entry.path), fraction: Double(restored) / Double(max(expanded, 1))))
            if entry.type == .directory {
                try manager.createDirectory(
                    at: target, withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700])
            } else {
                try manager.createDirectory(
                    at: target.deletingLastPathComponent(), withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700])
                let output = try FileIO.createOutput(target)
                defer { try? output.close() }
                var fileBytes: UInt64 = 0
                let checksum = try archive.extract(entry, bufferSize: FileIO.bufferSize) { data in
                    try Task.checkCancellation()
                    guard UInt64(data.count) <= entry.uncompressedSize - fileBytes else {
                        throw HycryptError.unsafeArchive
                    }
                    var chunk = data
                    defer { SecretMemory.wipe(&chunk) }
                    fileBytes += UInt64(chunk.count)
                    try output.write(contentsOf: chunk)
                }
                guard fileBytes == entry.uncompressedSize, checksum == entry.checksum else {
                    throw HycryptError.unsafeArchive
                }
                restored += fileBytes
                try output.synchronize()
            }
        }
        let root = destination.appendingPathComponent(roots.first!)
        guard try root.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            throw HycryptError.unsafeArchive
        }
        return root
    }

    /// Strict file-name decoding. Darwin file systems may contain arbitrary non-NUL bytes
    /// (for example on mounted foreign volumes); lossy U+FFFD replacement could address a
    /// different file, so fail closed instead.
    static func decodeName<Bytes: Sequence>(_ bytes: Bytes) -> String? where Bytes.Element == UInt8 {
        String(bytes: bytes, encoding: .utf8)
    }

    static func safeComponents(_ path: String) throws -> [String] {
        guard path.utf8.count <= maximumPathBytes,
            !path.hasPrefix("/"), !path.contains("\\"), !path.contains("\0")
        else { throw HycryptError.unsafeArchive }
        var parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        if parts.last == "" { parts.removeLast() }
        guard !parts.isEmpty, parts.count <= maximumDepth,
            parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains(":") })
        else {
            throw HycryptError.unsafeArchive
        }
        return parts
    }
}
