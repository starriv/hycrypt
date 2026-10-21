import Foundation
import HycryptCore
import LocalAuthentication
import Testing

@testable import HycryptApp

@MainActor
struct LocalAuthorizationTests {
    @Test func freshSessionSkipsAuthenticationButLaterLockRequiresIt() async throws {
        let authenticator = TestAuthenticator()
        let authorization = LocalAuthorization(authenticator: authenticator, startsUnlocked: true)
        let model = WorkspaceModel(processor: ControlledFileProcessor(), authorization: authorization)
        #expect(model.canAccessWindows)
        #expect(model.resume() == nil)
        #expect(!authorization.isAuthenticating)
        model.lock()
        #expect(!model.canAccessWindows)
        let task = try #require(model.resume())
        await authenticator.waitUntilStarted()
        authenticator.finish(success: true)
        await task.value
        #expect(model.canAccessWindows)
    }

    @Test func failureNeverUnlocksAndRetryCanSucceed() async throws {
        let authenticator = TestAuthenticator()
        let authorization = LocalAuthorization(authenticator: authenticator)
        let first = try #require(authorization.unlock())
        #expect(authorization.unlock() == nil)
        await authenticator.waitUntilStarted()
        authenticator.finish(success: false)
        await first.value
        #expect(!authorization.isUnlocked && !authorization.isAuthenticating)
        #expect(authorization.errorMessage != nil)
        let second = try #require(authorization.unlock())
        await authenticator.waitUntilStarted()
        authenticator.finish(success: true)
        await second.value
        #expect(authorization.isUnlocked && authorization.errorMessage == nil)
        authorization.lock()
        #expect(!authorization.isUnlocked)
    }

    @Test func automaticAuthenticationRunsOnceUntilUserRetriesOrSessionLocksAgain() async throws {
        let authenticator = TestAuthenticator()
        let authorization = LocalAuthorization(authenticator: authenticator)
        let first = try #require(authorization.unlockAutomatically())
        #expect(authorization.unlockAutomatically() == nil)
        await authenticator.waitUntilStarted()
        authenticator.finish(success: false, error: LAError(.userCancel))
        await first.value
        #expect(authorization.unlockAutomatically() == nil)

        let retry = try #require(authorization.unlock())
        await authenticator.waitUntilStarted()
        authenticator.finish(success: true)
        await retry.value
        authorization.lock()

        let nextSession = try #require(authorization.unlockAutomatically())
        await authenticator.waitUntilStarted()
        authenticator.finish(success: true)
        await nextSession.value
        #expect(authorization.isUnlocked)
    }

    @Test func missingLoginPasswordExplainsWhyUnlockIsUnavailable() async throws {
        let authenticator = TestAuthenticator()
        let authorization = LocalAuthorization(authenticator: authenticator)
        let task = try #require(authorization.unlock())
        await authenticator.waitUntilStarted()
        authenticator.finish(success: false, error: LAError(.passcodeNotSet))
        await task.value
        #expect(!authorization.isUnlocked)
        #expect(authorization.errorMessage == LocalAuthorization.message(for: LAError(.passcodeNotSet)))
        #expect(authorization.errorMessage != LocalAuthorization.message(for: CancellationError()))
    }

    @Test func documentOpenedWhileLockedWaitsForUnlockAndLockDiscardsIt() async throws {
        let authenticator = TestAuthenticator()
        let authorization = LocalAuthorization(authenticator: authenticator)
        let model = WorkspaceModel(processor: ControlledFileProcessor(), authorization: authorization)
        let document = URL(fileURLWithPath: "/tmp/synthetic.hycrypt")
        model.selectSource(document)
        #expect(model.form.source == nil && model.pendingSource == document)
        let task = try #require(authorization.unlock())
        await authenticator.waitUntilStarted()
        authenticator.finish(success: true)
        await task.value
        model.applyPendingSource()
        #expect(model.form.source?.url == document && model.pendingSource == nil)

        model.lock()
        model.selectSource(URL(fileURLWithPath: "/tmp/other.hycrypt"))
        #expect(model.pendingSource != nil)
        model.lock()
        #expect(model.pendingSource == nil)
        model.applyPendingSource()
        #expect(model.form.source?.url == document)
    }

    @Test func userCanCancelAuthentication() async throws {
        let authenticator = TestAuthenticator()
        let authorization = LocalAuthorization(authenticator: authenticator)
        let task = try #require(authorization.unlock())
        await authenticator.waitUntilStarted()
        authorization.cancelAuthentication()
        await task.value
        #expect(!authorization.isAuthenticating && !authorization.isUnlocked)
        #expect(authorization.errorMessage != nil)
        #expect(authenticator.cancellations == 1)
    }

    @Test func lockRejectsLateAuthenticationSuccess() async throws {
        let authenticator = TestAuthenticator()
        let authorization = LocalAuthorization(authenticator: authenticator)
        let task = try #require(authorization.unlock())
        await authenticator.waitUntilStarted()
        authorization.lock()
        authenticator.finish(success: true)
        await task.value
        #expect(!authorization.isUnlocked && !authorization.isAuthenticating)
        #expect(authenticator.cancellations == 1)
    }

    @Test func everyModeIsGatedBeforeProcessing() async throws {
        let authenticator = TestAuthenticator()
        let authorization = LocalAuthorization(authenticator: authenticator)
        let processor = ControlledFileProcessor()
        let model = WorkspaceModel(processor: processor, authorization: authorization)
        model.selectSource(URL(fileURLWithPath: "/tmp/test.txt"))
        model.form.password = "test-only-password-2026"
        model.form.confirmation = model.form.password
        #expect(model.start() == nil)
        model.text.input = "test-only-plaintext"
        model.text.password = "test-only-password-2026"
        model.text.confirmation = model.text.password
        #expect(model.text.start(.encrypt) == nil)
        model.text.generateMnemonic()
        #expect(!model.text.hasGeneratedMnemonic)
        #expect(await processor.requests.isEmpty)
        let task = try #require(authorization.unlock())
        await authenticator.waitUntilStarted()
        authenticator.finish(success: true)
        await task.value
        #expect(model.isAuthorized)
        model.inputKind = .mnemonic
        model.conceal()
        #expect(!model.isAuthorized)
        #expect(model.text.password.isEmpty && model.form.password.isEmpty)
        #expect(model.text.start(.encrypt) == nil)
    }

    @Test func authenticationSheetDoesNotCancelItselfOnDeactivation() async throws {
        let authenticator = TestAuthenticator()
        let authorization = LocalAuthorization(authenticator: authenticator)
        let model = WorkspaceModel(processor: ControlledFileProcessor(), authorization: authorization)
        let task = try #require(authorization.unlock())
        await authenticator.waitUntilStarted()
        model.conceal()
        #expect(authorization.isAuthenticating)
        authenticator.finish(success: true)
        await task.value
        model.resume()
        #expect(model.isAuthorized && !model.isObscured)
        model.lock()
        #expect(!model.isAuthorized)
    }

    @Test func resumeWhileLockedRequestsAuthentication() async throws {
        let authenticator = TestAuthenticator()
        let authorization = LocalAuthorization(authenticator: authenticator)
        let model = WorkspaceModel(processor: ControlledFileProcessor(), authorization: authorization)
        model.inputKind = .mnemonic
        let first = try #require(model.resume())
        #expect(authorization.isAuthenticating)
        await authenticator.waitUntilStarted()
        authenticator.finish(success: true)
        await first.value
        #expect(model.isAuthorized)
        model.conceal()
        #expect(model.isObscured && !model.isAuthorized)
        let second = try #require(model.resume())
        #expect(!model.isObscured && authorization.isAuthenticating)
        await authenticator.waitUntilStarted()
        authenticator.finish(success: true)
        await second.value
        #expect(model.isAuthorized && !model.isObscured)
    }

    @Test func productionWorkspaceStartsUnlockedWithoutAuthentication() {
        let model = WorkspaceModel(processor: ControlledFileProcessor())
        #expect(model.canAccessWindows)
        #expect(model.resume() == nil)
        #expect(model.authorization?.isAuthenticating == false)
        #expect(model.authorization != nil)
    }

    @Test func manualLockImmediatelyRequestsAuthenticationAndLocksAllWorkspaceAccess() async throws {
        let authenticator = TestAuthenticator()
        let authorization = LocalAuthorization(authenticator: authenticator)
        let model = WorkspaceModel(processor: ControlledFileProcessor(), authorization: authorization)
        let initial = try #require(authorization.unlock())
        await authenticator.waitUntilStarted()
        authenticator.finish(success: true)
        await initial.value
        #expect(model.canAccessWindows)

        let relock = try #require(model.lockAndRequestAuthentication())
        #expect(!model.canAccessWindows && authorization.isAuthenticating)
        await authenticator.waitUntilStarted()
        authenticator.finish(success: false, error: LAError(.userCancel))
        await relock.value
        #expect(!model.canAccessWindows && authorization.errorMessage != nil)
    }

    @Test func revokedSessionCannotRevealCompletedPlaintext() async {
        let authorized = TestAccessFlag()
        let text = TextWorkspace(isAuthorized: { authorized.value }, processor: { _, _, _, _ in "public test result" })
        text.input = "synthetic ciphertext"
        text.password = "old-password"
        await text.start(.decrypt)?.value
        authorized.value = false
        text.reveal()
        #expect(!text.isRevealed)
    }

    @Test func deactivationLocksTextModeAndDropsDecryptedPlaintext() async throws {
        let authenticator = TestAuthenticator()
        let authorization = LocalAuthorization(authenticator: authenticator, startsUnlocked: true)
        let model = WorkspaceModel(processor: ControlledFileProcessor(), authorization: authorization)
        model.inputKind = .text
        let ciphertext = try await TextCipher.process(
            "deactivation-secret", password: SecretBytes(utf8: "test-only-password-2026"),
            operation: .encrypt)
        model.text.input = ciphertext
        model.text.password = "test-only-password-2026"
        await model.text.start(.decrypt)?.value
        guard case .succeeded = model.text.state else {
            Issue.record("Expected a completed text decryption")
            return
        }
        model.conceal()
        #expect(!model.isAuthorized)
        #expect(model.isObscured)
        #expect(model.text.state == .idle)
        #expect(model.text.password.isEmpty)
        #expect(model.form.password.isEmpty)
        let task = try #require(model.resume())
        #expect(authorization.isAuthenticating)
        await authenticator.waitUntilStarted()
        authenticator.finish(success: true)
        await task.value
        #expect(model.isAuthorized && !model.isObscured)
    }

    @Test func bookmarkRoundTripAndExplicitReset() throws {
        let temporary = TemporaryDefaults("bookmark")
        let defaults = temporary.defaults
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer {
            temporary.remove()
            try? FileManager.default.removeItem(at: folder)
        }
        let settings = AppSettings(defaults: defaults, sandboxed: false)
        settings.selectOutputDirectory(folder)
        #expect(settings.accessError == nil)
        #expect(defaults.data(forKey: "outputBookmark") != nil)
        let restored = AppSettings(defaults: defaults, sandboxed: false)
        #expect(restored.outputDirectory?.standardizedFileURL == folder.standardizedFileURL)
        #expect(restored.outputAccess != nil)
        restored.outputPath = ""
        #expect(restored.outputAccess == nil && restored.outputDirectory == nil)
        #expect(defaults.data(forKey: "outputBookmark") == nil)
    }

    @Test func sandboxRejectsLegacyPathsAndCorruptBookmarks() throws {
        let temporary = TemporaryDefaults("bookmark")
        let defaults = temporary.defaults
        defer { temporary.remove() }
        defaults.set("/tmp/old-output", forKey: "outputPath")
        let legacy = AppSettings(defaults: defaults, sandboxed: true)
        #expect(legacy.outputDirectory == nil && legacy.accessError != nil)
        defaults.set(Data([0, 1, 2]), forKey: "outputBookmark")
        let corrupt = AppSettings(defaults: defaults, sandboxed: true)
        #expect(corrupt.outputDirectory == nil && corrupt.outputAccess == nil)
        #expect(corrupt.accessError != nil)
    }
}

@MainActor
private final class TestAuthenticator: LocalAuthenticating {
    var cancellations = 0
    private var continuation: CheckedContinuation<Void, any Error>?
    private var waiter: CheckedContinuation<Void, Never>?

    func authenticate() async throws {
        try await withCheckedThrowingContinuation {
            continuation = $0
            waiter?.resume()
            waiter = nil
        }
    }

    func waitUntilStarted() async {
        if continuation != nil { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func finish(success: Bool, error: any Error = CancellationError()) {
        if success { continuation?.resume() } else { continuation?.resume(throwing: error) }
        continuation = nil
    }

    func cancel() {
        cancellations += 1
        continuation?.resume(throwing: CancellationError())
        continuation = nil
    }
}

@MainActor
private final class TestAccessFlag {
    var value = true
}
