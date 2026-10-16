import Foundation
import HycryptCore
import Testing

@testable import HycryptApp

@MainActor
struct TextWorkspaceTests {
    @Test func encryptionUsesTrimmedPasswordAndRejectsInteriorWhitespace() async throws {
        let model = TextWorkspace(processor: { _, password, _, _ in
            #expect(password.withUnsafeBytes { String(decoding: $0, as: UTF8.self) } == "a")
            return "synthetic-ciphertext"
        })
        model.input = "hello"
        model.password = "a b"
        model.confirmation = "a b"
        #expect(model.start(.encrypt) == nil)
        #expect(model.passwordValidationMessage != nil)
        model.password = " \ta\n"
        model.confirmation = "a"
        #expect(model.passwordValidationMessage == nil)
        let task = try #require(model.start(.encrypt))
        await task.value
        #expect(model.state == .succeeded("synthetic-ciphertext"))
    }

    @Test func validationAndModeSwitchReset() {
        let model = TextWorkspace()
        #expect(model.validationMessage(for: .encrypt) != nil)
        model.input = "hello"
        model.password = "test-only-password-2026"
        #expect(model.validationMessage(for: .encrypt) != nil)
        #expect(model.validationMessage(for: .decrypt) == nil)
        model.confirmation = "test-only-password-2026"
        #expect(model.validationMessage(for: .encrypt) == nil)
        model.resetResult()
        #expect(model.password.isEmpty && model.confirmation.isEmpty)
        #expect(model.input == "hello")
    }

    @Test func completionAndEditingClearResult() async {
        let model = TextWorkspace()
        model.input = "hello"
        model.password = "test-only-password-2026"
        model.confirmation = "test-only-password-2026"
        let task = model.start(.encrypt)
        #expect(task != nil)
        #expect(model.state.isBusy)
        #expect(model.password.isEmpty && model.confirmation.isEmpty)
        #expect(model.start(.encrypt) == nil)
        await task?.value
        guard case .succeeded(let result) = model.state else {
            Issue.record("Expected ciphertext")
            return
        }
        #expect(Data(base64Encoded: result) != nil)
        model.input = "changed"
        #expect(model.state == .idle)
    }

    @Test func cancellationFinishes() async {
        let model = TextWorkspace()
        model.input = "hello"
        model.password = "test-only-password-2026"
        model.confirmation = "test-only-password-2026"
        let task = model.start(.encrypt)
        model.cancel()
        await task?.value
        #expect(model.state == .cancelled)
    }
}
