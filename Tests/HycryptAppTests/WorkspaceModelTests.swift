import Foundation
import HycryptCore
import Testing

@testable import HycryptApp

@Suite(.timeLimit(.minutes(1)))
@MainActor
struct WorkspaceModelTests {
    private func preparedModel(_ processor: ControlledFileProcessor) -> WorkspaceModel {
        let model = WorkspaceModel(processor: processor, authorization: nil)
        model.selectSource(URL(fileURLWithPath: "/tmp/report.txt"))
        model.form.password = "test-only-password-2026"
        model.form.confirmation = "test-only-password-2026"
        return model
    }

    @Test func selectionAndModeUpdateOutputName() {
        let model = WorkspaceModel(processor: ControlledFileProcessor(), authorization: nil)
        #expect(model.form.validationIssue == .missingSource)
        model.selectSource(URL(fileURLWithPath: "/tmp/report.txt"))
        #expect(model.form.operation == .encrypt)
        #expect(model.form.outputName == "report.txt.hycrypt")
        model.selectSource(URL(fileURLWithPath: "/tmp/report.txt.hycrypt"))
        #expect(model.form.operation == .decrypt)
        #expect(model.form.outputName == "report.txt")
        model.selectOperation(.encrypt)
        #expect(model.form.outputName == "report.txt.hycrypt.hycrypt")
        model.form.outputName = "custom"
        model.selectOperation(.encrypt)
        #expect(model.form.outputName == "custom")
    }

    @Test func nonFileURLsAreIgnored() {
        let model = WorkspaceModel(processor: ControlledFileProcessor(), authorization: nil)
        model.selectSource(URL(string: "https://example.com/file")!)
        model.selectOutputDirectory(URL(string: "https://example.com/folder")!)
        #expect(model.form.source == nil)
        #expect(model.form.outputDirectory == nil)
    }

    @Test func invalidFormCannotStart() {
        let model = WorkspaceModel(processor: ControlledFileProcessor(), authorization: nil)
        #expect(model.start() == nil)
        #expect(model.state == .idle)
    }

    @Test func successClearsSecretsAndIgnoresLateProgress() async throws {
        let processor = ControlledFileProcessor()
        let model = preparedModel(processor)
        let task = try #require(model.start())
        #expect(model.state.isBusy)
        #expect(model.form.password.isEmpty && model.form.confirmation.isEmpty)
        await processor.waitUntilStarted()
        let request = try #require(await processor.requests.first)
        #expect(request.password.withUnsafeBytes { String(decoding: $0, as: UTF8.self) } == "test-only-password-2026")
        await processor.emit(.init(.encrypting, fraction: 0.5))
        await processor.complete(.success(request.destination))
        await task.value
        await processor.emit(.init(.decrypting, fraction: 0.2))
        await Task.yield()
        #expect(model.state == .succeeded(request.destination))
        model.form.outputName = "next.hycrypt"
        #expect(model.state == .idle)
    }

    @Test func busyWorkspaceRejectsDuplicateStartAndSelectionChanges() async throws {
        let processor = ControlledFileProcessor()
        let model = preparedModel(processor)
        let task = try #require(model.start())
        await processor.waitUntilStarted()
        #expect(model.start() == nil)
        model.selectSource(URL(fileURLWithPath: "/tmp/other"))
        model.selectOperation(.decrypt)
        model.selectOutputDirectory(URL(fileURLWithPath: "/tmp/other-directory"))
        #expect(model.form.source?.url.path == "/tmp/report.txt")
        #expect(model.form.operation == .encrypt)
        #expect(model.form.outputDirectory?.path == "/tmp")
        #expect(await processor.requests.count == 1)
        model.cancel()
        await task.value
        #expect(model.state == .cancelled)
    }

    @Test func failureEndsBusyState() async throws {
        let processor = ControlledFileProcessor()
        let model = preparedModel(processor)
        let task = try #require(model.start())
        await processor.waitUntilStarted()
        await processor.complete(.failure(HycryptError.destinationExists))
        await task.value
        #expect(model.state == .failed(HycryptError.destinationExists.localizedDescription))
        #expect(!model.state.isBusy)
        #expect(model.form.password.isEmpty)
        model.cancel()
        #expect(model.state == .failed(HycryptError.destinationExists.localizedDescription))
    }

    @Test func cancelIsIdempotentAndPropagatesToProcessor() async throws {
        let processor = ControlledFileProcessor()
        let model = preparedModel(processor)
        model.cancel()
        #expect(model.state == .idle)
        let task = try #require(model.start())
        await processor.waitUntilStarted()
        model.cancel()
        model.cancel()
        #expect(model.state == .cancelling)
        await processor.emit(.init(.encrypting, fraction: 0.7))
        await task.value
        #expect(model.state == .cancelled)
        #expect(await processor.cancellations == 1)
    }

    @Test func oldOperationCannotUpdateANewOperation() async throws {
        let processor = ControlledFileProcessor()
        let model = preparedModel(processor)
        let first = try #require(model.start())
        await processor.waitUntilStarted()
        let output = URL(fileURLWithPath: "/tmp/first.hycrypt")
        await processor.complete(.success(output))
        await first.value
        model.form.password = "second-test-password-2026"
        model.form.confirmation = "second-test-password-2026"
        let second = try #require(model.start())
        await processor.waitUntilStarted()
        await processor.emit(.init(.encrypting, fraction: 0.99), invocation: 0)
        await Task.yield()
        #expect(model.state == .running(.init(.preparing)))
        model.cancel()
        await second.value
    }

    @Test func formEditsDoNotMutateCapturedRequest() async throws {
        let processor = ControlledFileProcessor()
        let model = preparedModel(processor)
        let task = try #require(model.start())
        model.form.outputName = "edited.hycrypt"
        await processor.waitUntilStarted()
        let request = try #require(await processor.requests.first)
        #expect(request.destination.lastPathComponent == "report.txt.hycrypt")
        #expect(model.state.isBusy)
        await processor.complete(.success(request.destination))
        await task.value
        #expect(model.state == .succeeded(request.destination))
    }

    @Test func releasingWorkspaceCancelsItsOwnedTask() async throws {
        let processor = ControlledFileProcessor()
        var model: WorkspaceModel? = preparedModel(processor)
        let weakModel = WeakWorkspace(model)
        let task = try #require(model?.start())
        await processor.waitUntilStarted()
        model = nil
        #expect(weakModel.value == nil)
        await task.value
        #expect(await processor.cancellations == 1)
    }

    @Test func immediateCancellationFinishesWithoutHanging() async throws {
        let model = preparedModel(ControlledFileProcessor())
        let task = try #require(model.start())
        model.cancel()
        await task.value
        #expect(model.state == .cancelled)
    }
}

@MainActor
private final class WeakWorkspace {
    weak var value: WorkspaceModel?

    init(_ value: WorkspaceModel?) {
        self.value = value
    }
}
