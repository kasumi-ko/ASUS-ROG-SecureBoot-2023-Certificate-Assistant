# ASUS/ROG Secure Boot 2023 Assistant

<p align="center">
  <strong>简体中文</strong> · <a href="./README_EN.md">English</a>
</p>

用于 ASUS/ROG Windows 10/11 设备的 Secure Boot 2023 检测与受控修复工具。

这个项目主要处理一种比较麻烦的情况：设备已经进入 Secure Boot Setup Mode，但 Windows 仍无法正常完成 2023 证书轮换。程序不会跳过检查或一次性写入全部 Keys，而是按真实固件状态逐步检测、备份、写入和复验。

> **重要：** 本程序会读取 UEFI NVRAM，并且只在用户明确确认后修改 Secure Boot 变量。它不是通用的一键修复工具，也不保证适用于所有主板或 BIOS。

## 下载

请从 [Releases](https://github.com/kasumi-ko/ASUS-ROG-SecureBoot-2023-Assistant/releases/latest) 下载：

- `ASUS-ROG-SecureBoot-2023-Assistant-v1.0.1.2-windows-x64.zip`
- `ASUS-ROG-SecureBoot-2023-Assistant-v1.0.1.2-windows-x64.zip.sha256.txt`

GitHub 自动生成的 `Source code (zip)` 和 `Source code (tar.gz)` 是源码快照，不是普通用户运行包。

当前 EXE 尚未进行 Authenticode 代码签名。下载后请使用随 Release 提供的 SHA-256 文件核对完整性。

## 系统要求

- Windows 10 或 Windows 11；
- UEFI 启动；
- ASUS、ROG 或 ASUSTeK 设备；
- 管理员权限。

## 主要功能

- 检查 Secure Boot、Setup Mode、`PK / KEK / db / dbx` 及四个 Default 变量；
- 验证微软官方 `Windows UEFI CA 2023` 证书；
- 在满足全部条件时，按固定顺序恢复 Secure Boot 信任链；
- 调用 Windows 自带的 Secure Boot 2023 轮换任务并检查结果；
- 重启后重新读取真实固件状态，不根据旧界面自动继续写入；
- 对意外中断的流程进行证据恢复；
- 导出脱敏诊断报告，并提示 Factory Keys 重置风险。

程序不绑定某一个型号或 BIOS 白名单。是否允许写入，取决于程序实际读取到的设备、固件变量、Setup Mode、活动 Keys、Default Keys、电源、BitLocker 和待重启状态。

## 使用方法

1. 完整解压 Release ZIP，并将 `ASUS-ROG-SecureBoot-2023-Assistant.exe.config` 与 EXE 保持在同一目录。
2. 运行 `ASUS-ROG-SecureBoot-2023-Assistant.exe`。
3. 接受管理员权限提示。
4. 首次运行时选择语言和备份目录，阅读风险说明并完成确认。
5. 进入主界面后，按顶部高亮的“下一步”操作。

没有出现修复按钮，通常表示某项前置条件未通过。具体原因可在“详细检测”中查看。

## 固定修复顺序

```text
备份四个 Default 变量
        ↓
dbDefault → db
        ↓
追加 Windows UEFI CA 2023
        ↓
dbxDefault → dbx
        ↓
KEKDefault → KEK
        ↓
PKDefault → PK
        ↓
重启并重新检测
        ↓
运行 Windows 官方 2023 轮换
        ↓
最终验证
```

`PK` 永远最后写入。每次新的 UEFI 写入都需要用户重新确认。重启后的自动启动只负责检测，不会自动执行下一次写入。

## 文件安全

“修复流程恢复包”可能包含设备相关的 Default Keys 原始备份、事务清单、设备指纹和阶段哈希。

**不要把修复流程恢复包上传到公开 Issue、论坛、网盘或聊天群。**

提交问题时应优先使用“诊断报告”。诊断报告会排除 Default Keys 原始备份、BitLocker 恢复密钥和个人文件，但仍建议在上传前自行检查内容。

## 反馈问题

请在 GitHub Issues 中说明 Windows 版本、设备型号和 BIOS 版本、程序显示的当前状态及复现步骤。必要时可附上脱敏诊断报告。

请勿公开上传恢复包、Default Keys 原始备份、BitLocker 恢复密钥、设备序列号或个人文件。

## 相关文档

- [安全说明](./SECURITY.md)
- [更新记录](./CHANGELOG.md)
- [v1.0.1.2 发布说明](./RELEASE-NOTES-v1.0.1.2.md)

## 许可与作者

本项目采用 [GNU General Public License v3.0](./LICENSE)。

作者：霞詩 @BILIBILI  
主页：<https://space.bilibili.com/4216920>
