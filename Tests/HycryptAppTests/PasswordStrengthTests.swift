import Testing

@testable import HycryptApp

struct PasswordStrengthTests {
    @Test func emptyAndWeakPasswordsNeverShowStrong() {
        #expect(PasswordStrength("").level == 0)
        #expect(PasswordStrength("a").level == 1)
        #expect(PasswordStrength("short-A9!").level == 1)
        #expect(PasswordStrength(String(repeating: "x", count: 100)).level == 1)
        #expect(PasswordStrength(String(repeating: "长口令", count: 400)).level == 1)
    }

    @Test func lengthDoesNotRewardRepeatedOrCommonPatterns() {
        #expect(PasswordStrength(String(repeating: "abcd123!", count: 10)).level == 1)
        #expect(PasswordStrength("password-123456-ABCDEFGHIJKLMNOPQRSTUVWXYZ").level == 1)
    }

    @Test func longDistinctPhraseCanReachHigherEstimate() {
        #expect(PasswordStrength("river-cloud-fern!").level == 2)
        #expect(PasswordStrength("River! lantern 8 meadow pebble North").level == 4)
    }
}
