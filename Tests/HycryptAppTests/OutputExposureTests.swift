import Foundation
import Testing

@testable import HycryptApp

struct OutputExposureTests {
    @Test func syncedPathsAreWarnedWithoutANetworkCall() {
        #expect(OutputExposure.pathLooksSynced("/Users/me/Library/CloudStorage/Dropbox/secret"))
        #expect(OutputExposure.pathLooksSynced("/Users/me/Library/Mobile Documents/com~apple~CloudDocs/Desktop"))
        #expect(!OutputExposure.pathLooksSynced("/Users/me/Documents/local"))
        #expect(OutputExposure.mayLeaveThisMac(URL(fileURLWithPath: "/Users/me/Library/CloudStorage/Dropbox")))
        #expect(OutputExposure.decryptWarning(for: nil) == nil)
        #expect(
            OutputExposure.decryptWarning(for: URL(fileURLWithPath: "/Users/me/Library/CloudStorage/Dropbox"))
                != nil)
    }

}
