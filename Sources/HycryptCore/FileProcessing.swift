import Foundation

/// The only application-to-core dependency seam; implementations own their execution policy.
public protocol FileProcessing: Sendable {
    func process(_ request: OperationRequest, progress: @escaping ProgressHandler) async throws -> URL
}
