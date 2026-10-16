import HycryptCore
import SwiftUI

@main
struct HycryptApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var workspace: WorkspaceModel
    private let fileActions = MacFileActions()

    init() {
        _workspace = State(
            initialValue: WorkspaceModel(processor: HycryptService()))
    }

    var body: some Scene {
        Window("Hycrypt", id: "main") {
            ContentView(model: workspace, fileActions: fileActions)
                .onAppear { delegate.workspace = workspace }
        }
        .defaultSize(width: 900, height: 720)
        .windowToolbarStyle(.unified)
        .commands { WorkspaceCommands(model: workspace) }

        Settings {
            SettingsSceneView(model: workspace, fileActions: fileActions)
                .onAppear { delegate.workspace = workspace }
        }
    }
}
