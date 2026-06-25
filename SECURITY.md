# Security Policy / 安全政策

<p align="center">
  <strong>简体中文</strong> · <a href="#english">English</a>
</p>

## 支持版本

仅当前正式版本和后续版本接受安全问题反馈。

| 版本 | 状态 |
| --- | --- |
| v1.1 及后续版本 | 支持 |
| v1.0.x 及更早版本 | 不再维护 |

请优先使用最新 Release。旧版本中已经修复的问题，不再单独回溯处理。

## 报告安全问题

如果你发现可能影响设备安全、数据安全或 Secure Boot 状态完整性的漏洞，请不要在公开 Issue 中直接披露细节。

建议报告内容包括：

- 受影响版本；
- Windows 版本和设备型号；
- 问题触发条件；
- 复现步骤；
- 程序显示的状态；
- 脱敏后的诊断报告。

请不要公开上传：

- 修复流程恢复包；
- `PKDefault / KEKDefault / dbDefault / dbxDefault` 原始备份；
- BitLocker 恢复密钥；
- 设备序列号；
- 包含个人信息的日志或截图。

如果问题只涉及普通兼容性、界面显示、BIOS 菜单差异或使用流程疑问，可以使用普通 Issue，但仍应避免上传敏感文件。

## 安全边界

本工具只面向受支持的 ASUS / ROG Windows 设备场景。非 ASUS / ROG 设备默认只读检测，不开放受控写入流程。

程序不会自动清除 BIOS 中的 Secure Boot Keys。需要完整修复流程时，用户必须自行进入 BIOS，使设备进入符合要求的 Setup Mode，再回到 Windows 运行工具。

程序不会绕过 Secure Boot、BitLocker 或 Windows 的安全机制，也不会提供用于规避游戏反作弊、系统完整性检查或企业安全策略的功能。

## BitLocker / 设备加密

从 v1.1 起，若没有明确检测到系统盘已经完全解密，程序不得继续执行 Secure Boot 写入流程。

以下情况均应阻止继续操作：

- BitLocker 保护中；
- BitLocker 已暂停但磁盘仍处于加密状态；
- 设备加密状态未知；
- 无法确认系统盘已经完全解密。

程序可以提示用户查看处理方法，但不应替用户自动暂停或解密 BitLocker。用户应自行确认恢复密钥已保存，并在理解风险后处理磁盘加密状态。

## Secure Boot 与 Factory Keys

程序会区分当前正在使用的 active Keys 和 BIOS 固件预置的 Default Keys。

如果 active Keys 已包含 2023 证书，但 BIOS 固件预置的 Default Keys 不完整，程序应按注意状态提示用户。这不代表当前 active Keys 一定未更新；它表示后续使用 `Restore Factory Keys` 可能把当前状态恢复到较旧的默认 Keys。

不要在不理解后果的情况下清除 Keys、恢复 Factory Keys 或手动导入未知来源的证书。

## 诊断报告与恢复包

诊断报告用于排查问题，设计上应尽量脱敏。

修复流程恢复包用于证明中断前的合法检查点，可能包含设备相关的原始备份、事务清单、设备指纹和阶段哈希。恢复包不应作为普通日志公开提交。

提交问题时，请优先提供脱敏诊断报告，而不是恢复包。

## 免责声明

本工具涉及 UEFI Secure Boot 状态检测和受控修复。错误操作、固件缺陷、断电、BitLocker 恢复、BIOS 菜单误操作或不受支持的设备环境都可能导致启动异常。

使用前请阅读 README、Release Notes 和首次运行提示，并自行确认已备份重要数据和恢复密钥。

---

<h2 id="english">English</h2>

## Supported versions

Only the current stable release and later versions receive security support.

| Version | Status |
| --- | --- |
| v1.1 and later | Supported |
| v1.0.x and earlier | Not maintained |

Please use the latest Release first. Issues already fixed in newer versions are not backported to old releases.

## Reporting a security issue

If you find a vulnerability that may affect device security, data security, or Secure Boot state integrity, do not disclose the details in a public Issue.

A useful report should include:

- affected version;
- Windows version and device model;
- trigger conditions;
- reproduction steps;
- the state shown by the program;
- a sanitized diagnostic report.

Do not publicly upload:

- repair workflow recovery packages;
- raw `PKDefault / KEKDefault / dbDefault / dbxDefault` backups;
- BitLocker recovery keys;
- device serial numbers;
- logs or screenshots containing personal information.

For compatibility issues, UI problems, BIOS menu differences, or general usage questions, public Issues are acceptable, but sensitive files should still be excluded.

## Security boundary

This tool is intended only for supported ASUS / ROG Windows device scenarios. Non-ASUS / ROG systems are read-only by default and do not receive controlled write actions.

The program does not automatically clear Secure Boot Keys in the BIOS. To run the full repair workflow, the user must enter the BIOS manually, put the device into the required Setup Mode, and then return to Windows to run the tool.

The program does not bypass Secure Boot, BitLocker, Windows security mechanisms, game anti-cheat checks, system integrity checks, or enterprise security policies.

## BitLocker / device encryption

Starting with v1.1, the program must not continue with Secure Boot write operations unless the system drive is clearly detected as fully decrypted.

The workflow must be blocked in all of the following cases:

- BitLocker protection is active;
- BitLocker is suspended but the drive is still encrypted;
- device encryption status is unknown;
- the system drive cannot be confirmed as fully decrypted.

The program may show guidance, but it should not automatically suspend or decrypt BitLocker. Users must confirm that the recovery key is saved and handle disk encryption only after understanding the risk.

## Secure Boot and Factory Keys

The program distinguishes between active Keys and firmware-provided Default Keys.

If the active Keys already contain the 2023 certificates but the firmware-provided Default Keys are incomplete, the program should show a caution-level notice. This does not necessarily mean the active Keys are not updated; it means using `Restore Factory Keys` later may restore older default Keys.

Do not clear Keys, restore Factory Keys, or manually import certificates from unknown sources without understanding the consequences.

## Diagnostic reports and recovery packages

Diagnostic reports are intended for troubleshooting and should be sanitized.

Repair workflow recovery packages are used to prove a valid interrupted checkpoint. They may contain device-related raw backups, transaction manifests, device fingerprint data, and stage hashes. Recovery packages should not be submitted publicly as ordinary logs.

When reporting an issue, provide a sanitized diagnostic report first, not a recovery package.

## Disclaimer

This tool interacts with UEFI Secure Boot state detection and controlled repair. Incorrect operation, firmware defects, power loss, BitLocker recovery, BIOS menu mistakes, or unsupported device environments may cause boot problems.

Read the README, Release Notes, and first-run notice before use. Back up important data and recovery keys first.
