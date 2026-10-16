import Darwin
import Foundation

/// Owns a private staging directory on the destination volume and publishes without replacement.
/// Staging is created beside the destination volume's temporary area, never inside the folder the
/// user selected, so a cloud-synced Desktop, Documents or Dropbox folder cannot upload in-progress
/// plaintext. A live transaction holds an exclusive flock; directories left by a crashed process
/// are unlocked and removed by the next transaction on that volume.
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
    /// A missing or remote volume fails closed to local scratch.
    static func plaintextMustStayLocal(relativeTo destination: URL) -> Bool {
        let parent = destination.deletingLastPathComponent()
        guard let local = try? parent.resourceValues(forKeys: [.volumeIsLocalKey]).volumeIsLocal else {
            return true
        }
        return local == false
    }

    static func makeLocalScratch() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "hycrypt-scratch-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        var excluded = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? excluded.setResourceValues(values)
        return root
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
    }

    private static func createStaging(appropriateFor destination: URL, destinationParent: URL) throws -> Staging {
        let probe: URL
        do {
            probe = try FileManager.default.url(
                for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: destination, create: true)
        } catch {
            throw HycryptError.stagingUnavailable
        }
        let resolved = probe.resolvingSymlinksInPath()
        let parent = resolved.deletingLastPathComponent()
        let parentPath = parent.path
        let selected = destinationParent.resolvingSymlinksInPath().path
        guard parentPath != selected, !parentPath.hasPrefix(selected + "/") else {
            removePrivateDirectory(at: resolved)
            throw HycryptError.stagingUnavailable
        }
        let parentFD = open(parentPath, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parentFD >= 0 else {
            try? FileManager.default.removeItem(at: probe)
            throw HycryptError.stagingUnavailable
        }
        resolved.lastPathComponent.withCString { name in
            let probeFD = openat(parentFD, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            if probeFD >= 0 {
                if sameInode(probeFD, parentFD, name) {
                    removeTree(probeFD)
                    _ = unlinkat(parentFD, name, AT_REMOVEDIR)
                }
                close(probeFD)
            }
        }
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
            parent: parent, parentFD: parentFD,
            directory: parent.appendingPathComponent(name, isDirectory: true),
            directoryFD: directoryFD, name: name)
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

    /// Deletes directory entries through the already-opened descriptor. Does not follow links.
    private static func removeTree(_ directory: Int32) {
        for name in childNames(directory) where name != "." && name != ".." {
            name.withCString { cName in
                var info = stat()
                guard fstatat(directory, cName, &info, AT_SYMLINK_NOFOLLOW) == 0 else { return }
                if (info.st_mode & S_IFMT) == S_IFDIR {
                    let child = openat(directory, cName, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                    if child >= 0 {
                        removeTree(child)
                        close(child)
                    }
                    _ = unlinkat(directory, cName, AT_REMOVEDIR)
                } else {
                    _ = unlinkat(directory, cName, 0)
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
