import AppKit
import HycryptCore
import SwiftUI

struct PasswordOptions: View {
    let operation: CryptOperation
    @Binding var password: String
    @Binding var confirmation: String
    var focusRequest = 0
    @ScaledMetric private var labelWidth = 64

    var body: some View {
        Section("密码") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    fieldLabel("密码")
                    RevealablePasswordField(
                        text: $password,
                        prompt: operation == .encrypt ? "输入便于记忆的密码" : "输入加密时使用的密码",
                        label: "密码", focusRequest: focusRequest
                    )
                    .frame(maxWidth: .infinity, minHeight: 22)
                }
                if operation == .encrypt {
                    GridRow(alignment: .top) {
                        fieldLabel("强度").foregroundStyle(.secondary)
                        strengthIndicator
                    }
                    GridRow {
                        fieldLabel("确认密码")
                        RevealablePasswordField(text: $confirmation, prompt: "再次输入密码", label: "确认密码")
                            .frame(maxWidth: .infinity, minHeight: 22)
                    }
                    if !confirmation.isEmpty
                        && SecretPolicy.preparedPassword(password, operation: operation)
                            != SecretPolicy.preparedPassword(confirmation, operation: operation)
                    {
                        GridRow {
                            Color.clear.frame(width: labelWidth, height: 1)
                            Label("两次输入的密码不一致", systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .frame(width: labelWidth, alignment: .leading)
    }

    private var strengthIndicator: some View {
        let strength = PasswordStrength(SecretPolicy.preparedPassword(password, operation: operation))
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                ProgressView(value: Double(strength.level), total: 4)
                    .progressViewStyle(.linear)
                    .tint(strengthColor(strength.level))
                    .frame(maxWidth: 220)
                    .accessibilityLabel("密码强度估计")
                    .accessibilityValue(strength.title)
                Text(strength.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("强度仅作提示。首尾空白自动忽略，密码中间不能包含空格、Tab 或换行。")
                .font(.caption)
                .foregroundStyle(.secondary)
            if SecretPolicy.mayDependOnInputMethod(password) {
                Label("密码包含非 ASCII 字符。换用其他输入法或设备时编码可能不同，导致无法解密。", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func strengthColor(_ level: Int) -> Color {
        switch level {
        case 0: .secondary
        case 1: .red
        case 2: .orange
        case 3: .blue
        default: .green
        }
    }
}

/// Reveals in place only after an explicit user action.
private struct RevealablePasswordField: View {
    @Binding var text: String
    let prompt: String
    let label: String
    var focusRequest = 0
    @State private var isRevealed = false
    @State private var selection = NSRange(location: 0, length: 0)
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 8) {
            SecurePasswordField(
                text: $text, prompt: prompt, label: label, focusRequest: focusRequest,
                isRevealed: isRevealed, selection: $selection
            )
            .id(isRevealed)
            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isRevealed ? "隐藏\(label)" : "显示\(label)")
            .accessibilityValue(isRevealed ? "已显示" : "已隐藏")
            .help(isRevealed ? "隐藏\(label)" : "显示\(label)以核对")
            .disabled(text.isEmpty)
        }
        .onChange(of: text) { if text.isEmpty { isRevealed = false } }
        .onChange(of: isEnabled) { if !isEnabled { isRevealed = false } }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            isRevealed = false
        }
        .onDisappear { isRevealed = false }
    }
}

/// Native secure field so focused password entry uses secure input, not a SwiftUI text field.
struct SecurePasswordField: NSViewRepresentable {
    @Binding var text: String
    let prompt: String
    let label: String
    var focusRequest = 0
    var isRevealed = false
    @Binding var selection: NSRange
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field: NSTextField = isRevealed ? RevealedPasswordField() : ProtectedPasswordField()
        if !isRevealed { field.cell = NSSecureTextFieldCell(textCell: "") }
        field.isEditable = true
        field.isSelectable = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.cell?.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.contentType = nil
        field.delegate = context.coordinator
        field.placeholderString = prompt
        field.setAccessibilityLabel(label)
        field.stringValue = text
        if !text.isEmpty {
            let savedSelection = selection
            DispatchQueue.main.async { [weak field] in
                guard let field, field.window?.isKeyWindow == true, field.isEnabled else { return }
                field.window?.makeFirstResponder(field)
                let length = (field.stringValue as NSString).length
                let location = min(savedSelection.location, length)
                field.currentEditor()?.selectedRange = NSRange(
                    location: location, length: min(savedSelection.length, length - location))
            }
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        field.isEnabled = isEnabled
        field.placeholderString = prompt
        field.setAccessibilityLabel(label)
        if field.stringValue != text { field.stringValue = text }
        guard context.coordinator.focusRequest != focusRequest else { return }
        context.coordinator.focusRequest = focusRequest
        DispatchQueue.main.async { [weak field] in
            guard let field, field.window?.isKeyWindow == true else { return }
            field.window?.makeFirstResponder(field)
        }
    }

    static func dismantleNSView(_ field: NSTextField, coordinator: Coordinator) {
        field.delegate = nil
        field.currentEditor()?.string = ""
        field.stringValue = ""
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SecurePasswordField
        var focusRequest = 0
        init(_ parent: SecurePasswordField) { self.parent = parent }

        func controlTextDidBeginEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField,
                let editor = field.currentEditor() as? NSTextView
            else { return }
            editor.allowsUndo = false
            editor.undoManager?.removeAllActions()
            editor.isContinuousSpellCheckingEnabled = false
            editor.isGrammarCheckingEnabled = false
            editor.isAutomaticSpellingCorrectionEnabled = false
            editor.isAutomaticTextCompletionEnabled = false
            editor.isAutomaticTextReplacementEnabled = false
            disableSystemTextAssistance(editor)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField,
                let editor = field.currentEditor()
            else { return }
            parent.selection = editor.selectedRange
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
            if let editor = field.currentEditor() { parent.selection = editor.selectedRange }
        }
    }
}

final class ProtectedPasswordField: NSSecureTextField {
    override func validRequestor(
        forSendType sendType: NSPasteboard.PasteboardType?, returnType: NSPasteboard.PasteboardType?
    ) -> Any? { nil }

    override func menu(for event: NSEvent) -> NSMenu? { nil }
}

final class RevealedPasswordField: NSTextField {
    override func validRequestor(
        forSendType sendType: NSPasteboard.PasteboardType?, returnType: NSPasteboard.PasteboardType?
    ) -> Any? { nil }

    override func menu(for event: NSEvent) -> NSMenu? { nil }
}
