import Testing

@testable import HycryptApp

struct ApplicationSandboxTests {
    @Test func sandboxAuthorizationFailsClosedOnlyForUnknown() {
        #expect(ApplicationSandbox.authorizationRequired(for: .sandboxed))
        #expect(!ApplicationSandbox.authorizationRequired(for: .notSandboxed))
        #expect(ApplicationSandbox.authorizationRequired(for: .unknown))
    }
}
