import Foundation

/// Shared nonempty-password validation; strength is advisory in the UI.
public enum SecretPolicy {
    public static func preparedPassword(_ password: String, operation: CryptOperation) -> String {
        operation == .encrypt ? password.trimmingCharacters(in: .whitespacesAndNewlines) : password
    }

    public static func validatePassword(_ password: String, operation: CryptOperation) throws {
        let value = preparedPassword(password, operation: operation)
        guard !value.isEmpty else { throw HycryptError.emptyPassword }
        if operation == .encrypt && value.contains(where: { $0.isWhitespace }) {
            throw HycryptError.passwordWhitespace
        }
    }

    static func validatePassword(_ password: SecretBytes, operation: CryptOperation) throws {
        try password.withUnsafeBytes { buffer in
            guard !buffer.isEmpty else { throw HycryptError.emptyPassword }
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
