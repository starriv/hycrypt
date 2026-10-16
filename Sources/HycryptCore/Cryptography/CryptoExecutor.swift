/// Serializes public operations so concurrent callers cannot allocate multiple Argon2 workspaces.
actor CryptoExecutor {
    static let shared = CryptoExecutor()

    func run<Value: Sendable>(_ operation: @Sendable () throws -> Value) throws -> Value {
        try Task.checkCancellation()
        return try operation()
    }
}
