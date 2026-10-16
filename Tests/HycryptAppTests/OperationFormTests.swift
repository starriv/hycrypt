import Foundation
import HycryptCore
import Testing

@testable import HycryptApp

struct OperationFormTests {
    @Test func whitespaceIsTrimmedOnlyForNewPasswords() throws {
        var form = OperationForm()
        form.selectSource(URL(fileURLWithPath: "/tmp/example.txt"))
        form.password = " \ta\n"
        form.confirmation = "a"
        let request = try form.makeRequest()
        #expect(request.password.withUnsafeBytes { String(decoding: $0, as: UTF8.self) } == "a")
        for value in ["a b", "a\tb", "a\nb", "a\u{00a0}b"] {
            form.password = value
            form.confirmation = value
            #expect(form.validationIssue == .passwordWhitespace)
        }
        form.password = " \n"
        #expect(form.validationIssue == .emptyPassword)
        form.selectOperation(.decrypt)
        form.password = " a b "
        let legacy = try form.makeRequest()
        #expect(legacy.password.withUnsafeBytes { String(decoding: $0, as: UTF8.self) } == " a b ")
    }

    @Test func confirmationAndOutputValidation() throws {
        var form = OperationForm()
        form.selectSource(URL(fileURLWithPath: "/tmp/report.txt"))
        #expect(form.validationIssue == .emptyPassword)
        form.password = "a"
        form.confirmation = "different"
        #expect(form.validationIssue == .passwordMismatch)
        form.confirmation = "a"
        #expect(form.validationIssue == nil)
        for name in ["", ".", "..", "../escape", "folder/file", "file:stream", "file\0"] {
            form.outputName = name
            #expect(form.validationIssue == .invalidOutputName)
            #expect(throws: OperationForm.ValidationIssue.self) { try form.makeRequest() }
        }
        form.outputName = "result.hycrypt"
        form.selectOperation(.decrypt)
        form.confirmation = ""
        #expect(form.validationIssue == nil)
    }

    @Test func secretsStayInRequestSnapshot() throws {
        var form = OperationForm()
        form.selectSource(URL(fileURLWithPath: "/tmp/file.hycrypt"))
        form.password = "test-only-password-2026"
        let request = try form.makeRequest()
        form.clearPassword()
        #expect(request.password.withUnsafeBytes { String(decoding: $0, as: UTF8.self) } == "test-only-password-2026")
        #expect(form.password.isEmpty && form.confirmation.isEmpty)
        form.password = "test-only-password-2026"
        form.confirmation = "test-only-password-2026"
        form.selectOperation(.encrypt)
        #expect(try form.makeRequest().operation == .encrypt)
        #expect(request.operation == .decrypt)
    }

    @Test func directoryDecryptionIsRejected() throws {
        var form = OperationForm()
        form.selectSource(FileManager.default.temporaryDirectory)
        form.selectOperation(.decrypt)
        #expect(form.validationIssue == .directoryDecryption)
    }

    @Test func validationDoesNotRepeatedlyReadSourceMetadata() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        var form = OperationForm()
        form.selectSource(folder)
        try FileManager.default.removeItem(at: folder)
        form.selectOperation(.decrypt)
        #expect(form.source?.isDirectory == true)
        #expect(form.validationIssue == .directoryDecryption)
        // The service performs authoritative validation again at execution time.
    }
}
