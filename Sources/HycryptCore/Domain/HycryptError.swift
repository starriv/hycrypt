import Foundation

public enum HycryptError: LocalizedError {
    case passwordWhitespace
    case invalidFormat, authenticationFailed, emptyPassword
    case destinationExists, invalidSource, sourceChanged, unsafeArchive, outputInsideSource
    case stagingUnavailable, memoryLockUnavailable
    case cryptoFailure(Int32)

    public var errorDescription: String? {
        switch self {
        case .invalidFormat: "文件格式无效、版本不受支持或文件已被截断。"
        case .authenticationFailed: "密码不正确，或文件已损坏 / 被修改。"
        case .passwordWhitespace: "密码中间不能包含空格、Tab 或换行。"
        case .emptyPassword: "请输入密码。"
        case .destinationExists: "目标已存在。请选择其他名称；Hycrypt 不会覆盖现有数据。"
        case .invalidSource: "请选择可读取的普通文件或文件夹。符号链接和特殊文件不受支持。"
        case .sourceChanged: "源文件在处理过程中被修改。请确认没有其他程序正在写入后重试。"
        case .unsafeArchive: "压缩包包含不安全、重复或超出限制的条目，已停止恢复。"
        case .outputInsideSource: "输出位置不能在待加密的文件夹内部。"
        case .stagingUnavailable: "无法在目标磁盘建立专用临时目录，已停止。请选择其他保存位置后重试。"
        case .memoryLockUnavailable: "无法将密钥锁定在物理内存中，已停止。请关闭其他占用内存的程序后重试。"
        case .cryptoFailure(let code): "加密组件发生错误（\(code)）。"
        }
    }
}
