# Changelog

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

### Safety

- No changes to the fixed write order. `PK` remains the final firmware write.
- Restart/resume still performs detection only and never starts a new UEFI write automatically.
- Advanced recovery still requires exact evidence and does not guess from key count.

## 1.0.1.2 — 2026-06-19

### Fixed

- Increased the top risk-summary panel from 68 to 100 logical pixels.
- Increased the wrapped explanation area from 33 to 62 logical pixels so Chinese and English text remains fully visible at the 1180 × 880 minimum window size.
- Moved the next-action panel and tab area downward without reducing the bottom control margin.
- Added regression checks for four-line risk text capacity and top-area non-overlap.
- Corrected the GitHub publishing guide to include the required PS2EXE `.exe.config` runtime sidecar.

### Safety

- No changes to the UEFI state machine, PK-last write order, certificate validation, restart behavior, official rotation, or advanced-recovery model.

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

### Safety

- No changes to the UEFI state machine, PK-last write order, certificate rules, restart behavior, or advanced-recovery model.

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

