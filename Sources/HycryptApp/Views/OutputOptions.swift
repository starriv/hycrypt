import SwiftUI

struct OutputOptions: View {
    let directory: URL?
    @Binding var name: String
    var syncWarning: String?
    var choose: () -> Void = {}

    var body: some View {
        Section {
            if let syncWarning {
                Label(syncWarning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            DisclosureGroup {
                TextField("输出名称", text: $name)
                    .accessibilityLabel("输出名称")
            } label: {
                LabeledContent("保存为") {
                    Text(name.isEmpty ? "选择源文件后自动命名" : name)
                        .lineLimit(1).truncationMode(.middle)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Label(directory?.lastPathComponent ?? "使用默认保存位置", systemImage: "folder")
                    .lineLimit(1).truncationMode(.middle)
                    .foregroundStyle(.secondary)
                    .help(directory?.path ?? "在设置中更改默认保存位置")
                Spacer()
                Button("选择…", action: choose)
            }
            .font(.caption)
        }
    }
}
