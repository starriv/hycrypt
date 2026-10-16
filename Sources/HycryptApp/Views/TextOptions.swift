import AppKit
import HycryptCore
import SwiftUI

struct TextOptions: View {
    let operation: CryptOperation
    var kind: SecretPolicy.TextKind = .text
    @Bindable var model: TextWorkspace
    @State private var passwordFocusRequest = 0

    var body: some View {
        Section(operation == .encrypt ? (kind == .mnemonic ? "助记词" : "原文") : "密文") {
            if kind == .mnemonic && operation == .encrypt {
                if model.hasGeneratedMnemonic {
                    Text("悬停单词格查看，移开即隐藏。按编号从左到右、逐行抄写。锁屏或 2 分钟无操作会清除，请及时备份并加密。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                MnemonicGrid(
                    draft: $model.mnemonic, enabled: !model.state.isBusy,
                    readOnly: model.hasGeneratedMnemonic
                ) { passwordFocusRequest += 1 }
                if model.hasGeneratedMnemonic {
                    Toggle("我已按顺序抄写并核对 24 个单词", isOn: $model.backupConfirmed)
                        .disabled(model.state.isBusy)
                    Text("查看期间屏幕内容可能被截屏或录屏。助记词不会自动复制或保存。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                SecretEditor(
                    text: $model.input, sensitive: operation == .encrypt,
                    maximumBytes: operation == .encrypt ? kind.maximumBytes : TextCipher.maximumEncodedBytes,
                    enabled: !model.state.isBusy
                )
                .frame(minHeight: 150, maxHeight: 240)
                .accessibilityLabel(operation == .encrypt ? "待加密文本" : "待解密密文")
                .disabled(model.state.isBusy)
            }
        }
        PasswordOptions(
            operation: operation, password: $model.password, confirmation: $model.confirmation,
            focusRequest: passwordFocusRequest
        )
        .disabled(model.state.isBusy)
        if case .succeeded(let result) = model.state {
            Section(operation == .encrypt ? "加密结果" : "解密结果") {
                ScrollView {
                    if operation == .encrypt || model.isRevealed {
                        Text(result.isEmpty ? "（空文本）" : result)
                            .font(.body.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                    } else {
                        Text("••••••••")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(minHeight: 150, maxHeight: 240)
                .accessibilityLabel("处理结果，只读")
                HStack {
                    if operation == .decrypt {
                        Button(model.isRevealed ? "隐藏" : "显示", systemImage: model.isRevealed ? "eye.slash" : "eye") {
                            if model.isRevealed { model.conceal() } else { model.reveal() }
                        }
                    }
                    Button("复制", systemImage: "doc.on.doc") {
                        SecretClipboard.shared.copy(result, sensitive: operation == .decrypt)
                    }
                    .disabled(operation == .decrypt && !model.isRevealed)
                }
            }
        }
    }
}

struct TextStatus: View {
    let state: TextWorkspace.State
    let validationMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch state {
            case .idle: Text(validationMessage ?? "准备就绪")
            case .running, .cancelling:
                ProgressView().controlSize(.small)
                Text(state == .cancelling ? "正在取消，请等待密钥派生结束…" : "正在处理文本…")
            case .succeeded: Label("处理完成", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
            case .cancelled: Text("已取消")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
