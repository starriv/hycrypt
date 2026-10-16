import CArgon2
import CArgon2Shim
import CryptoKit
import Foundation
import Security

// Fixed on-disk format parameters; changes require a new format version.
enum KeyDerivation {
    static func derive(password: SecretBytes, salt: Data) throws -> SymmetricKey {
        // Argon2 with ARGON2_FLAG_CLEAR_PASSWORD zeroes the password buffer after absorption.
        // Copy to a temporary so the caller's SecretBytes remains intact for reuse (e.g. decrypt after encrypt).
        let passwordCopy = try password.withUnsafeBytes { buffer in
            let copy = try SecretBytes(count: buffer.count)
            copy.withUnsafeMutableBytes { dest in dest.copyMemory(from: buffer) }
            return copy
        }
        let keyBytes = try SecretBytes(count: 32)
        let status = passwordCopy.withUnsafeBytes { password in
            keyBytes.withUnsafeMutableBytes { output in
                salt.withUnsafeBytes { saltBytes in
                    hycrypt_argon2id_raw(
                        5, 262_144, 6, password.baseAddress, password.count,
                        saltBytes.baseAddress, saltBytes.count, output.baseAddress, output.count)
                }
            }
        }
        guard status == ARGON2_OK.rawValue else { throw HycryptError.cryptoFailure(status) }
        try Task.checkCancellation()
        var copy = Data(count: 32)
        defer { SecretMemory.wipe(&copy) }
        copy.withUnsafeMutableBytes { destination in
            keyBytes.withUnsafeBytes { source in destination.copyMemory(from: source) }
        }
        return SymmetricKey(data: copy)
    }

    static func randomSalt() throws -> Data {
        var bytes = Data(count: 16)
        let result = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        guard result == errSecSuccess else { throw HycryptError.cryptoFailure(result) }
        return bytes
    }
}
