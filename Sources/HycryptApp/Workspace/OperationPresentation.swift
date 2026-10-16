import HycryptCore

extension CryptOperation {
    var title: String { self == .encrypt ? "加密" : "解密" }
    var symbol: String { self == .encrypt ? "lock.fill" : "lock.open.fill" }
}

extension OperationProgress {
    var message: String {
        switch phase {
        case .preparing: "正在准备…"
        case .derivingKey: "正在派生密钥…"
        case .encrypting: "正在加密…"
        case .decrypting: "正在验证并解密…"
        case .archiving(let path): "正在压缩：\(path)"
        case .restoring(let path): "正在恢复：\(path)"
        case .saving: "正在保存结果…"
        case .finished: "已完成"
        }
    }
}
