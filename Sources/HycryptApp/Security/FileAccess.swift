import Foundation
import Security

/// A balanced lease survives selection changes until the operation releases it.
final class SecurityScopedAccess: @unchecked Sendable {
    let url: URL
    let started: Bool

    init(_ url: URL) {
        self.url = url
        started = url.startAccessingSecurityScopedResource()
    }

    deinit {
        if started { url.stopAccessingSecurityScopedResource() }
    }
}

enum ApplicationSandbox {
    enum State: Equatable {
        case sandboxed
        case notSandboxed
        /// Signing information could not be read; treat this like a sandboxed app and
        /// require explicit output authorization rather than failing open.
        case unknown
    }

    static let state: State = {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return .unknown }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else {
            return .unknown
        }
        var information: CFDictionary?
        guard
            SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information)
                == errSecSuccess,
            let attributes = information as? [String: Any]
        else { return .unknown }
        // An unsigned process can have valid signing information but no entitlements.
        guard let entitlements = attributes[kSecCodeInfoEntitlementsDict as String] as? [String: Any] else {
            return .notSandboxed
        }
        return entitlements["com.apple.security.app-sandbox"] as? Bool == true ? .sandboxed : .notSandboxed
    }()

    static var isEnabled: Bool { state == .sandboxed }
    static var authorizationRequired: Bool { authorizationRequired(for: state) }

    static func authorizationRequired(for state: State) -> Bool {
        state != .notSandboxed
    }
}
