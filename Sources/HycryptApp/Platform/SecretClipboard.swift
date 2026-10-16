import AppKit

@MainActor
final class SecretClipboard {
    static let shared = SecretClipboard()
    private let pasteboard: NSPasteboard
    private var ownedChange: Int?
    private var expiration: Task<Void, Never>?

    init(pasteboard: NSPasteboard = .general) { self.pasteboard = pasteboard }

    func copy(_ text: String, sensitive: Bool) {
        clear()
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        if sensitive {
            item.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
            item.setData(Data(), forType: .init("org.nspasteboard.TransientType"))
        }
        pasteboard.prepareForNewContents(with: Self.contentsOptions(sensitive: sensitive))
        guard pasteboard.writeObjects([item]), sensitive else { return }
        ownedChange = pasteboard.changeCount
        expiration = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
            self?.clear()
        }
    }

    /// Concealed/transient markers do not stop Universal Clipboard; keep secrets on this Mac.
    nonisolated static func contentsOptions(sensitive: Bool) -> NSPasteboard.ContentsOptions {
        sensitive ? .currentHostOnly : []
    }

    func clear() {
        expiration?.cancel()
        expiration = nil
        if let ownedChange, pasteboard.changeCount == ownedChange { pasteboard.clearContents() }
        ownedChange = nil
    }

    deinit { expiration?.cancel() }
}
