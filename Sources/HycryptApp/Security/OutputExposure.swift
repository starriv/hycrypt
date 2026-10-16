import Foundation

/// Detects destinations whose published files can leave this Mac without the app using the network.
enum OutputExposure {
    static func mayLeaveThisMac(_ url: URL) -> Bool {
        let probe = url.resolvingSymlinksInPath()
        if pathLooksSynced(probe.path) { return true }
        let values = try? probe.resourceValues(forKeys: [.isUbiquitousItemKey, .volumeIsLocalKey])
        if values?.isUbiquitousItem == true { return true }
        if values?.volumeIsLocal == false { return true }
        return false
    }

    static func decryptWarning(for directory: URL?) -> String? {
        guard let directory, mayLeaveThisMac(directory) else { return nil }
        return "此保存位置会同步到其他设备或网络。解密得到的明文也会离开这台 Mac。"
    }

    static func pathLooksSynced(_ path: String) -> Bool {
        path.contains("/Library/CloudStorage/") || path.contains("/Mobile Documents/")
    }
}
