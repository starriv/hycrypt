import Foundation

/// Shared policy for destinations that can leave this Mac without the app using the network,
/// and for deciding when intermediate plaintext must stay in local scratch.
public enum OutputLocation {
    /// Best-effort detection of cloud-synced paths that use the system File Provider layout.
    public static func pathLooksSynced(_ path: String) -> Bool {
        path.contains("/Library/CloudStorage/") || path.contains("/Mobile Documents/")
    }

    /// Advisory UI warning check. Unknown metadata does not force a warning.
    public static func mayLeaveThisMac(_ url: URL) -> Bool {
        let probe = url.resolvingSymlinksInPath()
        if pathLooksSynced(probe.path) { return true }
        let values = try? probe.resourceValues(forKeys: [.isUbiquitousItemKey, .volumeIsLocalKey])
        if values?.isUbiquitousItem == true { return true }
        if values?.volumeIsLocal == false { return true }
        return false
    }

    /// Staging policy. Unlike the advisory check, unknown metadata fails closed: if the app
    /// cannot prove the destination is local, plaintext must stay in local scratch.
    public static func plaintextMustStayLocal(relativeTo destination: URL) -> Bool {
        let parent = destination.deletingLastPathComponent()
        guard let values = try? parent.resourceValues(forKeys: [.isUbiquitousItemKey, .volumeIsLocalKey])
        else { return true }
        if values.isUbiquitousItem == true { return true }
        if values.volumeIsLocal == false { return true }
        return pathLooksSynced(parent.path)
    }
}
