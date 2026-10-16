import HycryptCore
import SwiftUI

struct OperationActions: View {
    let operation: CryptOperation
    let state: OperationState
    let canStart: Bool
    let start: () -> Void
    let cancel: () -> Void
    var title: String?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            if #available(macOS 26, *), !reduceTransparency {
                GlassEffectContainer {
                    if state.isBusy {
                        cancelButton.buttonStyle(.glass)
                    } else {
                        startButton.buttonStyle(.glassProminent)
                    }
                }
            } else {
                if state.isBusy {
                    cancelButton.buttonStyle(.bordered)
                } else {
                    startButton.buttonStyle(.borderedProminent)
                }
            }
        }
        .controlSize(.large)
        .fixedSize()
    }

    private var startButton: some View {
        Button(action: start) {
            Label(title ?? "开始\(operation.title)", systemImage: operation.symbol)
                .padding(.horizontal, 6)
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!canStart)
    }

    private var cancelButton: some View {
        Button(state == .cancelling ? "正在取消…" : "取消", action: cancel)
            .disabled(state == .cancelling)
            .keyboardShortcut(.cancelAction)
    }
}
