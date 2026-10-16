import AppKit
import HycryptCore

/// Native UI side effects stay outside the observable workspace and cryptographic services.
@MainActor
final class MacFileActions {
    private var isPresenting = false

    func chooseSource(for operation: CryptOperation) async -> URL? {
        let panel = NSOpenPanel()
        panel.title = operation == .encrypt ? "选择要加密的文件或文件夹" : "选择要解密的文件"
        panel.canChooseDirectories = operation == .encrypt
        panel.canChooseFiles = true
        return await present(panel)
    }

    func chooseOutputDirectory(initial: URL?) async -> URL? {
        let panel = NSOpenPanel()
        panel.title = "选择保存位置"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = initial
        return await present(panel)
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func present(_ panel: NSOpenPanel) async -> URL? {
        guard !isPresenting else { return nil }
        isPresenting = true
        defer { isPresenting = false }
        panel.allowsMultipleSelection = false
        let response = await withCheckedContinuation { continuation in
            // Standalone presentation also works from the compact Settings window;
            // sandboxed remote sheets can receive invalid geometry on newer AppKit.
            panel.begin { continuation.resume(returning: $0) }
        }
        return response == .OK ? panel.url : nil
    }
}
