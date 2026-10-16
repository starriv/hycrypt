import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    var defaultInput: String {
        didSet { defaults.set(defaultInput, forKey: "defaultInput") }
    }
    var outputPath: String {
        didSet {
            defaults.set(outputPath, forKey: "outputPath")
            defaults.removeObject(forKey: "outputBookmark")
            outputAccess = nil
            accessError = nil
        }
    }
    private(set) var outputAccess: SecurityScopedAccess?
    private(set) var accessError: String?
    @ObservationIgnored private let sandboxed: Bool

    func selectOutputDirectory(_ url: URL) {
        let access = SecurityScopedAccess(url)
        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            outputPath = url.path
            defaults.set(bookmark, forKey: "outputBookmark")
            outputAccess = access
            accessError = nil
        } catch {
            accessError = "无法保存文件夹授权，请重新选择。"
        }
    }

    init(defaults: UserDefaults = .standard, sandboxed: Bool = ApplicationSandbox.isEnabled) {
        self.sandboxed = sandboxed
        self.defaults = defaults
        let storedInput = defaults.string(forKey: "defaultInput") ?? "file"
        defaultInput = ["file", "text", "mnemonic"].contains(storedInput) ? storedInput : "file"
        outputPath = defaults.string(forKey: "outputPath") ?? ""
        if let bookmark = defaults.data(forKey: "outputBookmark") {
            do {
                var stale = false
                let url = try URL(
                    resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI], relativeTo: nil,
                    bookmarkDataIsStale: &stale)
                let access = SecurityScopedAccess(url)
                guard !sandboxed || access.started else { throw CocoaError(.fileReadNoPermission) }
                outputAccess = access
                if stale {
                    let refreshed = try url.bookmarkData(
                        options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    defaults.set(refreshed, forKey: "outputBookmark")
                }
            } catch {
                outputAccess = nil
                accessError = "保存位置授权已失效，请重新选择。"
            }
        } else if sandboxed && !outputPath.isEmpty {
            accessError = "请重新授权保存位置。"
        }
    }

    var outputDirectory: URL? {
        if let outputAccess { return outputAccess.url }
        guard !sandboxed else { return nil }
        guard outputPath.hasPrefix("/") else { return nil }
        return URL(fileURLWithPath: outputPath, isDirectory: true)
    }

    func destinationDirectory(for source: URL) -> URL {
        outputDirectory ?? source.deletingLastPathComponent()
    }
}
