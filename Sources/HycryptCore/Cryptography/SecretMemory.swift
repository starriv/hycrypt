import Darwin
import Foundation

/// Wipes owned buffers; this cannot erase copies made by Swift or system frameworks.
enum SecretMemory {
    static func wipe(_ bytes: inout Data) {
        bytes.withUnsafeMutableBytes { buffer in
            guard let address = buffer.baseAddress, !buffer.isEmpty else { return }
            _ = memset_s(address, buffer.count, 0, buffer.count)
        }
    }

    static func wipe(_ bytes: inout [UInt8]) {
        bytes.withUnsafeMutableBytes { buffer in
            guard let address = buffer.baseAddress, !buffer.isEmpty else { return }
            _ = memset_s(address, buffer.count, 0, buffer.count)
        }
    }
}
