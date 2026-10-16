import CryptoKit
import Foundation
import Security

/// English BIP39 encoding and validation. No seed derivation, network, or persistent storage.
public enum BIP39 {
    public static let wordCount = 24
    public static let maximumWordLength = 8
    private static let wordList = Result { try WordList(text: BIP39English.text) }

    public enum Failure: LocalizedError {
        case wordListUnavailable, invalidEntropy, invalidWordCount, unknownWord, invalidChecksum

        public var errorDescription: String? {
            switch self {
            case .wordListUnavailable: "BIP39 词表校验失败。"
            case .invalidEntropy: "助记词生成失败。"
            case .invalidWordCount: "请输入 24 个单词。"
            case .unknownWord: "存在不属于 BIP39 英文词表的单词。"
            case .invalidChecksum: "助记词校验和不正确。"
            }
        }
    }

    struct WordList: Sendable {
        let words: [String]
        let indices: [String: Int]

        init(text: String) throws {
            let digest = SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
            guard digest == BIP39English.sha256 else { throw Failure.wordListUnavailable }
            let words = text.split(separator: "\n").map(String.init)
            guard words.count == 2_048, Set(words).count == 2_048, words == words.sorted() else {
                throw Failure.wordListUnavailable
            }
            self.words = words
            indices = Dictionary(uniqueKeysWithValues: words.enumerated().map { ($0.element, $0.offset) })
        }
    }

    public static func contains(_ word: String) -> Bool {
        (try? wordList.get().indices[word]) != nil
    }

    /// O(log n + limit), bounded independently of caller input. No fuzzy correction.
    public static func suggestions(for prefix: String, limit: Int = 8) -> [String] {
        guard !prefix.isEmpty, prefix.utf8.count <= maximumWordLength, limit > 0,
            prefix.utf8.allSatisfy({ (97...122).contains($0) }), let list = try? wordList.get()
        else { return [] }
        var low = 0
        var high = list.words.count
        while low < high {
            let middle = (low + high) / 2
            if list.words[middle] < prefix { low = middle + 1 } else { high = middle }
        }
        var result: [String] = []
        for index in low..<min(low + min(limit, 8), list.words.count) {
            guard list.words[index].hasPrefix(prefix) else { break }
            result.append(list.words[index])
        }
        return result
    }

    public static func validate(_ phrase: String, requiredWordCount: Int? = nil) throws {
        guard phrase.utf8.count <= 4_096 else { throw Failure.invalidWordCount }
        let words = phrase.split(whereSeparator: \.isWhitespace).map(String.init)
        try validate(words: words, requiredWordCount: requiredWordCount)
    }

    /// Validates a draft without allocating a joined plaintext phrase.
    public static func validate(words: [String], requiredWordCount: Int? = nil) throws {
        guard [12, 15, 18, 21, 24].contains(words.count),
            requiredWordCount == nil || words.count == requiredWordCount
        else { throw Failure.invalidWordCount }
        let list = try wordList.get()
        let entropyBits = words.count * 11 * 32 / 33
        let checksumBits = entropyBits / 32
        var entropy = Data(count: entropyBits / 8)
        defer { SecretMemory.wipe(&entropy) }
        var checksum: UInt8 = 0
        for (position, word) in words.enumerated() {
            guard word.utf8.count <= maximumWordLength, let index = list.indices[word] else {
                throw Failure.unknownWord
            }
            for bit in 0..<11 {
                let value = UInt8((index >> (10 - bit)) & 1)
                let offset = position * 11 + bit
                if offset < entropyBits {
                    entropy[offset / 8] |= value << (7 - offset % 8)
                } else {
                    checksum = (checksum << 1) | value
                }
            }
        }
        let expected = SHA256.hash(data: entropy).withUnsafeBytes { $0[0] } >> (8 - checksumBits)
        guard checksum == expected else { throw Failure.invalidChecksum }
    }

    /// Internal deterministic encoder used by published vectors; callers own/wipe entropy and output.
    static func mnemonicBytes(entropy: Data) throws -> Data {
        guard [16, 20, 24, 28, 32].contains(entropy.count) else { throw Failure.invalidEntropy }
        let list = try wordList.get()
        let entropyBits = entropy.count * 8
        let checksumBits = entropyBits / 32
        let checksum = SHA256.hash(data: entropy).withUnsafeBytes { $0[0] }
        var output = Data()
        output.reserveCapacity(216)
        for start in stride(from: 0, to: entropyBits + checksumBits, by: 11) {
            var index = 0
            for offset in start..<start + 11 {
                let bit =
                    offset < entropyBits
                    ? (entropy[offset / 8] >> (7 - offset % 8)) & 1
                    : (checksum >> (7 - (offset - entropyBits))) & 1
                index = (index << 1) | Int(bit)
            }
            if !output.isEmpty { output.append(32) }
            output.append(contentsOf: list.words[index].utf8)
        }
        return output
    }

    /// Explicit plaintext export for a user-confirmed, in-memory backup workflow.
    /// Returned Strings cannot be reliably wiped; callers must minimize their lifetime.
    public static func generateWords() throws -> [String] {
        try generateWords(random: systemRandom)
    }

    static func generateWords(random: (UnsafeMutableRawBufferPointer) throws -> Void) throws -> [String] {
        var entropy = Data(count: 32)
        defer { SecretMemory.wipe(&entropy) }
        try entropy.withUnsafeMutableBytes { try random($0) }
        var bytes = try mnemonicBytes(entropy: entropy)
        defer { SecretMemory.wipe(&bytes) }
        return bytes.split(separator: 32).map { String(decoding: $0, as: UTF8.self) }
    }

    static func systemRandom(_ buffer: UnsafeMutableRawBufferPointer) throws {
        guard buffer.count == 32, let base = buffer.baseAddress else { throw Failure.invalidEntropy }
        let status = SecRandomCopyBytes(kSecRandomDefault, buffer.count, base)
        guard status == errSecSuccess else { throw HycryptError.cryptoFailure(status) }
    }
}
