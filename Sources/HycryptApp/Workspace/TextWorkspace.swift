import Foundation
import HycryptCore
import Observation

@MainActor
@Observable
final class TextWorkspace {
    var input = "" { didSet { if !state.isBusy { state = .idle } } }
    var password = "" { didSet { if !state.isBusy { state = .idle } } }
    var confirmation = "" { didSet { if !state.isBusy { state = .idle } } }
    var mnemonic = MnemonicInput() {
        didSet {
            if !state.isBusy && oldValue.words != mnemonic.words {
                state = .idle
                backupConfirmed = false
                conceal()
            }
        }
    }
    private(set) var state: State = .idle
    private(set) var resultOperation: CryptOperation?
    private(set) var isRevealed = false
    private(set) var hasGeneratedMnemonic = false
    var backupConfirmed = false
    @ObservationIgnored private var revealTask: Task<Void, Never>?
    @ObservationIgnored private var discardResult = false
    @ObservationIgnored private var task: Task<Void, Never>?

    typealias Processor = @Sendable (String, SecretBytes, CryptOperation, SecretPolicy.TextKind) async throws -> String
    typealias Generator = @Sendable () throws -> [String]
    @ObservationIgnored private let processor: Processor
    @ObservationIgnored private let generator: Generator
    @ObservationIgnored private let isAuthorized: @MainActor () -> Bool

    init(
        isAuthorized: @escaping @MainActor () -> Bool = { true },
        generator: @escaping Generator = { try BIP39.generateWords() },
        processor: @escaping Processor = { input, password, operation, kind in
            try await TextCipher.process(input, password: password, operation: operation, kind: kind)
        }
    ) {
        self.isAuthorized = isAuthorized
        self.processor = processor
        self.generator = generator
    }

    enum State: Equatable {
        case idle, running, cancelling
        case succeeded(String)
        case failed(String)
        case cancelled
        var isBusy: Bool { self == .running || self == .cancelling }
    }

    deinit {
        task?.cancel()
        revealTask?.cancel()
    }

    func validationMessage(for operation: CryptOperation, kind: SecretPolicy.TextKind = .text) -> String? {
        if kind == .mnemonic && operation == .encrypt {
            if let message = mnemonic.validationMessage { return message }
            if hasGeneratedMnemonic && !backupConfirmed { return "请先抄写并核对 24 个单词。" }
            return passwordValidationMessage
        }
        if input.isEmpty { return operation == .encrypt ? "输入要加密的文本。" : "粘贴要解密的密文。" }
        let limit = operation == .encrypt ? kind.maximumBytes : TextCipher.maximumEncodedBytes
        if input.utf8.count > limit { return "文本过长，请使用文件模式。" }
        let password = SecretPolicy.preparedPassword(password, operation: operation)
        let confirmation = SecretPolicy.preparedPassword(confirmation, operation: operation)
        if password.isEmpty { return "请输入密码。" }
        if operation == .encrypt && password != confirmation { return "两次输入的密码不一致。" }
        do {
            try SecretPolicy.validatePassword(password, operation: operation)
            if operation == .encrypt { try kind.validate(input) }
        } catch { return error.localizedDescription }
        return nil
    }

    var passwordValidationMessage: String? {
        let password = SecretPolicy.preparedPassword(password, operation: .encrypt)
        let confirmation = SecretPolicy.preparedPassword(confirmation, operation: .encrypt)
        if password != confirmation { return "两次输入的密码不一致。" }
        do { try SecretPolicy.validatePassword(password, operation: .encrypt) } catch {
            return error.localizedDescription
        }
        return nil
    }

    var canGenerateMnemonic: Bool {
        if case .succeeded = state { return false }
        return !state.isBusy && mnemonic.isEmpty && mnemonic.inputError == nil && !hasGeneratedMnemonic
    }

    func resetResult() {
        guard !state.isBusy else { return }
        state = .idle
        password = ""
        confirmation = ""
        resultOperation = nil
        conceal()
    }

    func clear() {
        discardResult = true
        input = ""
        mnemonic.clear()
        hasGeneratedMnemonic = false
        backupConfirmed = false
        password = ""
        confirmation = ""
        resultOperation = nil
        conceal()
        if state.isBusy {
            cancel()
        } else {
            state = .idle
        }
    }

    func conceal() {
        revealTask?.cancel()
        revealTask = nil
        isRevealed = false
    }

    /// App switch drops decrypted plaintext instead of only hiding it. Encryption ciphertext is kept.
    func discardDecryptedPlaintext() {
        conceal()
        guard resultOperation == .decrypt else { return }
        if state.isBusy {
            discardResult = true
            cancel()
            return
        }
        if case .succeeded = state {
            state = .idle
            resultOperation = nil
        }
    }

    func reveal() {
        guard isAuthorized(), case .succeeded = state, resultOperation == .decrypt else { return }
        conceal()
        isRevealed = true
        revealTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
            self?.conceal()
        }
    }

    @discardableResult
    func start(_ operation: CryptOperation, kind: SecretPolicy.TextKind = .text) -> Task<Void, Never>? {
        guard isAuthorized(), !state.isBusy, validationMessage(for: operation, kind: kind) == nil else { return nil }
        let input = kind == .mnemonic && operation == .encrypt ? mnemonic.phrase : input
        guard let securePassword = try? SecretBytes(utf8: SecretPolicy.preparedPassword(password, operation: operation))
        else { return nil }
        let processor = processor
        return perform(operation) { try await processor(input, securePassword, operation, kind) }
    }

    func generateMnemonic() {
        guard isAuthorized(), canGenerateMnemonic else { return }
        conceal()
        resultOperation = nil
        do {
            try mnemonic.loadGenerated(generator())
            hasGeneratedMnemonic = true
            backupConfirmed = false
            state = .idle
        } catch {
            mnemonic.clear()
            hasGeneratedMnemonic = false
            backupConfirmed = false
            state = .failed(error.localizedDescription)
        }
    }

    private func perform(_ operation: CryptOperation, work: @escaping @Sendable () async throws -> String) -> Task<
        Void, Never
    > {
        self.password = ""
        confirmation = ""
        conceal()
        discardResult = false
        resultOperation = operation
        state = .running
        self.input = ""
        mnemonic.clear()
        hasGeneratedMnemonic = false
        backupConfirmed = false
        let started = Task { [weak self] in
            do {
                let result = try await work()
                try Task.checkCancellation()
                if self?.discardResult != true { self?.state = .succeeded(result) }
            } catch is CancellationError {
                self?.state = .cancelled
            } catch {
                self?.state = .failed(error.localizedDescription)
            }
            if self?.discardResult == true { self?.state = .idle }
            self?.task = nil
        }
        task = started
        return started
    }

    func cancel() {
        guard state == .running else { return }
        state = .cancelling
        task?.cancel()
    }
}
