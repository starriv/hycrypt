import Foundation

/// A disposable defaults suite. cfprefsd keeps an empty plist after
/// `removePersistentDomain`, so cleanup also removes the backing file.
final class TemporaryDefaults {
    let suite: String
    let defaults: UserDefaults

    init(_ prefix: String) {
        suite = "hycrypt-\(prefix)-test-" + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)!
    }

    func remove() {
        defaults.removePersistentDomain(forName: suite)
        CFPreferencesAppSynchronize(suite as CFString)
        let file = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/\(suite).plist")
        try? FileManager.default.removeItem(at: file)
    }
}
