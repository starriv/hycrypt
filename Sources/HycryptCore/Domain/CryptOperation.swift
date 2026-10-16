import Foundation

public enum CryptOperation: String, CaseIterable, Sendable, Identifiable {
    case encrypt
    case decrypt

    public var id: Self { self }

    public func suggestedOutputName(for source: URL) -> String {
        switch self {
        case .encrypt:
            source.lastPathComponent + ".hycrypt"
        case .decrypt:
            source.pathExtension.lowercased() == "hycrypt"
                ? source.deletingPathExtension().lastPathComponent
                : source.lastPathComponent + ".restored"
        }
    }
}
