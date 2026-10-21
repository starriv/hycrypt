import AppKit
import Foundation
import LocalAuthentication
import Observation

@MainActor
protocol LocalAuthenticating {
    func authenticate() async throws
    func cancel()
}

/// System authentication is a local access gate, not an extra encryption factor.
@MainActor
final class SystemAuthenticator: LocalAuthenticating {
    private struct Attempt {
        let id: UUID
        let context: LAContext
        let continuation: CheckedContinuation<Void, any Error>
    }

    private var attempt: Attempt?

    func authenticate() async throws {
        let id = UUID()
        let context = LAContext()
        // Use the system-managed prompt. An embedded LARight sheet can remain
        // blank and block its parent window while its remote UI is being created.
        context.localizedCancelTitle = "取消"
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                guard !Task.isCancelled else {
                    context.invalidate()
                    continuation.resume(throwing: CancellationError())
                    return
                }
                var error: NSError?
                guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                    context.invalidate()
                    continuation.resume(throwing: error ?? LAError(.notInteractive))
                    return
                }
                attempt = Attempt(id: id, context: context, continuation: continuation)
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "解锁 Hycrypt") {
                    [weak self] success, error in
                    let failure = success ? nil : (error as NSError? ?? LAError(.authenticationFailed) as NSError)
                    Task { @MainActor [weak self] in
                        self?.complete(id: id, error: failure)
                    }
                }
            }
            try Task.checkCancellation()
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel(id: id) }
        }
    }

    func cancel() {
        guard let id = attempt?.id else { return }
        cancel(id: id)
    }

    private func complete(id: UUID, error: NSError?) {
        guard let attempt, attempt.id == id else { return }
        self.attempt = nil
        attempt.context.invalidate()
        if let error {
            attempt.continuation.resume(throwing: error)
        } else {
            attempt.continuation.resume()
        }
    }

    private func cancel(id: UUID) {
        guard let attempt, attempt.id == id else { return }
        self.attempt = nil
        attempt.context.invalidate()
        attempt.continuation.resume(throwing: CancellationError())
    }

}

@MainActor
@Observable
final class LocalAuthorization {
    private(set) var isUnlocked = false
    private(set) var isAuthenticating = false
    private(set) var errorMessage: String?
    @ObservationIgnored private let authenticator: any LocalAuthenticating
    @ObservationIgnored private var attempt: UUID?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var automaticPromptArmed = true

    init(authenticator: any LocalAuthenticating = SystemAuthenticator(), startsUnlocked: Bool = false) {
        self.authenticator = authenticator
        isUnlocked = startsUnlocked
        automaticPromptArmed = !startsUnlocked
    }

    @discardableResult
    func unlock() -> Task<Void, Never>? {
        guard !isUnlocked, !isAuthenticating else { return nil }
        automaticPromptArmed = false
        let id = UUID()
        attempt = id
        isAuthenticating = true
        errorMessage = nil
        let authenticator = authenticator
        let task = Task { [weak self] in
            do {
                try await authenticator.authenticate()
                try Task.checkCancellation()
                guard let self, attempt == id else { return }
                isUnlocked = true
            } catch {
                guard let self, attempt == id else { return }
                errorMessage = Self.message(for: error)
            }
            guard let self, attempt == id else { return }
            isAuthenticating = false
            attempt = nil
            self.task = nil
        }
        self.task = task
        return task
    }

    /// Only one automatic system prompt is shown per lock. A cancelled prompt leaves
    /// the visible retry button available instead of reopening on sheet reactivation.
    @discardableResult
    func unlockAutomatically() -> Task<Void, Never>? {
        guard automaticPromptArmed else { return nil }
        return unlock()
    }

    /// Cancels an in-flight system authentication prompt. The user can retry explicitly;
    /// no automatic prompt is armed by this action.
    func cancelAuthentication() {
        guard isAuthenticating else { return }
        attempt = nil
        task?.cancel()
        task = nil
        authenticator.cancel()
        isAuthenticating = false
        errorMessage = "认证已取消。"
    }

    /// Fixed copy per failure class; framework descriptions and user data are never echoed.
    static func message(for error: any Error) -> String {
        switch (error as? LAError)?.code {
        case .passcodeNotSet:
            "此 Mac 未设置登录密码，无法进行系统认证。请先在“系统设置 > 用户与群组”中设置登录密码。"
        case .biometryLockout:
            "触控 ID 已被锁定，请使用登录密码认证。"
        case .userCancel, .systemCancel, .appCancel:
            "认证已取消。"
        case .notInteractive:
            "当前无法显示系统认证窗口，请稍后重试。"
        default:
            "未通过系统认证，请重试。"
        }
    }

    func lock() {
        attempt = nil
        task?.cancel()
        task = nil
        authenticator.cancel()
        isUnlocked = false
        isAuthenticating = false
        errorMessage = nil
        automaticPromptArmed = true
    }
}
