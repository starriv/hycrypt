import Foundation
import XCTest

@testable import HycryptCore

final class OutputLocationTests: XCTestCase {
    func testSyncedPathHeuristics() {
        XCTAssertTrue(OutputLocation.pathLooksSynced("/Users/me/Library/CloudStorage/Dropbox/secret"))
        XCTAssertTrue(OutputLocation.pathLooksSynced("/Users/me/Library/Mobile Documents/com~apple~CloudDocs/file"))
        XCTAssertFalse(OutputLocation.pathLooksSynced("/Users/me/Documents/local"))
        XCTAssertTrue(OutputLocation.mayLeaveThisMac(URL(fileURLWithPath: "/Users/me/Library/CloudStorage/Dropbox")))
    }

    func testPlaintextStagingFailsClosedForCloudAndUnknownPaths() throws {
        let local = FileManager.default.temporaryDirectory
            .appendingPathComponent("hycrypt-policy-" + UUID().uuidString)
        try FileManager.default.createDirectory(
            at: local, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: local) }
        XCTAssertFalse(
            OutputLocation.plaintextMustStayLocal(relativeTo: local.appendingPathComponent("out")))
        XCTAssertTrue(
            OutputLocation.plaintextMustStayLocal(
                relativeTo: URL(fileURLWithPath: "/Users/me/Library/CloudStorage/Dropbox/out")))
        XCTAssertTrue(
            OutputLocation.plaintextMustStayLocal(
                relativeTo: URL(fileURLWithPath: "/nonexistent/hycrypt/out")))
    }
}
