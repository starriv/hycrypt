import HycryptCore
import SwiftUI

struct SourcePicker: View {
    let source: URL?
    let operation: CryptOperation
    let isEnabled: Bool
    let choose: () -> Void
    let select: (URL) -> Void
    @State private var isDropTargeted = false

    var body: some View {
        Section("源文件") {
            HStack(spacing: 14) {
                Image(systemName: source == nil ? "doc.badge.plus" : "doc")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.tint)
                    .frame(width: 42)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(source?.lastPathComponent ?? "拖放文件到这里")
                        .font(.headline)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Text(source?.path ?? (operation == .encrypt ? "支持单个文件或整个文件夹" : "选择 .hycrypt 加密文件"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(source == nil ? "选择文件…" : "更换…", action: choose)
                    .accessibilityLabel(source == nil ? "选择源文件或文件夹" : "更换源文件或文件夹")
                    .disabled(!isEnabled)
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .listRowBackground(isDropTargeted ? Color.accentColor.opacity(0.12) : nil)
            .dropDestination(for: URL.self, action: acceptDrop) { isDropTargeted = isEnabled && $0 }
            .help(source?.path ?? "拖入一个文件，或使用选择按钮")
        }
    }

    private func acceptDrop(_ urls: [URL], at location: CGPoint) -> Bool {
        guard isEnabled, urls.count == 1, let url = urls.first, url.isFileURL else { return false }
        select(url)
        return true
    }
}
