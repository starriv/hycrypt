# 发布指南

## 发布前检查

1. 检查 `macOS/Info.plist` 中的版本号和构建号，以及 `Package.resolved`。
2. 执行 `make check` 和 `make security-check`。
3. 人工验证启动、加解密往返、密码显示切换、助记词备份、文件选择和锁定恢复。
4. 在计划支持的系统和处理器架构上验证。默认产物只包含构建机器的架构，不是 Universal Binary。
5. 项目尚未选择开源许可证；对外宣称开源或接收贡献前需确定授权安排。

## 本地构建

`make app` 在 `dist/Hycrypt.app` 创建 ad-hoc 签名应用，供本地验证。
CI 上传的 `unsigned-dev` 产物同样只供测试，不能当作正式签名版本。

## Developer ID 签名与公证

需要 Apple Developer Program、钥匙串中的 Developer ID Application 身份，
以及已经保存的 notarytool 凭据配置。不要将凭据提交到仓库。

```sh
xcrun notarytool store-credentials hycrypt-notary
SIGNING_IDENTITY="Developer ID Application: YOUR NAME (TEAMID)" \
NOTARY_PROFILE=hycrypt-notary make release
```

`make release` 先执行源码检查与测试，然后强制 Release 构建，检查签名身份配置，
签名并添加时间戳，验证权限，提交 Apple 公证、装订票据并执行 Gatekeeper 评估。
任何一步失败都会中止，不会生成新的发布归档。

成功后得到：

- `dist/Hycrypt.app`：已签名并装订票据的应用。
- `dist/Hycrypt-<版本>-<架构>.zip`：分发归档。
- 同名 `.zip.sha256`：归档 SHA-256 校验和。

构建目录可能包含以前的产物，应只分发本次成功命令输出的文件。
Git 标签、GitHub Release 与文件上传由维护者另行执行，构建脚本不会自动发布。
