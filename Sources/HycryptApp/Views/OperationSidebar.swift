import HycryptCore
import SwiftUI

struct OperationSidebar: View {
    let operation: CryptOperation
    let isBusy: Bool
    let select: (CryptOperation) -> Void

    var body: some View {
        List(selection: selection) {
            Section {
                ForEach(CryptOperation.allCases) { item in
                    Label(item.title, systemImage: item.symbol)
                        .tag(item)
                        .padding(.vertical, 3)
                }
            }
        }
        .listStyle(.sidebar)
        .disabled(isBusy)
        .navigationTitle("Hycrypt")
        .safeAreaInset(edge: .bottom, alignment: .leading) {
            SettingsLink {
                Label("设置", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(16)
        }
    }

    private var selection: Binding<CryptOperation?> {
        Binding(
            get: { operation },
            set: { value in
                guard !isBusy, let value else { return }
                select(value)
            })
    }
}
