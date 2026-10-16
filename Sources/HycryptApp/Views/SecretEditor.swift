import AppKit
import SwiftUI

/// Plain input without undo history, text substitutions, services, or drag-out.
struct SecretEditor: NSViewRepresentable {
    @Binding var text: String
    let sensitive: Bool
    let maximumBytes: Int
    let enabled: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let editor = ProtectedTextView()
        editor.configureSensitiveInput()
        editor.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        editor.drawsBackground = false
        editor.textContainerInset = NSSize(width: 6, height: 6)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.delegate = context.coordinator
        scroll.documentView = editor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? ProtectedTextView else { return }
        editor.sensitive = sensitive
        editor.isEditable = enabled
        editor.setAccessibilityLabel(sensitive ? "原文" : "密文")
        if editor.string != text { editor.string = text }
    }

    static func dismantleNSView(_ scroll: NSScrollView, coordinator: Coordinator) {
        guard let editor = scroll.documentView as? NSTextView else { return }
        editor.delegate = nil
        editor.string = ""
        editor.undoManager?.removeAllActions()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SecretEditor
        init(_ parent: SecretEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?)
            -> Bool
        {
            guard parent.enabled, let replacementString else { return false }
            let text = textView.string as NSString
            guard affectedCharRange.location <= text.length,
                affectedCharRange.length <= text.length - affectedCharRange.location
            else { return false }
            return text.replacingCharacters(in: affectedCharRange, with: replacementString).utf8.count
                <= parent.maximumBytes
        }
    }
}

final class ProtectedTextView: NSTextView {
    var sensitive = true

    func configureSensitiveInput() {
        isRichText = false
        importsGraphics = false
        allowsUndo = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isAutomaticTextCompletionEnabled = false
        disableSystemTextAssistance(self)
    }

    override func copy(_ sender: Any?) {
        let range = selectedRange()
        guard range.length > 0 else { return }
        SecretClipboard.shared.copy((string as NSString).substring(with: range), sensitive: sensitive)
    }

    override func cut(_ sender: Any?) {
        guard isEditable else { return }
        copy(sender)
        if shouldChangeText(in: selectedRange(), replacementString: "") {
            textStorage?.replaceCharacters(in: selectedRange(), with: "")
            didChangeText()
        }
    }

    override func paste(_ sender: Any?) { pasteAsPlainText(sender) }

    override func validRequestor(
        forSendType sendType: NSPasteboard.PasteboardType?, returnType: NSPasteboard.PasteboardType?
    ) -> Any? { nil }

    override func dragSelection(with event: NSEvent, offset mouseOffset: NSSize, slideBack: Bool) -> Bool { false }

    override func menu(for event: NSEvent) -> NSMenu? { nil }
}

/// Writing Tools and inline predictions may hand editor contents to system text services.
@MainActor
func disableSystemTextAssistance(_ editor: NSTextView) {
    editor.inlinePredictionType = .no
    if #available(macOS 15.0, *) {
        editor.writingToolsBehavior = .none
    }
}
