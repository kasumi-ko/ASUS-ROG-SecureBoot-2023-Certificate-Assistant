# ASUS/ROG Secure Boot 2023 Assistant v1.0.1.2

这是一个界面显示修正版。UEFI 状态机、写入顺序、证书校验、重启续跑、官方轮换和高级恢复规则没有改变。

## 下载

Windows 10/11 x64 用户请下载：

- `ASUS-ROG-SecureBoot-2023-Assistant-v1.0.1.2-windows-x64.zip`
- `ASUS-ROG-SecureBoot-2023-Assistant-v1.0.1.2-windows-x64.zip.sha256.txt`

GitHub 自动生成的源码压缩包不是普通用户运行包。当前 EXE 尚未进行 Authenticode 签名，请使用随 Release 提供的 SHA-256 文件核对完整性。

## 本次修正

- 扩大主界面顶部“风险等级”说明区域；
- 中英文风险解释在 1180 × 880 最小窗口下可完整换行显示；
- 下移“下一步”和标签页区域，同时保持底部按钮位置不变；
- 新增顶部区域不重叠和至少四行说明容量的回归测试；
- 发布说明明确保留 PS2EXE 生成的 `.exe.config` 长路径支持文件。

## Runtime ZIP 内容

```text
ASUS-ROG-SecureBoot-2023-Assistant.exe
ASUS-ROG-SecureBoot-2023-Assistant.exe.config
README.txt
LICENSE.txt
checksums.sha256
```

`.exe.config` 必须与 EXE 放在同一目录。

## 安全提醒

本工具会读取，并且仅在用户明确确认后修改主板 UEFI NVRAM 中的 Secure Boot 变量。不要公开上传修复流程恢复包、Default Keys 原始备份、BitLocker 恢复密钥、设备序列号或个人文件。

---

## English

This is a UI-display corrective release. The UEFI state machine, write order, certificate validation, restart/resume behavior, official rotation, and advanced-recovery rules are unchanged.

### Fixes

- Enlarged the top risk-summary area;
- kept wrapped Chinese and English risk explanations fully visible at the 1180 × 880 minimum window size;
- moved the next-action panel and tabs downward while preserving the bottom control margin;
- added regression checks for non-overlap and at least four lines of explanation text;
- documented the required PS2EXE `.exe.config` long-path sidecar.

### Runtime ZIP

```text
ASUS-ROG-SecureBoot-2023-Assistant.exe
ASUS-ROG-SecureBoot-2023-Assistant.exe.config
README.txt
LICENSE.txt
checksums.sha256
```

Keep `.exe.config` beside the EXE.
