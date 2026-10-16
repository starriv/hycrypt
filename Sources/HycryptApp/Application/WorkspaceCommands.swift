import SwiftUI

struct OpenSourceAction {
    let isEnabled: Bool
    let perform: () -> Void
}

private struct OpenSourceActionKey: FocusedValueKey {
    typealias Value = OpenSourceAction
}

extension FocusedValues {
    var openSource: OpenSourceAction? {
        get { self[OpenSourceActionKey.self] }
        set { self[OpenSourceActionKey.self] = newValue }
    }
}

struct WorkspaceCommands: Commands {
    let model: WorkspaceModel
    @FocusedValue(\.openSource) private var openSource

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("打开文件或文件夹…") { openSource?.perform() }
                .keyboardShortcut("o")
                .disabled(openSource?.isEnabled != true)
        }
        CommandGroup(after: .appInfo) {
            Divider()
            Button("锁定 Hycrypt") { model.lockAndRequestAuthentication() }
                .keyboardShortcut("l", modifiers: [.command, .option])
                .disabled(!model.canAccessWindows)
        }
    }
}
