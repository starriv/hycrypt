import Foundation
import HycryptCore

struct SourceSelection: Equatable {
    let url: URL
    let isDirectory: Bool

    init(url: URL) {
        self.url = url
        // Read once when selecting; rendering and validation never perform filesystem I/O.
        isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}

struct OperationForm {
    private(set) var operation: CryptOperation = .encrypt
    private(set) var source: SourceSelection?
    private(set) var outputDirectory: URL?
    var outputName = ""
    var password = ""
    var confirmation = ""

    enum ValidationIssue: Error {
        case missingSource, directoryDecryption, missingOutputDirectory, invalidOutputName
        case emptyPassword, passwordMismatch, passwordWhitespace, passwordTooLong

        var message: String {
            switch self {
            case .missingSource: "选择一个文件或文件夹开始。"
            case .directoryDecryption: "解密时请选择 .hycrypt 文件。"
            case .missingOutputDirectory: "请选择保存位置。"
            case .invalidOutputName: "请输入有效的输出名称。"
            case .passwordWhitespace: HycryptError.passwordWhitespace.localizedDescription
            case .passwordTooLong: HycryptError.passwordTooLong.localizedDescription
            case .emptyPassword: "请输入密码。"
            case .passwordMismatch: "两次输入的密码不一致。"
            }
        }
    }

    var validationIssue: ValidationIssue? {
        guard let source else { return .missingSource }
        if operation == .decrypt && source.isDirectory { return .directoryDecryption }
        guard outputDirectory != nil else { return .missingOutputDirectory }
        if outputName.isEmpty || [".", ".."].contains(outputName)
            || outputName.hasPrefix("-")
            || outputName.contains(where: { "/:\0".contains($0) })
            || outputName.contains("..")
        {
            return .invalidOutputName
        }
        // Resolved path must stay inside the chosen output directory.
        if let outputDirectory {
            let resolved = outputDirectory.appendingPathComponent(outputName).standardizedFileURL
            guard resolved.deletingLastPathComponent() == outputDirectory.standardizedFileURL else {
                return .invalidOutputName
            }
        }
        let password = SecretPolicy.preparedPassword(password, operation: operation)
        let confirmation = SecretPolicy.preparedPassword(confirmation, operation: operation)
        if password.isEmpty { return .emptyPassword }
        do {
            try SecretPolicy.validatePassword(password, operation: operation)
        } catch let error as HycryptError {
            switch error {
            case .passwordWhitespace: return .passwordWhitespace
            case .passwordTooLong: return .passwordTooLong
            case .emptyPassword: return .emptyPassword
            default: return .emptyPassword
            }
        } catch {
            return .emptyPassword
        }
        if operation == .encrypt && password != confirmation { return .passwordMismatch }
        return nil
    }

    mutating func selectSource(_ url: URL) {
        source = SourceSelection(url: url)
        outputDirectory = url.deletingLastPathComponent()
        if url.pathExtension.lowercased() == "hycrypt" { operation = .decrypt }
        outputName = operation.suggestedOutputName(for: url)
    }

    mutating func selectOperation(_ operation: CryptOperation) {
        guard self.operation != operation else { return }
        self.operation = operation
        if let source { outputName = operation.suggestedOutputName(for: source.url) }
    }

    mutating func selectOutputDirectory(_ url: URL) {
        outputDirectory = url
    }

    mutating func clearPassword() {
        password = ""
        confirmation = ""
    }

    /// Converts the password to a secure buffer immediately; the String copy in this form
    /// is cleared by the caller right after this returns.
    func makeRequest() throws -> OperationRequest {
        if let issue = validationIssue { throw issue }
        guard let source, let outputDirectory else { throw ValidationIssue.missingSource }
        let securePassword = try SecretBytes(utf8: SecretPolicy.preparedPassword(password, operation: operation))
        return OperationRequest(
            operation: operation, source: source.url,
            destination: outputDirectory.appendingPathComponent(outputName), password: securePassword)
    }
}
