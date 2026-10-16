import Darwin
import Foundation

/// A page-aligned secret buffer locked in physical memory. Deallocation wipes the whole allocation.
/// This does not cover Swift strings or copies made by CryptoKit.
public final class SecretBytes: @unchecked Sendable {
    private let base: UnsafeMutableRawPointer
    private let count: Int
    private let allocated: Int

    public init(count: Int) throws {
        let page = max(Int(sysconf(_SC_PAGESIZE)), 4_096)
        // A password or key, not the Argon2 workspace. Refuse to wire an unbounded buffer.
        guard count > 0, count <= page * 1_024 else { throw HycryptError.memoryLockUnavailable }
        let allocated = ((count + page - 1) / page) * page
        guard let memory = mmap(nil, allocated, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0),
            memory != MAP_FAILED
        else { throw HycryptError.memoryLockUnavailable }
        if mlock(memory, allocated) != 0 {
            munmap(memory, allocated)
            throw HycryptError.memoryLockUnavailable
        }
        self.base = memory
        self.count = count
        self.allocated = allocated
    }

    public convenience init(utf8 string: String) throws {
        try self.init(count: string.utf8.count)
        var offset = 0
        withUnsafeMutableBytes { buffer in
            for byte in string.utf8 {
                buffer[offset] = byte
                offset += 1
            }
        }
    }

    public func withUnsafeBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> T) rethrows -> T {
        try body(UnsafeRawBufferPointer(start: base, count: count))
    }

    public func withUnsafeMutableBytes<T>(_ body: (UnsafeMutableRawBufferPointer) throws -> T) rethrows -> T {
        try body(UnsafeMutableRawBufferPointer(start: base, count: count))
    }

    deinit {
        _ = memset_s(base, allocated, 0, allocated)
        munlock(base, allocated)
        munmap(base, allocated)
    }
}
