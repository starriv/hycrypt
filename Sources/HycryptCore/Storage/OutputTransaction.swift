import Darwin
import Foundation

/// Owns a private staging directory on the destination volume and publishes without replacement.
/// Same-volume destinations use a stable app-temp staging root (`hycrypt-staging`); other volumes
/// use a descriptor-owned itemReplacementDirectory probe. Staging is never inside the selected
/// folder, so a cloud-synced Desktop, Documents or Dropbox folder cannot upload in-progress
/// plaintext. A live transaction holds an exclusive flock; directories left by a crashed process
/// are unlocked and removed by the next transaction in the same staging root.
final class OutputTransaction {
    static let stagingPrefix = ".hycrypt-"
    /// Covers the window between creating a staging directory and locking it.
    static let staleAge: TimeInterval = 60

    let directory: URL
    let destination: URL
    private let parent: URL
    private let parentFD: Int32
    private let stagingParent: URL
    private let stagingParentFD: Int32
    private let directoryFD: Int32
    private let stagingName: String
    private let removeParentOnCleanup: Bool

    init(destination: URL) throws {
        let destination = destination.standardizedFileURL
        var info = stat()
        guard lstat(destination.path, &info) != 0 else { throw HycryptError.destinationExists }
        guard errno == ENOENT else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let parent = destination.deletingLastPathComponent().resolvingSymlinksInPath()
        let parentFD = open(parent.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parentFD >= 0 else { throw POSIXError(.EACCES) }
        let staging: Staging
        do {
            staging = try Self.createStaging(appropriateFor: destination, destinationParent: parent)
        } catch {
            close(parentFD)
            throw error
        }
        self.destination = destination
        self.parent = parent
        self.parentFD = parentFD
        stagingParent = staging.parent
        stagingParentFD = staging.parentFD
        directory = staging.directory
        directoryFD = staging.directoryFD
        stagingName = staging.name
        removeParentOnCleanup = staging.removeParentOnCleanup
        var excluded = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? excluded.setResourceValues(values)
    }

    deinit {
        close(directoryFD)
        close(stagingParentFD)
        close(parentFD)
    }

    /// True when intermediate plaintext must not be created on the destination volume.
    /// A missing, remote or cloud-synced destination fails closed to local scratch.
    static func plaintextMustStayLocal(relativeTo destination: URL) -> Bool {
        OutputLocation.plaintextMustStayLocal(relativeTo: destination)
    }

    static let scratchPrefix = "hycrypt-scratch-"

    /// Owns a local plaintext scratch directory and its lock. remove() releases the lock and
    /// deletes the tree; a crash releases the lock, so the next makeLocalScratch can reclaim it.
    final class LocalScratch {
        let directory: URL
        private var lockFD: Int32

        init(directory: URL, lockFD: Int32) {
            self.directory = directory
            self.lockFD = lockFD
        }

        func remove() {
            guard lockFD >= 0 else { return }
            close(lockFD)
            lockFD = -1
            OutputTransaction.removePrivateDirectory(at: directory)
        }

        deinit {
            if lockFD >= 0 { close(lockFD) }
        }
    }

    static func makeLocalScratch() throws -> LocalScratch {
        removeAbandonedScratch()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            scratchPrefix + UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        } catch {
            throw HycryptError.stagingUnavailable
        }
        let lockFD = open(
            root.appendingPathComponent(".lock").path,
            O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
            if lockFD >= 0 { close(lockFD) }
            try? FileManager.default.removeItem(at: root)
            throw HycryptError.stagingUnavailable
        }
        var excluded = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? excluded.setResourceValues(values)
        return LocalScratch(directory: root, lockFD: lockFD)
    }

    /// Reclaims local plaintext scratch directories left by a crashed process. A live scratch
    /// holds an exclusive lock on its .lock file, so it is never removed.
    static func removeAbandonedScratch(now: Date = Date()) {
        let parent = FileManager.default.temporaryDirectory
        let parentFD = open(parent.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parentFD >= 0 else { return }
        defer { close(parentFD) }
        let names = childNames(parentFD).filter { name in
            name.hasPrefix(scratchPrefix)
                && UUID(uuidString: String(name.dropFirst(scratchPrefix.count))) != nil
        }
        for name in names {
            name.withCString { cName in
                let directoryFD = openat(parentFD, cName, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                guard directoryFD >= 0 else { return }
                defer { close(directoryFD) }
                var info = stat()
                guard fstat(directoryFD, &info) == 0, info.st_uid == getuid(), isStale(info, now: now)
                else { return }
                let lockFD = openat(directoryFD, ".lock", O_RDWR | O_NOFOLLOW | O_CLOEXEC)
                if lockFD >= 0 {
                    let locked = flock(lockFD, LOCK_EX | LOCK_NB) == 0
                    if locked {
                        removeTree(directoryFD)
                        if sameInode(directoryFD, parentFD, cName) {
                            _ = unlinkat(parentFD, cName, AT_REMOVEDIR)
                        }
                    }
                    close(lockFD)
                } else if flock(directoryFD, LOCK_EX | LOCK_NB) == 0 {
                    // Legacy scratch directory without a .lock file.
                    removeTree(directoryFD)
                    if sameInode(directoryFD, parentFD, cName) {
                        _ = unlinkat(parentFD, cName, AT_REMOVEDIR)
                    }
                }
            }
        }
    }

    static func removePrivateDirectory(at url: URL) {
        let parent = url.deletingLastPathComponent().resolvingSymlinksInPath()
        let parentFD = open(parent.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parentFD >= 0 else { return }
        defer { close(parentFD) }
        url.lastPathComponent.withCString { name in
            let fd = openat(parentFD, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard fd >= 0 else { return }
            defer { close(fd) }
            guard sameInode(fd, parentFD, name) else { return }
            removeTree(fd)
            guard sameInode(fd, parentFD, name) else { return }
            _ = unlinkat(parentFD, name, AT_REMOVEDIR)
        }
    }

    func commit(_ result: URL) throws -> URL {
        try Task.checkCancellation()
        guard sameDirectory(parentFD, at: parent), sameDirectory(directoryFD, at: directory),
            sameDirectory(stagingParentFD, at: stagingParent),
            destination.deletingLastPathComponent().resolvingSymlinksInPath() == parent,
            result.path.hasPrefix(directory.path + "/")
        else { throw HycryptError.invalidSource }
        let relative = String(result.path.dropFirst(directory.path.count + 1))
        guard !relative.split(separator: "/").contains("..") else { throw HycryptError.invalidSource }
        var resultInfo = stat()
        guard relative.withCString({ fstatat(directoryFD, $0, &resultInfo, AT_SYMLINK_NOFOLLOW) }) == 0
        else { throw HycryptError.invalidSource }
        let resultType = resultInfo.st_mode & S_IFMT
        guard resultType == S_IFREG || resultType == S_IFDIR else { throw HycryptError.invalidSource }
        guard
            renameatx_np(
                directoryFD, relative, parentFD, destination.lastPathComponent, UInt32(RENAME_EXCL)
            ) == 0
        else {
            if errno == EEXIST { throw HycryptError.destinationExists }
            if errno == EXDEV { throw HycryptError.stagingUnavailable }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        // Publication already succeeded: never report cancellation after this point.
        _ = fsync(parentFD)
        return destination
    }

    func cleanUp() {
        guard sameDirectory(parentFD, at: parent), sameDirectory(directoryFD, at: directory),
            sameDirectory(stagingParentFD, at: stagingParent)
        else { return }
        Self.removeTree(directoryFD)
        stagingName.withCString { name in
            guard Self.sameInode(directoryFD, stagingParentFD, name) else { return }
            _ = unlinkat(stagingParentFD, name, AT_REMOVEDIR)
        }
        if removeParentOnCleanup {
            try? FileManager.default.removeItem(at: stagingParent)
        }
    }

    /// Best effort: plaintext staging from an interrupted run must not persist indefinitely.
    static func removeAbandonedStaging(in parentFD: Int32, now: Date = Date()) {
        let names = childNames(parentFD).filter { name in
            name.hasPrefix(stagingPrefix) && UUID(uuidString: String(name.dropFirst(stagingPrefix.count))) != nil
        }
        for name in names {
            name.withCString { cName in
                let fd = openat(parentFD, cName, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                guard fd >= 0 else { return }
                defer { close(fd) }
                var info = stat()
                guard fstat(fd, &info) == 0, info.st_uid == getuid(), isStale(info, now: now),
                    flock(fd, LOCK_EX | LOCK_NB) == 0, sameInode(fd, parentFD, cName)
                else { return }
                removeTree(fd)
                guard sameInode(fd, parentFD, cName) else { return }
                _ = unlinkat(parentFD, cName, AT_REMOVEDIR)
            }
        }
    }

    private struct Staging {
        let parent: URL
        let parentFD: Int32
        let directory: URL
        let directoryFD: Int32
        let name: String
        let removeParentOnCleanup: Bool
    }

    private static func createStaging(appropriateFor destination: URL, destinationParent: URL) throws -> Staging {
        // Prefer a stable private root in the app temporary directory when it lives on the
        // destination volume. This avoids the per-volume TemporaryItems directory: on macOS 26,
        // open(2) on that directory returns EPERM, which made every transaction fail with
        // stagingUnavailable. A stable root also lets the next transaction reclaim abandoned
        // staging directories.
        if sameVolume(FileManager.default.temporaryDirectory, destinationParent) {
            if let root = try? stableStagingRoot(),
                let staging = try? makeStaging(
                    in: root, removeParentOnCleanup: false, selected: destinationParent)
            {
                return staging
            }
        }
        // Other volumes: use the system replacement directory, but use the probe directory
        // itself as the staging parent. Its parent may be a protected TemporaryItems directory.
        let probe: URL
        do {
            probe = try FileManager.default.url(
                for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: destination, create: true)
        } catch {
            throw HycryptError.stagingUnavailable
        }
        let resolved = probe.resolvingSymlinksInPath()
        // Prefer the probe's parent when it is openable: that preserves cross-run
        // removeAbandonedStaging. On macOS 26 the system volume's TemporaryItems parent is
        // protected (EPERM), so fall back to using the probe directory itself.
        let parent = resolved.deletingLastPathComponent()
        if let staging = try? makeStaging(
            in: parent, removeParentOnCleanup: false, selected: destinationParent)
        {
            try? FileManager.default.removeItem(at: resolved)
            return staging
        }
        do {
            return try makeStaging(in: resolved, removeParentOnCleanup: true, selected: destinationParent)
        } catch {
            try? FileManager.default.removeItem(at: resolved)
            throw error
        }
    }

    private static func makeStaging(in root: URL, removeParentOnCleanup: Bool, selected: URL) throws -> Staging {
        let rootPath = root.resolvingSymlinksInPath().path
        let selectedPath = selected.resolvingSymlinksInPath().path
        guard rootPath != selectedPath, !rootPath.hasPrefix(selectedPath + "/") else {
            throw HycryptError.stagingUnavailable
        }
        let parentFD = open(rootPath, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parentFD >= 0 else { throw HycryptError.stagingUnavailable }
        removeAbandonedStaging(in: parentFD)
        let name = stagingPrefix + UUID().uuidString
        guard mkdirat(parentFD, name, 0o700) == 0 else {
            close(parentFD)
            throw HycryptError.stagingUnavailable
        }
        let directoryFD = openat(
            parentFD, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard directoryFD >= 0 else {
            _ = unlinkat(parentFD, name, AT_REMOVEDIR)
            close(parentFD)
            throw HycryptError.stagingUnavailable
        }
        guard flock(directoryFD, LOCK_EX | LOCK_NB) == 0 else {
            close(directoryFD)
            _ = unlinkat(parentFD, name, AT_REMOVEDIR)
            close(parentFD)
            throw HycryptError.stagingUnavailable
        }
        _ = fchmod(directoryFD, 0o700)
        return Staging(
            parent: root, parentFD: parentFD,
            directory: root.appendingPathComponent(name, isDirectory: true),
            directoryFD: directoryFD, name: name,
            removeParentOnCleanup: removeParentOnCleanup)
    }

    private static func stableStagingRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hycrypt-staging", isDirectory: true)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else { throw HycryptError.stagingUnavailable }
        } else {
            do {
                try FileManager.default.createDirectory(
                    at: root, withIntermediateDirectories: false,
                    attributes: [.posixPermissions: 0o700])
            } catch {
                throw HycryptError.stagingUnavailable
            }
        }
        var info = stat()
        guard lstat(root.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFDIR else {
            throw HycryptError.stagingUnavailable
        }
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: root.path)
        var excluded = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? excluded.setResourceValues(values)
        return root.resolvingSymlinksInPath()
    }

    private static func sameVolume(_ first: URL, _ second: URL) -> Bool {
        var firstInfo = stat()
        var secondInfo = stat()
        guard lstat(first.path, &firstInfo) == 0, lstat(second.path, &secondInfo) == 0 else {
            return false
        }
        return firstInfo.st_dev == secondInfo.st_dev
    }

    private static func isStale(_ info: stat, now: Date) -> Bool {
        let birth = info.st_birthtimespec.tv_sec
        let stamp = birth > 0 ? birth : info.st_mtimespec.tv_sec
        return now.timeIntervalSince1970 - TimeInterval(stamp) >= staleAge
    }

    private static func sameInode(_ fd: Int32, _ parentFD: Int32, _ name: UnsafePointer<CChar>) -> Bool {
        var opened = stat()
        var current = stat()
        return fstat(fd, &opened) == 0
            && fstatat(parentFD, name, &current, AT_SYMLINK_NOFOLLOW) == 0
            && opened.st_dev == current.st_dev && opened.st_ino == current.st_ino
    }

    private struct RemovalFrame {
        let fd: Int32
        let owned: Bool
        let parentFD: Int32
        let name: String?
        let names: [String]
        var index: Int
    }

    /// Deletes directory entries through already-opened descriptors without following links.
    /// Iterative post-order traversal avoids stack overflow on deeply nested staging trees.
    private static func removeTree(_ directory: Int32) {
        var stack = [
            RemovalFrame(
                fd: directory, owned: false, parentFD: -1, name: nil,
                names: childNames(directory), index: 0)
        ]
        while !stack.isEmpty {
            let top = stack.count - 1
            if stack[top].index >= stack[top].names.count {
                let frame = stack.removeLast()
                if frame.owned { close(frame.fd) }
                if let name = frame.name, frame.parentFD >= 0 {
                    _ = name.withCString { unlinkat(frame.parentFD, $0, AT_REMOVEDIR) }
                }
                continue
            }
            let name = stack[top].names[stack[top].index]
            stack[top].index += 1
            let parentFD = stack[top].fd
            name.withCString { cName in
                var info = stat()
                guard fstatat(parentFD, cName, &info, AT_SYMLINK_NOFOLLOW) == 0 else { return }
                if (info.st_mode & S_IFMT) == S_IFDIR {
                    let child = openat(parentFD, cName, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                    if child >= 0 {
                        stack.append(
                            RemovalFrame(
                                fd: child, owned: true, parentFD: parentFD, name: name,
                                names: childNames(child), index: 0))
                    } else {
                        _ = unlinkat(parentFD, cName, AT_REMOVEDIR)
                    }
                } else {
                    _ = unlinkat(parentFD, cName, 0)
                }
            }
        }
    }

    private static func childNames(_ directory: Int32) -> [String] {
        let duplicate = dup(directory)
        guard duplicate >= 0, let stream = fdopendir(duplicate) else {
            if duplicate >= 0 { close(duplicate) }
            return []
        }
        defer { closedir(stream) }
        var names: [String] = []
        while let entry = readdir(stream) {
            let name = withUnsafeBytes(of: entry.pointee.d_name) { raw in
                String(decoding: raw.prefix(Int(entry.pointee.d_namlen)), as: UTF8.self)
            }
            if name != "." && name != ".." { names.append(name) }
        }
        return names
    }

    private func sameDirectory(_ fd: Int32, at url: URL) -> Bool {
        var opened = stat()
        var current = stat()
        return fstat(fd, &opened) == 0 && lstat(url.path, &current) == 0
            && (current.st_mode & S_IFMT) == S_IFDIR
            && opened.st_dev == current.st_dev && opened.st_ino == current.st_ino
    }
}
