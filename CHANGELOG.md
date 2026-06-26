# Changelog

## v1.2

- Added a boot check for devices where Active Keys already contain the 2023 certificates but Secure Boot is still disabled.
- Checked Windows Boot Manager, firmware boot order, the standard Windows boot path, third-party EFI loaders, external boot entries, network boot entries, PE entries, Ventoy entries, dual-boot entries, and unknown boot paths.
- Show Windows Boot Manager repair only when the issue is limited to boot order or the standard Windows boot path.
- Updated Chinese and English UI text, script comments, README, security notes, and release text.
- Adjusted several UI areas so long English text has more room in the minimum window size.

## v1.1.1

- Added a boot-chain check for the state where active Keys already contain 2023 certificates but Secure Boot is still disabled.
- The assistant now checks Windows Boot Manager path and firmware boot order before guiding the user to enable Secure Boot.
- If Windows Boot Manager can be repaired, the primary action sets it as the first firmware boot entry and confirms the standard Windows boot file path.
- If the boot chain cannot be verified, the direct enable flow is blocked and the user is told to repair Windows Boot Manager manually first.

## 1.1 — 2026-06-25

### Fixed

- Added visible disabled-action reasons when the main repair button is shown but cannot be clicked.
- Added `WriteAllowed` and write-block reason fields to detailed diagnostics, overview, logs, and diagnostic snapshots.
- Treated firmware Default Keys that lack complete 2023 entries as a caution state when active Keys are already updated.
- Improved post-PK state recognition so verified active Secure Boot state can continue to official rotation even when the prior transaction record was locked by a conservative validation failure.
- Removed x64-only wording from the ordinary user README and runtime README.

## 1.0.1.2 — 2026-06-19

### Fixed

- Increased the top risk-summary panel from 68 to 100 logical pixels.
- Increased the wrapped explanation area from 33 to 62 logical pixels so Chinese and English text remains fully visible at the 1180 × 880 minimum window size.
- Moved the next-action panel and tab area downward without reducing the bottom control margin.
- Added regression checks for four-line risk text capacity and top-area non-overlap.
- Corrected the GitHub publishing guide to include the required PS2EXE `.exe.config` runtime sidecar.

## 1.0.1 — 2026-06-19

### Fixed

- Replaced the mixed source/runtime release layout with a strict four-file runtime allow-list.
- Removed `START-HERE.txt`, the `source` directory, build scripts, tests, and project documents from the end-user ZIP.
- Added clean-extraction verification after ZIP creation.
- Added manifest coverage checks so unlisted files fail package verification.
- Added the `windows-x64` platform and architecture suffix to runtime artifact names.

### Changed

- Updated application and EXE metadata to version 1.0.1.
- Split the repository README into linked Chinese and English pages.
- Simplified the public README and removed the standalone `BUILD-EXE.md` document.

## 1.0.0 — 2026-06-19

First public release.

- Chinese/English first-run setup and main interface.
- ASUS/ROG capability-based detection rather than a fixed BIOS whitelist.
- Controlled Setup Mode trust-chain reconstruction with PK written last.
- Windows UEFI CA 2023 certificate identity and hash validation.
- Per-step byte length, SHA-256, byte-level, and semantic verification.
- One-time restart/resume task with post-sign-in re-detection.
- Interrupted workflow recovery and evidence-based restricted recovery.
- Official Windows Secure Boot 2023 servicing workflow and event analysis.
- Factory Keys reset-risk comparison.
- Sanitized diagnostic report export and explicit file-location disclosure.

