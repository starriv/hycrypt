import CryptoKit
import Foundation

/// V2: authenticated header + ordered AES-GCM records + authenticated empty terminator.
/// Each record has a bounded size, so neither encryption nor decryption loads the whole file.
enum FileCipher {
    enum PayloadKind { case file, directory }

    static let magic = Data("HYCRYPT2".utf8)
    static let chunkSize = 1_048_576
    static let headerSize = 25

    static func encrypt(
        source: URL, destination: URL, password: SecretBytes, directory: Bool,
        progress: ProgressHandler
    ) throws {
        try SecretPolicy.validatePassword(password, operation: .encrypt)
        let salt = try KeyDerivation.randomSalt()
        let header = magic + salt + Data([directory ? 1 : 0])
        progress(.init(.derivingKey))
        let key = try KeyDerivation.derive(password: password, salt: salt)
        let input = try FileIO.openInput(source)
        defer { try? input.close() }
        let before = try FileIO.Snapshot(input)
        let output = try FileIO.createOutput(destination)
        defer { try? output.close() }
        try output.write(contentsOf: header)
        let total = before.size
        var index: UInt64 = 0
        var processed: UInt64 = 0
        var content = SHA256()
        while true {
            try Task.checkCancellation()
            var plaintext = try input.read(upToCount: chunkSize) ?? Data()
            defer { SecretMemory.wipe(&plaintext) }
            let length = encode(UInt32(plaintext.count))
            let sequence = encode(index)
            let nonce = try AES.GCM.Nonce(data: Data(repeating: 0, count: 4) + sequence)
            let box = try AES.GCM.seal(
                plaintext, using: key, nonce: nonce,
                authenticating: header + sequence + length)
            try output.write(contentsOf: length + box.ciphertext + box.tag)
            if plaintext.isEmpty { break }
            content.update(data: plaintext)
            processed += UInt64(plaintext.count)
            // Never emit records beyond the length observed at open; growth is reported below.
            guard processed <= total else { throw HycryptError.sourceChanged }
            progress(.init(.encrypting, fraction: Double(processed) / Double(max(total, 1))))
            index += 1
        }
        // Metadata alone misses a same-size rewrite that restores mtime. Re-read and compare.
        guard processed == total, try FileIO.Snapshot(input) == before,
            try FileIO.digest(input, count: total) == content.finalize(),
            try FileIO.Snapshot(input) == before
        else { throw HycryptError.sourceChanged }
        try output.synchronize()
    }

    static func decrypt(
        source: URL, destination: URL, password: SecretBytes,
        progress: ProgressHandler
    ) throws -> PayloadKind {
        let input = try FileIO.openInput(source)
        defer { try? input.close() }
        let prefix = try input.read(upToCount: magic.count) ?? Data()
        try input.seek(toOffset: 0)
        guard prefix == magic else { throw HycryptError.invalidFormat }
        let header = try FileIO.readExactly(input, count: headerSize)
        guard header.last == 0 || header.last == 1 else { throw HycryptError.invalidFormat }
        progress(.init(.derivingKey))
        let key = try KeyDerivation.derive(password: password, salt: header.subdata(in: 8..<24))
        let output = try FileIO.createOutput(destination)
        defer { try? output.close() }
        let total = try input.seekToEnd()
        try input.seek(toOffset: UInt64(headerSize))
        var index: UInt64 = 0
        while true {
            try Task.checkCancellation()
            let lengthBytes = try FileIO.readExactly(input, count: 4)
            let count = lengthBytes.reduce(0) { ($0 << 8) | Int($1) }
            guard count <= chunkSize else { throw HycryptError.invalidFormat }
            let ciphertext = try FileIO.readExactly(input, count: count)
            let tag = try FileIO.readExactly(input, count: 16)
            let sequence = encode(index)
            let nonce = try AES.GCM.Nonce(data: Data(repeating: 0, count: 4) + sequence)
            let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            var plaintext: Data
            do {
                plaintext = try AES.GCM.open(box, using: key, authenticating: header + sequence + lengthBytes)
            } catch { throw HycryptError.authenticationFailed }
            defer { SecretMemory.wipe(&plaintext) }
            if count == 0 {
                guard (try input.read(upToCount: 1) ?? Data()).isEmpty else { throw HycryptError.invalidFormat }
                break
            }
            try output.write(contentsOf: plaintext)
            progress(.init(.decrypting, fraction: Double(try input.offset()) / Double(max(total, 1))))
            index += 1
        }
        try output.synchronize()
        return header.last == 1 ? .directory : .file
    }

    /// Unauthenticated hint for choosing a scratch location. Decryption still authenticates the header.
    static func declaredKind(of source: URL) throws -> PayloadKind {
        let input = try FileIO.openInput(source)
        defer { try? input.close() }
        let header = try FileIO.readExactly(input, count: headerSize)
        guard header.prefix(magic.count) == magic, header.last == 0 || header.last == 1 else {
            throw HycryptError.invalidFormat
        }
        return header.last == 1 ? .directory : .file
    }

    static func encode<T: FixedWidthInteger>(_ value: T) -> Data {
        var bigEndian = value.bigEndian
        return withUnsafeBytes(of: &bigEndian) { Data($0) }
    }
}
