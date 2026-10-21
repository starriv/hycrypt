import Foundation

/// Shared nonempty-password validation; strength is advisory in the UI.
public enum SecretPolicy {
    /// UI and Core encryption policy. Decryption intentionally accepts longer/legacy passwords.
    public static let maximumPasswordBytes = 4_096

    public static func preparedPassword(_ password: String, operation: CryptOperation) -> String {
        operation == .encrypt ? password.trimmingCharacters(in: .whitespacesAndNewlines) : password
    }

    public static func validatePassword(_ password: String, operation: CryptOperation) throws {
        let value = preparedPassword(password, operation: operation)
        guard !value.isEmpty else { throw HycryptError.emptyPassword }
        if operation == .encrypt {
            guard value.utf8.count <= maximumPasswordBytes else { throw HycryptError.passwordTooLong }
            guard !value.contains(where: { $0.isWhitespace }) else { throw HycryptError.passwordWhitespace }
        }
    }

    static func validatePassword(_ password: SecretBytes, operation: CryptOperation) throws {
        try password.withUnsafeBytes { buffer in
            guard !buffer.isEmpty else { throw HycryptError.emptyPassword }
            if operation == .encrypt {
                guard buffer.count <= maximumPasswordBytes else { throw HycryptError.passwordTooLong }
                let asciiWhitespace: Set<UInt8> = [0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20]
                guard !buffer.contains(where: { asciiWhitespace.contains($0) }) else {
                    throw HycryptError.passwordWhitespace
                }
                if let text = String(bytes: buffer, encoding: .utf8),
                    text.contains(where: { $0.isWhitespace })
                {
                    throw HycryptError.passwordWhitespace
                }
            }
        }
    }

    /// Passwords are hashed as UTF-8 without normalization; non-ASCII input can encode
    /// differently on another keyboard, input method or platform.
    public static func mayDependOnInputMethod(_ password: String) -> Bool {
        password.unicodeScalars.contains { !$0.isASCII }
    }

    public enum TextKind: Sendable {
        case text, mnemonic

        public var maximumBytes: Int { self == .mnemonic ? 4_096 : TextCipher.maximumBytes }

        public func validate(_ text: String) throws {
            guard text.utf8.count <= maximumBytes else { throw TextCipher.TextError.tooLarge }
            if self == .mnemonic {
                try BIP39.validate(text, requiredWordCount: BIP39.wordCount)
            }
        }
    }
}
