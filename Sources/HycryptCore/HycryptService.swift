import Foundation

public struct HycryptService: FileProcessing {
    public init() {}

    /// Keep blocking filesystem/KDF work off the caller's actor and propagate cancellation explicitly.
    public func process(_ request: OperationRequest, progress: @escaping ProgressHandler = { _ in }) async throws -> URL
    {
        let worker = Task.detached(priority: .userInitiated) {
            try await CryptoExecutor.shared.run { try Self.run(request, progress: progress) }
        }
        return try await withTaskCancellationHandler {
            if Task.isCancelled { worker.cancel() }
            return try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    /// Synchronous implementation stays internal; UI clients use the async protocol above.
    @discardableResult
    static func run(_ request: OperationRequest, progress: ProgressHandler = { _ in }) throws -> URL {
        try Task.checkCancellation()
        try SecretPolicy.validatePassword(request.password, operation: request.operation)
        let source = request.source.standardizedFileURL
        let destination = request.destination.standardizedFileURL
        let values = try source.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true,
            values.isRegularFile == true || (request.operation == .encrypt && values.isDirectory == true)
        else {
            throw HycryptError.invalidSource
        }
        let parent = destination.deletingLastPathComponent().resolvingSymlinksInPath()
        let resolvedSource = source.resolvingSymlinksInPath()
        if values.isDirectory == true,
            parent.path == resolvedSource.path || parent.path.hasPrefix(resolvedSource.path + "/")
        {
            throw HycryptError.outputInsideSource
        }
        let transaction = try OutputTransaction(destination: destination)
        defer { transaction.cleanUp() }
        let payload = transaction.directory.appendingPathComponent("payload")
        let remote = OutputTransaction.plaintextMustStayLocal(relativeTo: destination)
        var scratch: URL?
        defer { if let scratch { OutputTransaction.removePrivateDirectory(at: scratch) } }
        let result: URL
        switch request.operation {
        case .encrypt:
            var input = source
            if values.isDirectory == true {
                input = try Self.archiveURL(remote: remote, transaction: transaction, scratch: &scratch)
                try DirectoryArchive.pack(source: source, destination: input, progress: progress)
            }
            try FileCipher.encrypt(
                source: input, destination: payload, password: request.password,
                directory: values.isDirectory == true, progress: progress)
            result = payload
        case .decrypt:
            let declared = try FileCipher.declaredKind(of: source)
            let incoming: URL
            if declared == .directory && remote {
                incoming = try Self.archiveURL(remote: true, transaction: transaction, scratch: &scratch)
            } else {
                incoming = payload
            }
            let kind = try FileCipher.decrypt(
                source: source, destination: incoming, password: request.password, progress: progress)
            if kind == .directory {
                result = try DirectoryArchive.unpack(
                    source: incoming,
                    into: transaction.directory.appendingPathComponent("restored"), progress: progress)
            } else if incoming == payload {
                result = payload
            } else {
                try FileIO.copy(incoming, to: payload)
                result = payload
            }
        }
        try Task.checkCancellation()
        progress(.init(.saving))
        let output = try transaction.commit(result)
        progress(.init(.finished, fraction: 1))
        return output
    }

    /// Remote volumes keep the plaintext ZIP on local scratch. Local volumes use private same-volume staging,
    /// which is outside the selected folder.
    private static func archiveURL(remote: Bool, transaction: OutputTransaction, scratch: inout URL?) throws -> URL {
        if remote {
            let local = try OutputTransaction.makeLocalScratch()
            scratch = local
            return local.appendingPathComponent("archive.zip")
        }
        return transaction.directory.appendingPathComponent("archive.zip")
    }
}
