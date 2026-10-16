import CryptoKit
import Foundation

/// In-memory text transport for the V2 file payload, encoded as Base64.
public enum TextCipher {
    public static let maximumBytes = 1_048_576
    public static let maximumEncodedBytes = 1_398_200

    public static func process(
        _ text: String, password: SecretBytes, operation: CryptOperation, kind: SecretPolicy.TextKind = .text
    ) async throws -> String {
        let worker = Task.detached(priority: .userInitiated) {
            try await CryptoExecutor.shared.run {
                try Task.checkCancellation()
                try SecretPolicy.validatePassword(password, operation: operation)
                if operation == .encrypt { try kind.validate(text) }
                let result =
                    try operation == .encrypt
                    ? encrypt(text, password: password) : decrypt(text, password: password, kind: kind)
                try Task.checkCancellation()
                return result
            }
        }
        return try await withTaskCancellationHandler {
            if Task.isCancelled { worker.cancel() }
            return try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private static func encrypt(_ text: String, password: SecretBytes) throws -> String {
        guard text.utf8.count <= maximumBytes else { throw TextError.tooLarge }
        var bytes = Data(text.utf8)
        defer { SecretMemory.wipe(&bytes) }
        return try encrypt(bytes: bytes, password: password)
    }

    /// Returns only ciphertext; generated mnemonic bytes never cross into application/UI state.
    public static func generateMnemonic(password: SecretBytes) async throws -> String {
        let worker = Task.detached(priority: .userInitiated) {
            try await CryptoExecutor.shared.run { try encryptNewMnemonic(password: password) }
        }
        return try await withTaskCancellationHandler {
            if Task.isCancelled { worker.cancel() }
            return try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    static func encryptNewMnemonic(
        password: SecretBytes, random: (UnsafeMutableRawBufferPointer) throws -> Void = BIP39.systemRandom
    ) throws -> String {
        try Task.checkCancellation()
        try SecretPolicy.validatePassword(password, operation: .encrypt)
        var entropy = Data(count: 32)
        defer { SecretMemory.wipe(&entropy) }
        try entropy.withUnsafeMutableBytes { try random($0) }
        try Task.checkCancellation()
        var plaintext = try BIP39.mnemonicBytes(entropy: entropy)
        defer { SecretMemory.wipe(&plaintext) }
        let result = try encrypt(bytes: plaintext, password: password)
        try Task.checkCancellation()
        return result
    }

    private static func encrypt(bytes: Data, password: SecretBytes) throws -> String {
        let salt = try KeyDerivation.randomSalt()
        let header = FileCipher.magic + salt + Data([0])
        let key = try KeyDerivation.derive(password: password, salt: salt)
        var result = header
        let count = bytes.isEmpty ? 1 : 2
        for index in 0..<count {
            let plaintext = index == 0 ? bytes : Data()
            try Task.checkCancellation()
            let sequence = FileCipher.encode(UInt64(index))
            let length = FileCipher.encode(UInt32(plaintext.count))
            let nonce = try AES.GCM.Nonce(data: Data(repeating: 0, count: 4) + sequence)
            let box = try AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: header + sequence + length)
            result.append(length + box.ciphertext + box.tag)
        }
        return result.base64EncodedString()
    }

    private static func decrypt(_ text: String, password: SecretBytes, kind: SecretPolicy.TextKind) throws -> String {
        guard text.utf8.count <= maximumEncodedBytes else { throw TextError.tooLarge }
        let compact = text.filter { !$0.isWhitespace }
        guard let data = Data(base64Encoded: compact), data.count >= FileCipher.headerSize,
            data.prefix(8) == FileCipher.magic, data[24] == 0
        else { throw HycryptError.invalidFormat }
        let header = Data(data.prefix(FileCipher.headerSize))
        let key = try KeyDerivation.derive(password: password, salt: header.subdata(in: 8..<24))
        var offset = FileCipher.headerSize
        var index: UInt64 = 0
        var result = Data()
        defer { SecretMemory.wipe(&result) }
        while true {
            try Task.checkCancellation()
            guard data.count - offset >= 20 else { throw HycryptError.invalidFormat }
            let length = data.subdata(in: offset..<offset + 4)
            let count = length.reduce(0) { ($0 << 8) | Int($1) }
            offset += 4
            guard count <= kind.maximumBytes, count <= kind.maximumBytes - result.count,
                data.count - offset >= count + 16
            else { throw HycryptError.invalidFormat }
            let sequence = FileCipher.encode(index)
            let nonce = try AES.GCM.Nonce(data: Data(repeating: 0, count: 4) + sequence)
            let box = try AES.GCM.SealedBox(
                nonce: nonce, ciphertext: data.subdata(in: offset..<offset + count),
                tag: data.subdata(in: offset + count..<offset + count + 16))
            var plaintext: Data
            do {
                plaintext = try AES.GCM.open(box, using: key, authenticating: header + sequence + length)
            } catch { throw HycryptError.authenticationFailed }
            defer { SecretMemory.wipe(&plaintext) }
            offset += count + 16
            if count == 0 {
                guard offset == data.count else { throw HycryptError.invalidFormat }
                guard let text = String(data: result, encoding: .utf8) else { throw TextError.invalidText }
                try kind.validate(text)
                return text
            }
            result.append(plaintext)
            index += 1
        }
    }

    public enum TextError: LocalizedError {
        case tooLarge, invalidText

        public var errorDescription: String? {
            switch self {
            case .tooLarge: "输入过长。"
            case .invalidText: "解密内容不是有效的 UTF-8 文本，请使用文件模式。"
            }
        }
    }
}
