#if DEBUG
    import Foundation
    import HycryptCore

    /// Interactive previews never read, encrypt or write real files.
    struct PreviewFileProcessor: FileProcessing {
        func process(_ request: OperationRequest, progress: @escaping ProgressHandler) async throws -> URL {
            progress(.init(.encrypting, fraction: 0.5))
            try await Task.sleep(for: .milliseconds(300))
            return request.destination
        }
    }
#endif
