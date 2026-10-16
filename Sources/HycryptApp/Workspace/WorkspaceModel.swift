import Foundation
import HycryptCore
import Observation

@MainActor
@Observable
final class WorkspaceModel {
    enum InputKind: String, CaseIterable, Identifiable {
        case file
        case text
        case mnemonic
        var id: Self { self }
        var title: String {
            switch self {
            case .file: "文件"
            case .text: "文本"
            case .mnemonic: "助记词"
            }
        }
        var textKind: SecretPolicy.TextKind { self == .mnemonic ? .mnemonic : .text }
    }
    let settings: AppSettings
    var inputKind: InputKind = .file
    private(set) var isObscured = false
    let text: TextWorkspace
    let authorization: LocalAuthorization?
    var hasOutputAuthorization: Bool { outputAccess != nil }
    var isAuthorized: Bool { authorization?.isUnlocked ?? true }
    var canAccessWindows: Bool { isAuthorized && !isObscured }
    @ObservationIgnored private var sourceAccess: SecurityScopedAccess?
    @ObservationIgnored private var outputAccess: SecurityScopedAccess?
    /// A document opened while locked (for example by double-clicking at launch) waits for unlock.
    private(set) var pendingSource: URL?
    var isBusy: Bool { state.isBusy || text.state.isBusy }

    var form = OperationForm() {
        didSet {
            if !state.isBusy { state = .idle }
        }
    }
    private(set) var state: OperationState = .idle
    @ObservationIgnored private let processor: any FileProcessing
    @ObservationIgnored private var operationID: UUID?
    @ObservationIgnored private var task: Task<Void, Never>?

    init(
        processor: any FileProcessing, settings: AppSettings = AppSettings(),
        authorization: LocalAuthorization? = LocalAuthorization(startsUnlocked: true)
    ) {
        self.authorization = authorization
        text = TextWorkspace(isAuthorized: { authorization?.isUnlocked ?? true })
        self.processor = processor
        self.settings = settings
        inputKind = InputKind(rawValue: settings.defaultInput) ?? .file
    }

    func refreshOutputDirectory() {
        guard !isBusy, let source = form.source?.url else { return }
        let directory = settings.destinationDirectory(for: source)
        outputAccess = settings.outputAccess
        guard form.outputDirectory != directory else { return }
        let previousState = state
        form.selectOutputDirectory(directory)
        state = previousState
    }

    deinit {
        task?.cancel()
    }

    func selectSource(_ url: URL) {
        guard !isBusy, url.isFileURL else { return }
        guard canAccessWindows else {
            pendingSource = url
            return
        }
        pendingSource = nil
        inputKind = .file
        text.clear()
        form.clearPassword()
        sourceAccess = SecurityScopedAccess(url)
        form.selectSource(url)
        outputAccess = nil
        refreshOutputDirectory()
    }

    func selectOperation(_ operation: CryptOperation) {
        guard !isBusy, canAccessWindows, operation != form.operation else { return }
        text.clear()
        form.clearPassword()
        form.selectOperation(operation)
    }

    func selectInputKind(_ kind: InputKind) {
        guard !isBusy, canAccessWindows, kind != inputKind else { return }
        text.clear()
        form.clearPassword()
        inputKind = kind
    }

    func conceal() {
        guard inputKind == .mnemonic else { return }
        if authorization?.isAuthenticating != true { authorization?.lock() }
        isObscured = true
        let previousState = state
        form.clearPassword()
        state = previousState
        if !text.password.isEmpty { text.password = "" }
        if !text.confirmation.isEmpty { text.confirmation = "" }
        text.discardDecryptedPlaintext()
        text.mnemonic.activeIndex = nil
    }

    /// Request authentication once for the current lock; repeated activation events
    /// must not reopen a cancelled system prompt.
    /// Returns the owned unlock task (if any) for deterministic tests.
    @discardableResult
    func resume() -> Task<Void, Never>? {
        isObscured = false
        return !isAuthorized ? authorization?.unlockAutomatically() : nil
    }

    func applyPendingSource() {
        guard canAccessWindows, let url = pendingSource else { return }
        selectSource(url)
    }

    func lock() {
        pendingSource = nil
        authorization?.lock()
        text.clear()
        form.clearPassword()
        cancel()
        SecretClipboard.shared.clear()
    }

    /// Locks the shared app session and immediately asks macOS to authenticate again.
    /// Lifecycle locks use `lock()` alone so they never present UI while the app is inactive.
    @discardableResult
    func lockAndRequestAuthentication() -> Task<Void, Never>? {
        lock()
        return authorization?.unlockAutomatically()
    }

    func selectOutputDirectory(_ url: URL) {
        guard !isBusy, canAccessWindows, url.isFileURL else { return }
        outputAccess = SecurityScopedAccess(url)
        form.selectOutputDirectory(url)
    }

    /// Returns the same owned task that cancel() controls, also allowing deterministic tests.
    @discardableResult
    func start() -> Task<Void, Never>? {
        guard !isBusy, canAccessWindows else { return nil }
        if !ApplicationSandbox.isEnabled { refreshOutputDirectory() }
        guard !ApplicationSandbox.isEnabled || hasOutputAuthorization else { return nil }
        guard let request = try? form.makeRequest() else { return nil }
        form.clearPassword()
        let id = UUID()
        operationID = id
        state = .running(.init(.preparing))
        let processor = processor
        let access = [sourceAccess, outputAccess]
        task = Task { [weak self] in
            // Bounded progress delivery: avoid allocating a main-actor Task for every file/chunk.
            let (updates, continuation) = AsyncStream<OperationProgress>.makeStream(
                bufferingPolicy: .bufferingNewest(1))
            let progressTask = Task { [weak self] in
                for await update in updates {
                    guard !Task.isCancelled else { break }
                    self?.receive(update, for: id)
                }
            }
            defer {
                withExtendedLifetime(access) {}
                continuation.finish()
                progressTask.cancel()
            }
            do {
                let output = try await processor.process(request) { update in
                    continuation.yield(update)
                }
                // If publication won a cancellation race, report the file that actually exists.
                self?.finish(.succeeded(output), for: id)
            } catch is CancellationError {
                self?.finish(.cancelled, for: id)
            } catch {
                self?.finish(.failed(error.localizedDescription), for: id)
            }
        }
        return task
    }

    func cancel() {
        guard case .running = state else { return }
        state = .cancelling
        task?.cancel()
    }

    private func receive(_ progress: OperationProgress, for id: UUID) {
        guard operationID == id, case .running = state else { return }
        state = .running(progress)
    }

    private func finish(_ result: OperationState, for id: UUID) {
        guard operationID == id else { return }
        operationID = nil
        state = result
        task = nil
    }
}
