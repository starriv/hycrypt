# Hycrypt

原生 macOS 加密应用，支持文件、文件夹、文本与 24 词 BIP39 英文助记词。
使用 Swift 6、SwiftUI 和 AppKit，所有加解密在本机执行，无需后台服务。

## 环境要求

- 运行：macOS 14 或更新版本。
- 构建：Xcode 26 或更新版本及其命令行工具。
- 首次构建需要下载 ZIPFoundation；依赖版本由 `Package.resolved` 固定。

## 构建与运行

```sh
make check          # 第三方源码校验、Swift 格式检查、单元测试
make app            # 本机架构 Release 构建，输出 dist/Hycrypt.app
make run            # 构建并运行
make security-check # 构建并验证签名、沙盒及 Argon2 错误路径
```

也可以在 Xcode 中打开 `Package.swift`。`make app` 默认使用 ad-hoc 签名，
适合本地开发，不是经过 Apple 公证的分发版本。正式发布见 [发布指南](docs/RELEASING.md)。

## 使用

1. 选择「加密」或「解密」，再选择文件、文本或助记词模式。
2. 文件模式选择源文件或目录，并授权保存目录；文本模式直接输入内容。
3. 输入密码，加密时再次确认，然后开始处理。已有目标不会被覆盖。

新密码最多 4096 字节，不强制复杂度，强度仅供参考。新密码与确认密码会去除首尾空白，
中间不能有空格、Tab 或换行；解密密码保持原样，兼容已有密文。
小眼睛可在原输入行切换显示与隐藏；显示期间明文可能被截图或录屏。

助记词模式可生成或输入 24 个 BIP39 英文单词。生成后悬停逐词查看，
抄写并确认备份后再加密。应用不验证钱包派生路径，也不保存恢复密码。
文本原文最多 1 MiB，密文为 Base64；文件夹先打包 ZIP 再加密。

应用启动无需认证。手动锁定、锁屏、休眠或两分钟闲置会清理并锁定会话，
锁定后恢复使用需系统认证。设置可选择默认输入模式和保存位置。

## 数据与安全

- `HYCRYPT2`：AES-256-GCM 分块认证加密，Argon2id 派生密钥。
- 源文件保留；密码错误、密文损坏或操作取消不会发布不完整结果。
- 不支持旧 AES-CBC 格式、源符号链接或特殊文件；文件元数据不保证保留。
- 文件模式可能产生临时明文；崩溃或断电后可能残留，删除不等于安全擦除。
- 密码、助记词和解密内容不持久保存在设置或钥匙串中。
- App Sandbox 和 Hardened Runtime 已启用；应用没有网络权限。

安全边界与临时数据处理详见 [安全说明](docs/SECURITY.md)，
二进制格式见 [格式规范](docs/FORMAT.md)。此项目尚未经独立密码学审计。

## 开发

- [贡献指南](CONTRIBUTING.md)：检查命令、测试组织与提交要求。
- [架构说明](docs/ARCHITECTURE.md)：模块职责与并发边界。
- [发布指南](docs/RELEASING.md)：签名、公证和分发产物。

第三方依赖：Apple CryptoKit、[Argon2](https://github.com/P-H-C/phc-winner-argon2)、
[ZIPFoundation](https://github.com/weichsel/ZIPFoundation) 及 BIP39 英文词表。
第三方许可保留在 `Vendor/` 和依赖源码内，并随应用包分发。

## 许可证

项目目前未指定开源许可证。源码可见不代表获得复制、修改或再分发授权；
第三方组件分别适用其自身许可。
