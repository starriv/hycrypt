import AppKit
import Foundation
import HycryptCore
import Testing

@testable import HycryptApp

@MainActor
struct MnemonicWorkspaceTests {
    @Test func mnemonicFieldUsesNativeSecureCellAndRejectsServices() {
        let field = ProtectedWordField()
        #expect(field.cell is NSSecureTextFieldCell)
        #expect(field.validRequestor(forSendType: .string, returnType: .string) == nil)
    }

    private var phrase: String { Array(repeating: "abandon", count: 23).joined(separator: " ") + " art" }

    @Test func wholePhraseImportIsAtomicAndChecksChecksum() {
        var draft = MnemonicInput()
        draft.edit(phrase, at: 4)
        #expect(draft.validationMessage == nil)
        #expect(draft.words.count == 24 && draft.words.last == "art")
        let original = draft.words
        for invalid in [
            "abandon ability", Array(repeating: "abandon", count: 24).joined(separator: " "), phrase + " zoo",
        ] {
            draft.edit(invalid, at: 0)
            #expect(draft.words == original)
            #expect(draft.validationMessage != nil)
        }
        draft.clear()
        #expect(draft.isEmpty && draft.inputError == nil && draft.activeIndex == nil)
    }

    @Test func completionsUseOnlyLocalDictionaryAndNeverSilentlyCorrect() {
        var draft = MnemonicInput()
        draft.activeIndex = 0
        draft.edit("aban", at: 0)
        #expect(draft.suggestions == ["abandon"])
        draft.choose("ability")
        #expect(draft.words[0] == "aban")
        draft.choose("abandon")
        #expect(draft.words[0] == "abandon" && draft.activeIndex == 1)
        draft.edit("zzzz", at: 1)
        #expect(draft.suggestions.isEmpty)
        draft.advance(from: 1)
        #expect(draft.activeIndex == 1)
        for input in ["аbandon", "Abandon", "ab\0", "abandonment", String(repeating: "a", count: 257)] {
            draft.edit(input, at: 1)
            #expect(draft.words[1] == "zzzz")
            #expect(draft.inputError != nil)
        }
    }

    @Test func generationNeedsNoPasswordAndNeverOverwritesDraft() {
        let words = phrase.split(separator: " ").map(String.init)
        let model = TextWorkspace(generator: { words })
        #expect(model.canGenerateMnemonic)
        model.generateMnemonic()
        #expect(model.hasGeneratedMnemonic)
        #expect(model.password.isEmpty && model.mnemonic.words == words)
        #expect(!model.canGenerateMnemonic)
        model.generateMnemonic()
        #expect(model.mnemonic.words == words)
        model.clear()
        model.mnemonic.edit("only", at: 0)
        model.generateMnemonic()
        #expect(model.mnemonic.words[0] == "only" && !model.hasGeneratedMnemonic)
    }

    @Test func generatedBackupRequiresConfirmationAndEncryptsTheSameWords() async throws {
        let words = phrase.split(separator: " ").map(String.init)
        let model = TextWorkspace(generator: { words })
        model.generateMnemonic()
        model.password = "test-only-password-2026"
        model.confirmation = model.password
        #expect(model.start(.encrypt, kind: .mnemonic) == nil)
        model.backupConfirmed = true
        let task = try #require(model.start(.encrypt, kind: .mnemonic))
        #expect(model.mnemonic.isEmpty && !model.hasGeneratedMnemonic)
        #expect(!model.backupConfirmed && model.password.isEmpty)
        await task.value
        guard case .succeeded(let ciphertext) = model.state else {
            Issue.record("Expected successful encryption")
            return
        }
        let restored = try await TextCipher.process(
            ciphertext, password: SecretBytes(utf8: "test-only-password-2026"), operation: .decrypt, kind: .mnemonic)
        #expect(restored == phrase)
    }

    @Test func hidingPreservesBackupButLockAndModeSwitchDiscardIt() {
        let model = WorkspaceModel(processor: ControlledFileProcessor(), authorization: nil)
        model.selectInputKind(.mnemonic)
        model.text.generateMnemonic()
        #expect(model.text.hasGeneratedMnemonic)
        model.conceal()
        #expect(model.isObscured && !model.text.mnemonic.isEmpty)
        model.resume()
        #expect(!model.isObscured)
        model.lock()
        #expect(model.text.mnemonic.isEmpty && !model.text.hasGeneratedMnemonic)
        #expect(!model.text.backupConfirmed)
        model.text.generateMnemonic()
        model.selectInputKind(.text)
        #expect(model.text.mnemonic.isEmpty && !model.text.hasGeneratedMnemonic)
    }

    @Test func generationFailureLeavesNoPartialDraft() {
        let generators: [TextWorkspace.Generator] = [
            { throw HycryptError.cryptoFailure(-1) },
            { Array(repeating: "abandon", count: 24) },
        ]
        for generator in generators {
            let model = TextWorkspace(generator: generator)
            model.generateMnemonic()
            guard case .failed = model.state else {
                Issue.record("Expected generation failure")
                continue
            }
            #expect(model.mnemonic.isEmpty && !model.hasGeneratedMnemonic)
            #expect(!model.backupConfirmed)
        }
    }

    @Test func changingDraftInvalidatesBackupConfirmation() {
        let words = phrase.split(separator: " ").map(String.init)
        let model = TextWorkspace(generator: { words })
        model.generateMnemonic()
        model.backupConfirmed = true
        model.mnemonic.edit("ability", at: 0)
        #expect(!model.backupConfirmed)
    }

    @Test func manualInputStillEncryptsWithoutBackupConfirmation() async throws {
        let expected = phrase
        let manual = TextWorkspace(processor: { input, _, operation, kind in
            #expect(input == expected && operation == .encrypt && kind == .mnemonic)
            return "ciphertext-only"
        })
        manual.mnemonic.edit(phrase, at: 0)
        manual.password = "test-only-password-2026"
        manual.confirmation = manual.password
        let task = try #require(manual.start(.encrypt, kind: .mnemonic))
        #expect(manual.mnemonic.isEmpty && manual.input.isEmpty)
        await task.value
        #expect(manual.state == .succeeded("ciphertext-only"))
    }

    @Test func protectedEditorDisablesSystemLearningAndUndo() {
        let editor = ProtectedTextView()
        editor.configureSensitiveInput()
        #expect(!editor.allowsUndo && !editor.isRichText)
        #expect(!editor.isContinuousSpellCheckingEnabled && !editor.isAutomaticSpellingCorrectionEnabled)
        #expect(!editor.isAutomaticTextCompletionEnabled && !editor.isAutomaticTextReplacementEnabled)
        #expect(editor.validRequestor(forSendType: .string, returnType: .string) == nil)
    }
}
