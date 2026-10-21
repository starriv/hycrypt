import SwiftUI

struct ContentView: View {
    let fileActions: MacFileActions
    @Bindable var model: WorkspaceModel
    @State private var syncWarning: String?

    init(model: WorkspaceModel, fileActions: MacFileActions) {
        self.model = model
        self.fileActions = fileActions
    }

    var body: some View {
        Group {
            if model.canAccessWindows {
                workspace
            } else {
                // Global gate: the workspace is unreachable until authentication succeeds.
                LockedView(authorization: model.authorization)
            }
        }
        .frame(minWidth: 760, minHeight: 620)
        .onAppear {
            // A fresh session opens directly; an existing locked session requests authentication.
            model.resume()
            updateSyncWarning()
        }
        .onOpenURL(perform: model.selectSource)
        .onChange(of: model.settings.outputPath) { _, _ in model.refreshOutputDirectory() }
        .onChange(of: model.isBusy) { _, isBusy in if !isBusy { model.refreshOutputDirectory() } }
        .onChange(of: model.canAccessWindows) { _, canAccess in if canAccess { model.applyPendingSource() } }
        .onChange(of: model.form.operation) { _, _ in updateSyncWarning() }
        .onChange(of: model.form.outputDirectory) { _, _ in updateSyncWarning() }
        .onChange(of: model.form.source) { _, _ in updateSyncWarning() }
        .onChange(of: model.inputKind) { _, _ in updateSyncWarning() }
        .focusedSceneValue(
            \.openSource, OpenSourceAction(isEnabled: !model.isBusy && model.canAccessWindows, perform: chooseSource)
        )
    }

    private var workspace: some View {
        NavigationSplitView {
            OperationSidebar(
                operation: model.form.operation, isBusy: model.isBusy,
                select: model.selectOperation
            )
            .navigationSplitViewColumnWidth(min: 175, ideal: 190, max: 240)
        } detail: {
            Form {
                Section {
                    Picker("处理内容", selection: Binding(get: { model.inputKind }, set: model.selectInputKind)) {
                        ForEach(WorkspaceModel.InputKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(model.isBusy)
                }
                if model.inputKind != .file {
                    TextOptions(operation: model.form.operation, kind: model.inputKind.textKind, model: model.text)
                } else {
                    SourcePicker(
                        source: model.form.source?.url, operation: model.form.operation,
                        isEnabled: !model.isBusy, choose: chooseSource, select: model.selectSource)
                    OutputOptions(
                        directory: model.form.outputDirectory, name: $model.form.outputName,
                        syncWarning: syncWarning,
                        choose: chooseOutput
                    )
                    .disabled(model.isBusy)
                    PasswordOptions(
                        operation: model.form.operation, password: $model.form.password,
                        confirmation: $model.form.confirmation
                    )
                    .disabled(model.isBusy)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("\(model.form.operation.title)\(model.inputKind.title)")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack(alignment: .center, spacing: 20) {
                    if model.inputKind != .file {
                        TextStatus(
                            state: model.text.state,
                            validationMessage: textValidationMessage
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        OperationActions(
                            operation: model.form.operation,
                            state: model.text.state == .cancelling
                                ? .cancelling : (model.text.state.isBusy ? .running(.init(.preparing)) : .idle),
                            canStart: model.canAccessWindows && textValidationMessage == nil,
                            start: {
                                if generatesMnemonic {
                                    model.text.generateMnemonic()
                                } else {
                                    model.text.start(model.form.operation, kind: model.inputKind.textKind)
                                }
                            },
                            cancel: model.text.cancel, title: generatesMnemonic ? "生成助记词" : nil)
                    } else {
                        OperationStatus(
                            state: model.state, validationMessage: model.form.validationIssue?.message,
                            reveal: fileActions.reveal
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        OperationActions(
                            operation: model.form.operation, state: model.state,
                            canStart: model.canAccessWindows && model.form.validationIssue == nil,
                            start: startFile, cancel: model.cancel)
                    }
                }
                .padding(20)
                .background(.bar)
                .overlay(alignment: .top) { Divider() }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("锁定", systemImage: "lock.fill") {
                    model.lockAndRequestAuthentication()
                }
                .help("立即锁定 Hycrypt 并请求系统认证")
            }
            ToolbarItem(placement: .primaryAction) {
                if model.inputKind == .file {
                    Button("打开", systemImage: "folder", action: chooseSource)
                        .disabled(model.isBusy || !model.canAccessWindows)
                        .help("打开文件或文件夹（⌘O）")
                }
            }
        }
    }

    private func updateSyncWarning() {
        guard model.inputKind == .file, let directory = model.form.outputDirectory else {
            syncWarning = nil
            return
        }
        switch model.form.operation {
        case .decrypt:
            syncWarning = OutputExposure.decryptWarning(for: directory)
        case .encrypt:
            syncWarning =
                model.form.source?.isDirectory == true
                ? OutputExposure.directoryEncryptionWarning(for: directory) : nil
        }
    }

    private func chooseSource() {
        guard !model.isBusy, model.canAccessWindows else { return }
        Task { @MainActor in
            if let url = await fileActions.chooseSource(for: model.form.operation) {
                model.selectSource(url)
            }
        }
    }

    private func chooseOutput() {
        guard !model.isBusy, model.canAccessWindows else { return }
        Task { @MainActor in
            if let url = await fileActions.chooseOutputDirectory(initial: model.form.outputDirectory) {
                model.selectOutputDirectory(url)
            }
        }
    }

    private func startFile() {
        guard !model.isBusy, model.canAccessWindows else { return }
        // A file-selection grant does not authorize writing its parent directory.
        if ApplicationSandbox.authorizationRequired && !model.hasOutputAuthorization {
            Task { @MainActor in
                if let url = await fileActions.chooseOutputDirectory(initial: model.form.outputDirectory) {
                    guard model.canAccessWindows else { return }
                    model.selectOutputDirectory(url)
                    model.start()
                }
            }
        } else {
            model.start()
        }
    }

    private var generatesMnemonic: Bool {
        model.inputKind == .mnemonic && model.form.operation == .encrypt
            && model.text.canGenerateMnemonic
    }

    private var textValidationMessage: String? {
        generatesMnemonic
            ? nil
            : model.text.validationMessage(for: model.form.operation, kind: model.inputKind.textKind)
    }

}

#if DEBUG
    #Preview("加密 · 浅色") {
        ContentView(
            model: WorkspaceModel(processor: PreviewFileProcessor(), authorization: nil), fileActions: MacFileActions()
        )
        .preferredColorScheme(.light)
    }

    #Preview("解密 · 深色") {
        let model = WorkspaceModel(processor: PreviewFileProcessor(), authorization: nil)
        model.selectOperation(.decrypt)
        return ContentView(model: model, fileActions: MacFileActions())
            .preferredColorScheme(.dark)
    }

    #Preview("最小窗口") {
        ContentView(
            model: WorkspaceModel(processor: PreviewFileProcessor(), authorization: nil), fileActions: MacFileActions()
        )
        .frame(width: 760, height: 620)
    }
#endif
