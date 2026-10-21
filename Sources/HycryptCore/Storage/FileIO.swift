import CryptoKit
import Darwin
import Foundation

/// Shared bounded I/O; archive code does not depend on the cipher implementation.
enum FileIO {
    static let bufferSize = 1_048_576

    static func openInput(_ url: URL) throws -> FileHandle {
        try openInput(at: AT_FDCWD, url.path)
    }

    /// Opens a regular file relative to an already-verified directory descriptor.
    /// When `expected` is given, the opened file must be the same inode that was inspected.
    static func openInput(at directory: Int32, _ name: String, expected: stat? = nil) throws -> FileHandle {
        let fd = openat(directory, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        var info = stat()
        guard fstat(fd, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
            expected.map({ $0.st_dev == info.st_dev && $0.st_ino == info.st_ino }) ?? true
        else {
            close(fd)
            throw HycryptError.invalidSource
        }
        return FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    }

    static func createOutput(_ url: URL) throws -> FileHandle {
        // Staging paths are private and unique. Never truncate an existing file.
        let fd = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        return FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    }

    /// Identity, length and content timestamp of an open input. Comparing snapshots taken
    /// before and after reading detects a source that changed while it was being encrypted.
    struct Snapshot: Equatable {
        let device: Int32
        let inode: UInt64
        let size: UInt64
        let modifiedSeconds: Int
        let modifiedNanoseconds: Int

        init(_ handle: FileHandle) throws {
            var info = stat()
            guard fstat(handle.fileDescriptor, &info) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            device = info.st_dev
            inode = info.st_ino
            size = UInt64(max(info.st_size, 0))
            modifiedSeconds = info.st_mtimespec.tv_sec
            modifiedNanoseconds = info.st_mtimespec.tv_nsec
        }
    }

    /// SHA-256 of the first `count` bytes. Used to detect a same-size rewrite that restores mtime.
    static func digest(_ handle: FileHandle, count: UInt64) throws -> SHA256.Digest {
        try Task.checkCancellation()
        try handle.seek(toOffset: 0)
        var hasher = SHA256()
        var remaining = count
        while remaining > 0 {
            try Task.checkCancellation()
            let expected = Int(min(UInt64(bufferSize), remaining))
            var chunk = try handle.read(upToCount: expected) ?? Data()
            defer { SecretMemory.wipe(&chunk) }
            guard chunk.count == expected else { throw HycryptError.sourceChanged }
            hasher.update(data: chunk)
            remaining -= UInt64(expected)
        }
        return hasher.finalize()
    }

    static func copy(_ source: URL, to destination: URL) throws {
        let input = try openInput(source)
        defer { try? input.close() }
        let output = try createOutput(destination)
        defer { try? output.close() }
        while true {
            try Task.checkCancellation()
            var chunk = try input.read(upToCount: bufferSize) ?? Data()
            defer { SecretMemory.wipe(&chunk) }
            if chunk.isEmpty { break }
            try output.write(contentsOf: chunk)
        }
        try output.synchronize()
    }

    static func readExactly(_ input: FileHandle, count: Int) throws -> Data {
        var result = Data()
        while result.count < count {
            let part = try input.read(upToCount: count - result.count) ?? Data()
            guard !part.isEmpty else { throw HycryptError.invalidFormat }
            result.append(part)
        }
        return result
    }

}
