import AppKit
import Foundation
import HycryptCore
import Testing

@testable import HycryptApp

@MainActor
struct SecretSessionTests {
    @Test func switchingInputClearsSecretsAndUsesMnemonicPolicy() {
        let model = WorkspaceModel(processor: ControlledFileProcessor(), authorization: nil)
        model.text.input = "old plaintext"
        model.form.password = "old password"
        model.selectInputKind(.mnemonic)
        #expect(model.text.input.isEmpty && model.form.password.isEmpty)
        model.text.mnemonic.edit("only", at: 0)
        model.text.password = "test-only-password-2026"
        model.text.confirmation = model.text.password
        #expect(
            model.text.validationMessage(for: .encrypt, kind: .mnemonic)
                == BIP39.Failure.invalidWordCount.localizedDescription)
        model.text.mnemonic.edit(Array(repeating: "abandon", count: 23).joined(separator: " ") + " art", at: 0)
        #expect(model.text.validationMessage(for: .encrypt, kind: .mnemonic) == nil)
        model.lock()
        #expect(model.text.input.isEmpty && model.text.password.isEmpty && model.text.confirmation.isEmpty)
    }

    @Test func lockedTextCannotPublishLateResults() async throws {
        let processor = SuspendedTextProcessor()
        let model = TextWorkspace(processor: { _, _, _, _ in await processor.run() })
        model.input = "secret"
        model.password = "test-only-password-2026"
        model.confirmation = model.password
        let task = try #require(model.start(.encrypt))
        #expect(model.input.isEmpty)
        await processor.waitUntilStarted()
        model.clear()
        #expect(model.state == .cancelling)
        #expect(model.start(.decrypt) == nil)
        await processor.complete("late plaintext")
        await task.value
        #expect(model.state == .idle && model.input.isEmpty && !model.isRevealed)
    }

    @Test func decryptedTextStartsHiddenAndCanBeConcealed() async throws {
        let model = TextWorkspace(processor: { _, _, _, _ in "synthetic secret" })
        model.input = "ciphertext"
        model.password = "old"
        await model.start(.decrypt)?.value
        #expect(model.state == .succeeded("synthetic secret"))
        #expect(!model.isRevealed)
        model.reveal()
        #expect(model.isRevealed)
        model.conceal()
        #expect(!model.isRevealed)
        #expect(model.state == .succeeded("synthetic secret"))
        model.discardDecryptedPlaintext()
        #expect(model.state == .idle && !model.isRevealed)
    }

    @Test func switchingAwayDiscardsLateDecryption() async throws {
        let processor = SuspendedTextProcessor()
        let model = TextWorkspace(processor: { _, _, _, _ in await processor.run() })
        model.input = "ciphertext"
        model.password = "old"
        let task = try #require(model.start(.decrypt))
        await processor.waitUntilStarted()
        model.discardDecryptedPlaintext()
        await processor.complete("late plaintext")
        await task.value
        #expect(model.state == .idle)
    }

    @Test func clipboardCleanupPreservesNewerContent() {
        let pasteboard = NSPasteboard(name: .init("hycrypt-test-" + UUID().uuidString))
        defer { pasteboard.releaseGlobally() }
        let clipboard = SecretClipboard(pasteboard: pasteboard)
        clipboard.copy("secret", sensitive: true)
        #expect(pasteboard.string(forType: .string) == "secret")
        #expect(pasteboard.types?.contains(.init("org.nspasteboard.ConcealedType")) == true)
        clipboard.clear()
        #expect(pasteboard.string(forType: .string) == nil)
        clipboard.copy("second secret", sensitive: true)
        pasteboard.clearContents()
        pasteboard.setString("new content", forType: .string)
        clipboard.clear()
        #expect(pasteboard.string(forType: .string) == "new content")
        clipboard.copy("ciphertext", sensitive: false)
        clipboard.clear()
        #expect(pasteboard.string(forType: .string) == "ciphertext")
    }

    @Test func sensitiveCopiesStayOnThisMac() {
        #expect(SecretClipboard.contentsOptions(sensitive: true).contains(.currentHostOnly))
        #expect(!SecretClipboard.contentsOptions(sensitive: false).contains(.currentHostOnly))
    }

    @Test func sensitiveEditorsOptOutOfSystemTextAssistance() {
        let editor = ProtectedTextView()
        editor.configureSensitiveInput()
        #expect(editor.inlinePredictionType == .no)
        #expect(!editor.allowsUndo && !editor.isAutomaticTextCompletionEnabled)
        if #available(macOS 15.0, *) {
            #expect(editor.writingToolsBehavior == .none)
        }
        let fieldEditor = NSTextView()
        disableSystemTextAssistance(fieldEditor)
        #expect(fieldEditor.inlinePredictionType == .no)
        let password = ProtectedPasswordField()
        #expect(password.cell is NSSecureTextFieldCell)
        #expect(password.validRequestor(forSendType: .string, returnType: nil) == nil)
    }

    @Test func fileLockCancelsAndClearsPasswords() async throws {
        let processor = ControlledFileProcessor()
        let model = WorkspaceModel(processor: processor, authorization: nil)
        model.selectSource(URL(fileURLWithPath: "/tmp/test.txt"))
        model.form.password = "test-only-password-2026"
        model.form.confirmation = model.form.password
        let task = try #require(model.start())
        await processor.waitUntilStarted()
        model.lock()
        #expect(model.state == .cancelling)
        #expect(model.form.password.isEmpty && model.form.confirmation.isEmpty)
        await task.value
        #expect(model.state == .cancelled)
    }
}

private actor SuspendedTextProcessor {
    private var continuation: CheckedContinuation<String, Never>?
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func run() async -> String {
        await withCheckedContinuation {
            continuation = $0
            for waiter in waiters { waiter.resume() }
            waiters.removeAll()
        }
    }

    func waitUntilStarted() async {
        if continuation != nil { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func complete(_ result: String) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}
