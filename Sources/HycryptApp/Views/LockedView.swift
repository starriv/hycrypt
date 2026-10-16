import SwiftUI

/// Full-window gate while the app-wide local session is locked.
struct LockedView: View {
    let authorization: LocalAuthorization?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("已锁定")
                .font(.title)
            Text("需要系统认证才能继续使用 Hycrypt")
                .foregroundStyle(.secondary)
            if authorization?.isAuthenticating == true {
                ProgressView()
                    .padding(.top, 4)
            } else {
                Button("重新认证", systemImage: "lock.open") { authorization?.unlock() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .padding(.top, 4)
            }
            if let error = authorization?.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 420)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
    #Preview("锁定") {
        LockedView(authorization: nil)
    }
#endif
