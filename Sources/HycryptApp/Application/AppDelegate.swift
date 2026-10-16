import AppKit
import Darwin

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var workspace: WorkspaceModel?
    private var idleTimer: Timer?
    private var eventMonitor: Any?
    private var lastActivity = ProcessInfo.processInfo.systemUptime

    func applicationDidFinishLaunching(_ notification: Notification) {
        denyDebuggerAttach()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let center = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification,
        ] {
            center.addObserver(self, selector: #selector(lockSession), name: name, object: nil)
        }
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(lockSession), name: .init("com.apple.screenIsLocked"), object: nil)
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(resumeAfterScreenUnlock), name: .init("com.apple.screenIsUnlocked"), object: nil)
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [
            .keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel,
        ]) { [weak self] event in
            self?.lastActivity = ProcessInfo.processInfo.systemUptime
            // An idle lock can happen while the window stays active. The first new
            // interaction requests authentication without requiring a specific button.
            if NSApp.isActive, self?.workspace?.isAuthorized == false { self?.workspace?.resume() }
            return event
        }
        idleTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, NSApp.isActive, workspace?.canAccessWindows == true,
                    ProcessInfo.processInfo.systemUptime - lastActivity >= 120
                else { return }
                lockSession()
            }
        }
    }

    func applicationDidResignActive(_ notification: Notification) {
        workspace?.conceal()
        SecretClipboard.shared.clear()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        lastActivity = ProcessInfo.processInfo.systemUptime
        workspace?.resume()
    }

    @objc private func resumeAfterScreenUnlock() {
        guard NSApp.isActive else { return }
        lastActivity = ProcessInfo.processInfo.systemUptime
        workspace?.resume()
    }

    @objc private func lockSession() {
        workspace?.lock()
        lastActivity = ProcessInfo.processInfo.systemUptime
    }

    func applicationWillTerminate(_ notification: Notification) {
        lockSession()
        idleTimer?.invalidate()
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard workspace?.isBusy == true else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "内容正在处理中"
        alert.informativeText = "请先取消当前操作，等待操作结束后再退出。"
        alert.addButton(withTitle: "返回")
        alert.runModal()
        return .terminateCancel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Refuse debugger attachment and detect dynamic library injection.
    private func denyDebuggerAttach() {
        #if !DEBUG
            // PT_DENY_ATTACH = 31; ptrace is not exposed in Swift's Darwin module.
            // Use syscall(SYS_ptrace, PT_DENY_ATTACH, 0, 0, 0) directly.
            typealias PtraceFn = @convention(c) (Int32, pid_t, UnsafeMutableRawPointer?, Int32) -> Int32
            if let lib = dlopen(nil, RTLD_NOW),
                let sym = dlsym(lib, "ptrace")
            {
                let ptrace = unsafeBitCast(sym, to: PtraceFn.self)
                _ = ptrace(31, 0, nil, 0)  // PT_DENY_ATTACH
                dlclose(lib)
            }
            if getenv("DYLD_INSERT_LIBRARIES") != nil {
                NSLog("DYLD_INSERT_LIBRARIES detected; terminating.")
                exit(1)
            }
        #endif
    }
}
