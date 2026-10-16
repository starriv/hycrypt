import AppKit
import HycryptCore
import SwiftUI

struct MnemonicGrid: View {
    @Binding var draft: MnemonicInput
    let enabled: Bool
    var readOnly = false
    let finished: () -> Void
    @State private var revealedIndex: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(0..<BIP39.wordCount, id: \.self) { index in
                    HStack(spacing: 6) {
                        Text(String(index + 1))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 18, alignment: .trailing)
                        if readOnly {
                            ZStack(alignment: .leading) {
                                if revealedIndex == index && enabled {
                                    Text(draft.words[index])
                                        .transition(
                                            .asymmetric(
                                                insertion: reduceMotion
                                                    ? .identity : .opacity.combined(with: .offset(y: 2)),
                                                removal: .identity))
                                } else {
                                    Text("••••").foregroundStyle(.secondary)
                                        .transition(.identity)
                                }
                            }
                            .font(.body.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 24)
                            .accessibilityLabel("第 \(index + 1) 个单词")
                        } else {
                            MnemonicWordField(draft: $draft, index: index, enabled: enabled, finished: finished)
                                .frame(height: 24)
                        }
                        if !readOnly {
                            Button {
                                revealedIndex = revealedIndex == index ? nil : index
                            } label: {
                                Image(systemName: revealedIndex == index ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.borderless)
                            .disabled(!enabled || draft.words[index].isEmpty)
                            .help("查看此单词及候选词，10 秒后隐藏")
                            .accessibilityLabel("查看第 \(index + 1) 个单词")
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.background, in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        if readOnly && revealedIndex == index {
                            RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.06))
                                .allowsHitTesting(false)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 6))
                    .onHover { hovering in
                        guard readOnly else { return }
                        if hovering && enabled {
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                                revealedIndex = index
                            }
                        } else if revealedIndex == index {
                            concealWord()
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(borderColor(index), lineWidth: draft.activeIndex == index ? 1.5 : 0.5)
                    }
                    .overlay(alignment: .topLeading) {
                        if !readOnly && revealedIndex == index {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(draft.words[index])
                                    .font(.body.monospaced())
                                    .padding(6)
                                ForEach(
                                    BIP39.contains(draft.words[index])
                                        ? [] : BIP39.suggestions(for: draft.words[index]), id: \.self
                                ) { word in
                                    Button {
                                        draft.activeIndex = index
                                        draft.choose(word)
                                        revealedIndex = nil
                                    } label: {
                                        Text(word).frame(maxWidth: .infinity, alignment: .leading).padding(6)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!enabled)
                                }
                            }
                            .padding(4)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                            .shadow(radius: 4)
                            .offset(y: 36)
                        }
                    }
                    .zIndex(revealedIndex == index ? 1 : 0)
                }
            }
        }
        .padding(.vertical, 6)
        .task(id: revealedIndex) {
            guard !readOnly, revealedIndex != nil else { return }
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            revealedIndex = nil
        }
        .onChange(of: draft.activeIndex) { _, _ in concealWord() }
        .onChange(of: draft.words) { _, _ in concealWord() }
        .onChange(of: enabled) { _, _ in concealWord() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            concealWord()
        }
        .onDisappear { concealWord() }
    }

    private func concealWord() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { revealedIndex = nil }
    }

    private func borderColor(_ index: Int) -> Color {
        let word = draft.words[index]
        if !word.isEmpty && !BIP39.contains(word) && BIP39.suggestions(for: word).isEmpty { return .red }
        return draft.activeIndex == index || (readOnly && revealedIndex == index)
            ? .accentColor : .secondary.opacity(0.35)
    }
}

private struct MnemonicWordField: NSViewRepresentable {
    @Binding var draft: MnemonicInput
    let index: Int
    let enabled: Bool
    let finished: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> ProtectedWordField {
        let field = ProtectedWordField()
        field.cell = NSSecureTextFieldCell(textCell: "")
        field.isEditable = true
        field.isSelectable = true
        field.cell?.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        field.delegate = context.coordinator
        field.setAccessibilityLabel("第 \(index + 1) 个单词")
        return field
    }

    func updateNSView(_ field: ProtectedWordField, context: Context) {
        context.coordinator.parent = self
        field.isEnabled = enabled
        let word = draft.words[index]
        if field.stringValue != word { field.stringValue = word }
        if draft.activeIndex == index && context.coordinator.focusRequest != draft.focusRequest {
            context.coordinator.focusRequest = draft.focusRequest
            DispatchQueue.main.async { [weak field, weak coordinator = context.coordinator] in
                guard let field, let coordinator, coordinator.parent.enabled,
                    coordinator.parent.draft.activeIndex == coordinator.parent.index,
                    field.window?.isKeyWindow == true
                else { return }
                field.window?.makeFirstResponder(field)
            }
        }
    }

    static func dismantleNSView(_ field: ProtectedWordField, coordinator: Coordinator) {
        field.delegate = nil
        field.currentEditor()?.string = ""
        field.stringValue = ""
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MnemonicWordField
        var focusRequest = 0
        init(_ parent: MnemonicWordField) { self.parent = parent }

        func controlTextDidBeginEditing(_ notification: Notification) {
            parent.draft.activeIndex = parent.index
            if let field = notification.object as? NSSecureTextField,
                let editor = field.currentEditor() as? NSTextView
            {
                editor.allowsUndo = false
                editor.undoManager?.removeAllActions()
                editor.isContinuousSpellCheckingEnabled = false
                editor.isGrammarCheckingEnabled = false
                editor.isAutomaticSpellingCorrectionEnabled = false
                editor.isAutomaticTextCompletionEnabled = false
                editor.isAutomaticTextReplacementEnabled = false
                disableSystemTextAssistance(editor)
            }
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.draft.edit(field.stringValue, at: parent.index)
            let accepted = parent.draft.words[parent.index]
            if field.stringValue != accepted { field.stringValue = accepted }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertTab(_:)), #selector(NSResponder.insertNewline(_:)):
                if parent.index == BIP39.wordCount - 1 && BIP39.contains(parent.draft.words[parent.index]) {
                    parent.draft.activeIndex = nil
                    control.window?.makeFirstResponder(nil)
                    parent.finished()
                    return true
                }
                parent.draft.advance(from: parent.index)
                return true
            case #selector(NSResponder.insertBacktab(_:)):
                if parent.index == 0 { return false }
                parent.draft.advance(from: parent.index, backwards: true)
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                control.window?.makeFirstResponder(nil)
                parent.draft.activeIndex = nil
                return true
            default: return false
            }
        }
    }
}

/// Keep AppKit's secure field editor; replacing it with NSTextView would expose input.
final class ProtectedWordField: NSSecureTextField {
    override func validRequestor(
        forSendType sendType: NSPasteboard.PasteboardType?, returnType: NSPasteboard.PasteboardType?
    ) -> Any? { nil }

    override func menu(for event: NSEvent) -> NSMenu? { nil }
}
