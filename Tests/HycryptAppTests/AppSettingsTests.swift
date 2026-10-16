import Foundation
import Testing

@testable import HycryptApp

@MainActor
struct AppSettingsTests {
    @Test func persistenceAndSourceDirectoryFallback() throws {
        let temporary = TemporaryDefaults("settings")
        let defaults = temporary.defaults
        defer { temporary.remove() }
        let settings = AppSettings(defaults: defaults)
        let source = URL(fileURLWithPath: "/tmp/source/document.txt")
        #expect(settings.destinationDirectory(for: source).path == "/tmp/source")
        settings.defaultInput = "text"
        settings.outputPath = "/tmp/output"
        let restored = AppSettings(defaults: defaults)
        #expect(restored.defaultInput == "text")
        #expect(restored.destinationDirectory(for: source).path == "/tmp/output")
        restored.outputPath = ""
        #expect(restored.destinationDirectory(for: source).path == "/tmp/source")
        #expect(defaults.string(forKey: "password") == nil)
    }

    @Test func settingsDoNotChangeRunningRequestOrCompletedResult() async throws {
        let temporary = TemporaryDefaults("settings")
        let defaults = temporary.defaults
        defer { temporary.remove() }
        let settings = AppSettings(defaults: defaults)
        settings.defaultInput = "text"
        settings.outputPath = "/tmp/first"
        let processor = ControlledFileProcessor()
        let model = WorkspaceModel(processor: processor, settings: settings, authorization: nil)
        #expect(model.inputKind == .text)
        model.selectSource(URL(fileURLWithPath: "/tmp/document.txt"))
        #expect(model.inputKind == .file)
        #expect(model.form.outputDirectory?.path == "/tmp/first")
        model.form.password = "test-only-password-2026"
        model.form.confirmation = "test-only-password-2026"
        let task = model.start()
        await processor.waitUntilStarted()
        settings.outputPath = "/tmp/second"
        model.refreshOutputDirectory()
        #expect(model.form.outputDirectory?.path == "/tmp/first")
        let request = try #require(await processor.requests.first)
        #expect(request.destination.deletingLastPathComponent().path == "/tmp/first")
        await processor.complete(.success(request.destination))
        await task?.value
        model.refreshOutputDirectory()
        #expect(model.form.outputDirectory?.path == "/tmp/second")
        #expect(model.state == .succeeded(request.destination))
    }
}
