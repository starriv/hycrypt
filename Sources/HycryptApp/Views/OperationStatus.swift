import HycryptCore
import SwiftUI

struct OperationStatus: View {
    let state: OperationState
    let validationMessage: String?
    let reveal: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch state {
            case .idle:
                Text(validationMessage ?? "准备就绪").font(.caption).foregroundStyle(.secondary)
            case .running(let progress):
                if let fraction = progress.fraction {
                    ProgressView(value: fraction)
                } else {
                    ProgressView().controlSize(.small)
                }
                Text(progress.message).font(.caption).foregroundStyle(.secondary)
            case .cancelling:
                ProgressView().controlSize(.small)
                Text("正在取消…密钥派生结束后会清理临时数据").font(.caption).foregroundStyle(.secondary)
            case .succeeded(let result):
                VStack(alignment: .leading, spacing: 6) {
                    Label("已保存：\(result.lastPathComponent)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green).lineLimit(2)
                    Button("在 Finder 中显示", systemImage: "arrow.up.forward.square") { reveal(result) }
                        .buttonStyle(.link)
                }
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red).textSelection(.enabled)
            case .cancelled:
                Text("已取消，临时数据已清理").font(.caption).foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
    }
}

#Preview("成功") {
    OperationStatus(
        state: .succeeded(URL(fileURLWithPath: "/tmp/report.hycrypt")), validationMessage: nil, reveal: { _ in }
    )
    .padding()
}

#Preview("取消中") {
    OperationStatus(state: .cancelling, validationMessage: nil, reveal: { _ in }).padding()
}
