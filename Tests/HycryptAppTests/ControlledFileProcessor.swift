import Foundation
import HycryptCore

/// Suspends until the test completes/fails it. No disk I/O, sleeps, or Argon2 work in state tests.
actor ControlledFileProcessor: FileProcessing {
    private(set) var requests: [OperationRequest] = []
    private(set) var cancellations = 0
    private var handlers: [ProgressHandler] = []
    private var pending: CheckedContinuation<URL, any Error>?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    func process(_ request: OperationRequest, progress: @escaping ProgressHandler) async throws -> URL {
        try Task.checkCancellation()
        requests.append(request)
        handlers.append(progress)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending = continuation
                let waiters = startWaiters
                startWaiters.removeAll()
                for waiter in waiters { waiter.resume() }
            }
        } onCancel: {
            Task { await self.cancelPending() }
        }
    }

    func waitUntilStarted() async {
        if pending != nil { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func emit(_ update: OperationProgress, invocation: Int = 0) {
        handlers[invocation](update)
    }

    func complete(_ result: Result<URL, any Error>) {
        let continuation = pending
        pending = nil
        continuation?.resume(with: result)
    }

    private func cancelPending() {
        cancellations += 1
        complete(.failure(CancellationError()))
    }
}
