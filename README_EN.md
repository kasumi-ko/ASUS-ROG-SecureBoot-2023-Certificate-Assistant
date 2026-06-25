# ASUS/ROG Secure Boot 2023 Assistant

<p align="center">
  <a href="./README.md">简体中文</a> · <strong>English</strong>
</p>

A Secure Boot 2023 diagnostic and controlled-repair tool for ASUS/ROG Windows devices.

This project addresses a difficult class of failures where a device is already in Secure Boot Setup Mode but Windows still cannot complete the 2023 certificate rotation. It does not bypass checks or write every key at once. Detection, backup, firmware writes, restart handling, and verification are performed step by step against the real firmware state.

> **Important:** This program reads UEFI NVRAM and can modify Secure Boot variables only after explicit user confirmation. It is not a generic one-click repair tool and is not guaranteed to support every motherboard or BIOS.

## Download

Download the runtime package that matches your device architecture from [Releases](https://github.com/kasumi-ko/ASUS-ROG-SecureBoot-2023-Assistant/releases/latest).

GitHub's automatically generated `Source code (zip)` and `Source code (tar.gz)` files are source snapshots, not the end-user package.

The current EXE is not Authenticode-signed. Verify the download with the SHA-256 file provided with the release.

## Basic requirements

- Windows 10 or Windows 11;
- UEFI boot mode;
- an ASUS, ROG, or ASUSTeK device;
- administrator privileges.

Non-ASUS/ROG systems are read-only.

## Main features

- Inspects Secure Boot, Setup Mode, `PK / KEK / db / dbx`, and all four Default variables;
- validates the official Microsoft `Windows UEFI CA 2023` certificate;
- restores the Secure Boot trust chain in a fixed order when every precondition is satisfied;
- clearly shows why the repair button is unavailable;
- runs the Windows Secure Boot 2023 servicing task and checks the result;
- re-reads the real firmware state after restart instead of automatically continuing from an old UI checkpoint;
- recovers interrupted workflows from verified evidence;
- exports sanitized diagnostics and warns about Factory Keys reset risks.

The program is not tied to one model or BIOS allow-list. Firmware writes are enabled only when the detected device, firmware variables, Setup Mode, active keys, Default keys, power state, system-drive BitLocker/device-encryption decryption state, and pending-restart checks all pass.

## Basic use

1. Extract the complete release ZIP and keep `ASUS-ROG-SecureBoot-2023-Assistant.exe.config` beside the EXE.
2. Run `ASUS-ROG-SecureBoot-2023-Assistant.exe`.
3. Accept the administrator prompt.
4. On first run, choose a language and storage folder, read the safety notice, and complete the confirmations.
5. Follow the highlighted next action in the main window.

If the repair button is greyed out, the interface will show the blocking reason, such as a pending Windows restart, no fully decrypted system drive detected, unsafe power state, or unverified recovery evidence.

## Fixed repair order

```text
Back up all four Default variables
        ↓
dbDefault → db
        ↓
Append Windows UEFI CA 2023
        ↓
dbxDefault → dbx
        ↓
KEKDefault → KEK
        ↓
PKDefault → PK
        ↓
Restart and re-detect
        ↓
Run the official Windows 2023 rotation
        ↓
Final verification
```

`PK` is always written last. Every new UEFI write requires fresh user confirmation. Automatic startup after a restart performs detection only; it never performs the next write automatically.

## File safety

A repair workflow recovery package may contain device-related raw Default-key backups, a transaction manifest, device fingerprint data, and stage hashes.

**Do not upload a repair workflow recovery package to public Issues, forums, file-sharing sites, or chat groups.**

Use the sanitized diagnostic report when reporting a problem. It excludes raw Default-key backups, BitLocker recovery keys, and personal files, but you should still review it before uploading.

## Documentation

- [Security policy](./SECURITY.md)
- [Changelog](./CHANGELOG.md)

## License and author

Licensed under the [GNU General Public License v3.0](./LICENSE).

Author: 霞詩 @BILIBILI  
Profile: <https://space.bilibili.com/4216920>
