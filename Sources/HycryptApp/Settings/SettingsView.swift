import SwiftUI

struct SettingsSceneView: View {
    @Bindable var model: WorkspaceModel
    let fileActions: MacFileActions

    var body: some View {
        Group {
            if model.canAccessWindows {
                SettingsView(settings: model.settings, fileActions: fileActions) { model.canAccessWindows }
            } else {
                LockedView(authorization: model.authorization)
            }
        }
        .frame(minWidth: 520, minHeight: 380)
        .onAppear { model.resume() }
    }
}

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let fileActions: MacFileActions
    let canEdit: @MainActor () -> Bool

    var body: some View {
        Form {
            Section("启动") {
                Picker("默认输入", selection: $settings.defaultInput) {
                    ForEach(WorkspaceModel.InputKind.allCases) { kind in
                        Text(kind.title).tag(kind.rawValue)
                    }
                }
            }
            Section {
                LabeledContent("默认位置") {
                    VStack(alignment: .trailing, spacing: 8) {
                        if let error = settings.accessError { Text(error).foregroundStyle(.red) }
                        Text(settings.outputDirectory?.path ?? "与源文件相同的文件夹")
                            .lineLimit(2).truncationMode(.middle)
                            .foregroundStyle(.secondary)
                            .help(settings.outputPath)
                        if let directory = settings.outputDirectory, OutputExposure.mayLeaveThisMac(directory) {
                            Text("解密到此位置时，明文会随该文件夹同步到其他设备或网络。加密结果仍是密文。")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack {
                            if settings.outputDirectory != nil {
                                Button("使用源文件位置") { settings.outputPath = "" }
                            }
                            Button("选择文件夹…") {
                                Task { @MainActor in
                                    if let url = await fileActions.chooseOutputDirectory(
                                        initial: settings.outputDirectory)
                                    {
                                        guard canEdit() else { return }
                                        settings.selectOutputDirectory(url)
                                    }
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("文件输出")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 380)
        .navigationTitle("设置")
    }
}
