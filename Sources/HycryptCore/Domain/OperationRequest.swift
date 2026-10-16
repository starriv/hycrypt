import Foundation

/// A value snapshot: changing a form cannot mutate an operation already in flight.
public struct OperationRequest: Sendable {
    public let operation: CryptOperation
    public let source: URL
    public let destination: URL
    public let password: SecretBytes

    public init(
        operation: CryptOperation, source: URL, destination: URL, password: SecretBytes
    ) {
        self.operation = operation
        self.source = source
        self.destination = destination
        self.password = password
    }
}
