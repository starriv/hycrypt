import Foundation
import HycryptCore

/// Detects destinations whose published files can leave this Mac without the app using the network.
enum OutputExposure {
    static func mayLeaveThisMac(_ url: URL) -> Bool {
        OutputLocation.mayLeaveThisMac(url)
    }

    static func decryptWarning(for directory: URL?) -> String? {
        guard let directory, mayLeaveThisMac(directory) else { return nil }
        return "此保存位置会同步到其他设备或网络。解密得到的明文也会离开这台 Mac。"
    }

    static func directoryEncryptionWarning(for directory: URL?) -> String? {
        guard let directory, mayLeaveThisMac(directory) else { return nil }
        return "此保存位置会同步。目录加密的明文 ZIP 只在本机临时目录生成；崩溃或断电后可能残留。"
    }

    static func pathLooksSynced(_ path: String) -> Bool {
        OutputLocation.pathLooksSynced(path)
    }
}
