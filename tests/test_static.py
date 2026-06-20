from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
MAIN_PATH = ROOT / 'ASUS-ROG-SecureBoot-2023-Assistant.ps1'
MAIN = MAIN_PATH.read_text(encoding='utf-8-sig')

required_tokens = [
    "1.0.1.2",
    'Show-Oobe', 'Get-DefaultBackupRoot', 'Get-BackupDirectoryValidation',
    'SetupMode', 'SecureBoot', 'NoKeys',
    'PKDefault', 'KEKDefault', 'dbDefault', 'dbxDefault',
    'ReadSucceeded', "if ($isMissing) { 'Missing' } else { 'Error' }",
    'Format-SecureBootUEFI', 'Set-SecureBootUEFI',
    'Windows UEFI CA 2023',
    '076F1FEA90AC29155EBF77C17682F75F1FDD1BE196DA302DC8461E350A9AE330',
    '45A0FA32604773C82433C3B7D59E7466B3AC0C67',
    '77fa9abd-0359-4d32-bd60-28f4e78f784b',
    'AvailableUpdatesAll = 0x5944', 'AvailableUpdatesComplete = 0x4000',
    'UEFICA2023Status', 'Secure-Boot-Update',
    'Register-ResumeTask', 'Resolve-ResumeCheckpoint',
    '不会自动执行新的固件写入',
    'LastWriteIntent', 'Test-TransactionIntermediateState', 'Sync-TransactionProgressFromState',
    'Export-DiagnosticPackage', 'DefaultResetRisk',
    'Test-PendingWindowsReboot', 'Assert-WritePreconditions', 'Assert-OfficialRotationPreconditions',
    'ReadOnlyNonAsus', 'MissingDefaultVariables', 'FirmwareVariableReadFailure',
    'UpdatedButVerificationMismatch', 'PkWrittenPendingReboot',
    'AdvancedRecoveryRequired', 'BlockedUnsafe', 'Show-AdvancedRecoveryDialog',
    'Import-RecoveryPackage', 'Export-RecoveryPackage', 'Rebuild-TransactionFromSelectedEvidence',
    'New-AdvancedRecoveryTransaction', 'Get-RecoveryStageFromEvidence',
    'I UNDERSTAND', '我已了解', 'ASUSROG-SecureBoot-Recovery',
    'Show-AboutDialog', 'New-AboutIconBitmap', 'Open-TrustedUrl',
    'https://github.com/kasumi-ko/ASUS-ROG-SecureBoot-2023-Assistant',
    'https://space.bilibili.com/4216920', '项目仓库', '哔哩哔哩主页', '霞詩',
]
missing = [token for token in required_tokens if token not in MAIN]
assert not missing, f'missing required tokens: {missing}'

# Dangerous typo and raw certificate write must never appear.
for pattern in [
    r'Set\s+-\s+SecureBootUEFI',
    r'Set-SecureBootUEFI[^\n]*-Content\s+\$certBytes',
    r'Invoke-WebRequest[^\n]*2239776',  # app must not download the certificate itself
    r'Restart-Computer\s+-Force',       # do not force-close user applications
]:
    assert not re.search(pattern, MAIN, flags=re.I), f'unsafe pattern found: {pattern}'

# The only certificate write path must pass a formatted object to Set-SecureBootUEFI.
assert re.search(r'Format-SecureBootUEFI[\s\S]{0,1800}\$formatted\s*\|\s*Set-SecureBootUEFI', MAIN)

# The software may calculate MD5 at runtime, but must not gate trust on a hard-coded MD5.
assert "OfficialCertificateMd5" not in MAIN
assert "Get-FileHashHex -Path $Path -Algorithm MD5" in MAIN
assert '安全判定不依赖MD5' in MAIN

# PK must be the final restoration option in the UI flow.
restore_order = [
    MAIN.index("'DbxWritten' { 'KekDefault' }"),
    MAIN.index("'KekWritten' { 'PkDefault' }"),
]
assert restore_order == sorted(restore_order)

# Every UEFI write function must record pending intent first and verify afterward.
for fn in ['Invoke-WriteDbDefault', 'Invoke-Append2023Certificate', 'Invoke-RestoreDefaultVariable']:
    start = MAIN.index(f'function {fn}')
    next_fn = MAIN.find('\nfunction ', start + 10)
    body = MAIN[start: next_fn if next_fn != -1 else None]
    assert 'Set-TransactionPending' in body
    assert 'Set-TransactionStepComplete' in body
    assert 'Set-TransactionFailure' in body

# PK reboot cannot be skipped.
assert MAIN.index("$state.Classification = 'PkWrittenPendingReboot'") < MAIN.index("$state.Classification = 'Completed'")
assert "ResumeReason -eq 'ValidateAfterPK'" in MAIN

# OOBE is one integrated screen with countdown, scroll, backup path and exit.
for token in ['Countdown = 10', 'ScrolledBottom', '文件保存位置', '退出软件', '开始检测', '文件创建清单']:
    assert token in MAIN

# Live OOBE validation must not create folders; final confirmation does.
assert 'Get-BackupDirectoryValidation -Path $backupText.Text\n' in MAIN
assert 'Get-BackupDirectoryValidation -Path $backupText.Text -CreateIfMissing' in MAIN

# Main launcher/resume must request STA.
assert "'-STA'" in MAIN
assert '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass' in MAIN
for launcher in ['Start-Assistant.cmd', 'Start ASUS-ROG Secure Boot Assistant.cmd']:
    text = (ROOT / launcher).read_text(encoding='utf-8-sig')
    assert '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass' in text

# Privacy: diagnostic export must use a sanitized transaction object, not raw transaction paths.
assert 'Transaction = Get-LoggableTransaction $script:CurrentTransaction' in MAIN

# Fail-closed distinction: only STATUS_VARIABLE_NOT_FOUND is treated as a legitimate missing variable.
assert "0XC0000100" in MAIN
assert "$isMissing = ($code -eq '0XC0000100')" in MAIN
assert 'ActiveVariablesReadable' in MAIN and 'DefaultVariablesReadable' in MAIN

# Backup files must be immediately read back and compared byte-for-byte.
assert '备份文件逐字节回读失败' in MAIN
assert '备份SHA-256与固件回读不一致' in MAIN

# License is GPL-3.0, not MIT.
license_text = (ROOT / 'LICENSE.txt').read_text(encoding='utf-8')
assert 'GNU GENERAL PUBLIC LICENSE' in license_text
assert 'Version 3, 29 June 2007' in license_text
assert 'MIT License' not in license_text


# UI and file-lifecycle regression checks from rc9 screenshots and user requirements.
assert 'System.Object[]' not in MAIN
assert '[string]::Join([Environment]::NewLine' in MAIN
assert 'certificateMeta' not in MAIN
assert 'PrimaryPulseTimer' in MAIN and 'Interval = 650' in MAIN
assert 'Set-ContextButtonVisibility' in MAIN
assert "恢复未完成的修复流程" in MAIN
assert "保存修复流程恢复包" in MAIN
assert '查看软件创建的文件与目录' in MAIN
assert 'RequestedLanguage' in MAIN and 'Changing language reloads the main interface' in MAIN
assert 'This folder is not created before OOBE confirmation' in MAIN
assert 'The protected ProgramData state directory is intentionally not created before the user accepts the OOBE' in MAIN
assert MAIN.index('The protected ProgramData state directory is intentionally not created before the user accepts the OOBE') < MAIN.index('function Save-Settings')
assert 'Protect-AppDataDirectory -Path $script:AppDataRoot\n\n$createdNew' not in MAIN
assert 'SaveFileDialog' in MAIN and 'File created at:' in MAIN

print('STATIC_REQUIREMENTS_OK')

# Interrupted pending steps are reconciled only from hash-verified real UEFI state.
assert '已根据真实UEFI状态恢复事务进度' in MAIN
assert "'DbxWritten'       = @('DbDefault','Db2023','DbxDefault')" in MAIN

# Privileged state and resume metadata are protected and bound to an integrity hash.
assert "Join-Path $env:ProgramData 'ASUSROG-SecureBoot2023Assistant'" in MAIN
assert 'Protect-AppDataDirectory' in MAIN
assert 'TransactionSha256' in MAIN
assert '事务文件完整性校验失败' in MAIN
assert 'Test-PathsEqual' in MAIN and 'Test-PathIsUnderRoot' in MAIN
assert 'Test-InteractiveIdentityMatch' in MAIN

# Official rotation and BIOS entry are also gated by power, BitLocker, and pending reboot checks.
assert 'Assert-OfficialRotationPreconditions -State $state' in MAIN
assert '进入BIOS修改Secure Boot前' in MAIN

# Resume task is one-shot: the protected wrapper deletes the task before launching the GUI.
assert 'resume-launch.ps1' in MAIN
assert "Unregister-ScheduledTask -TaskName '$literalTask'" in MAIN
assert 'WindowStyle Hidden' in MAIN
assert (ROOT / 'Start ASUS-ROG Secure Boot Assistant.vbs').exists()

# External links are fixed HTTPS allow-list entries and opened through the registered default browser.
assert '$allowedUrls = @(' in MAIN
assert '$script:OfficialCertificateUrl' in MAIN and '$script:RepositoryUrl' in MAIN and '$script:AuthorUrl' in MAIN
assert "$uri.Scheme -ne 'https'" in MAIN
assert "AbsoluteUri.TrimEnd('/')" in MAIN
assert 'Open-TrustedUrl $script:OfficialCertificateUrl' in MAIN
assert '$startInfo.UseShellExecute = $true' in MAIN
assert r'Start-Process -FilePath "$env:SystemRoot\explorer.exe" -ArgumentList $uri.AbsoluteUri' not in MAIN


# Resume highest-privilege task must execute a hash-verified ProgramData runtime,
# never the mutable package script in Downloads/Desktop.
assert "ProtectedRuntimePath" in MAIN
assert "Copy-Item -LiteralPath $script:ProgramPath -Destination $script:ProtectedRuntimePath" in MAIN
assert "sourceHashBefore" in MAIN and "runtimeHash" in MAIN
register_start = MAIN.index('function Register-ResumeTask')
register_end = MAIN.index('function Remove-ResumeTaskSafe', register_start)
register_body = MAIN[register_start:register_end]
assert "$literalProgram = $script:ProtectedRuntimePath" in register_body
assert "$literalProgram = $PSCommandPath" not in register_body

# Backup location must fail closed on network/removable drives; the policy exception
# cannot be swallowed by a DriveInfo catch.
assert "DriveType -ne [IO.DriveType]::Fixed" in MAIN
assert "Unable to validate the drive" in MAIN
assert "Assert-NoReparsePoint -Path $script:BackupRoot" in MAIN

# If shutdown.exe rejects the restart, the one-shot task is removed and transaction state is rolled back.
assert '$shutdownExitCode = $LASTEXITCODE' in MAIN
assert 'Remove-ResumeTaskSafe' in MAIN[MAIN.index('function Invoke-RebootWithResume'):MAIN.index('function Suspend-BitLockerForWorkflow')]

# EXE compatibility: all path-sensitive operations use the resolved program path.
assert 'Get-CurrentProgramPath' in MAIN
assert '$script:ProgramPath = Get-CurrentProgramPath' in MAIN
assert '$script:IsCompiledExe' in MAIN
assert "@('-end', '-Language', $script:Language)" in MAIN
assert "ProtectedRuntimePath = Join-Path $script:ProtectedRuntimeRoot" in MAIN
assert "'ASUS-ROG-SecureBoot-2023-Assistant.exe'" in MAIN
assert "Start-Process -FilePath '$literalProgram' -ArgumentList @('-end','-Resume'" in MAIN
assert '$root = $script:ProgramRoot' in MAIN
assert 'ProgramSha256 = Get-FileHashHex -Path $script:ProgramPath' in MAIN
assert MAIN.count('$PSCommandPath') <= 2  # comments only; compiled path resolution uses argv[0]

build = (ROOT / 'Build-EXE.ps1').read_text(encoding='utf-8-sig')
for token in ['Invoke-ps2exe', 'requireAdmin', 'noConsole', 'STA', 'x64', 'checksums.sha256', 'Compress-Archive']:
    assert token in build
# Build bootstrap must solve Restricted execution policy without persisting a user/machine change.
assert 'Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass' in build
assert 'Unblock-File' in build
assert 'MachinePolicy or UserPolicy' in build
assert 'Set-ExecutionPolicy -Scope CurrentUser' not in build
assert 'Set-ExecutionPolicy -Scope LocalMachine' not in build
build_cmd = (ROOT / 'Build-EXE.cmd').read_text(encoding='utf-8-sig')
assert '-ExecutionPolicy Bypass -File' in build_cmd
assert (ROOT / 'Build-EXE.cmd').exists()
assert (ROOT / 'assets' / 'app.ico').exists()

# Regression: cmd.exe must see @echo off as the first bytes; UTF-8 BOM produces a bogus command.
build_cmd_bytes = (ROOT / 'Build-EXE.cmd').read_bytes()
assert not build_cmd_bytes.startswith(b'\xef\xbb\xbf')
assert build_cmd_bytes.startswith(b'@echo off')

# Regression: PowerShell backslash is not an escape character. Passing '\\' to
# TrimStart/TrimEnd is a two-character string and makes path validation fail closed
# for every package file. Use DirectorySeparatorChar/AltDirectorySeparatorChar.
assert ".TrimEnd('\\\\','/')" not in MAIN
assert ".TrimStart('\\\\','/')" not in MAIN
assert 'TrimEnd([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))' in MAIN
assert 'TrimStart([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))' in MAIN

# Regression: PS2EXE path resolution must use entry command metadata/argv[0], not
# prefer $PSCommandPath in a compiled build.
assert '$script:EntryCommandType' in MAIN
assert '[Environment]::GetCommandLineArgs()[0]' in MAIN

print('EXE_COMPATIBILITY_OK')

print('SECURITY_HARDENING_OK')


# Advanced recovery must never guess from key count: it requires exact backup/default/certificate evidence.
assert 'Get-RecoveryStageFromEvidence' in MAIN
assert '备份与当前固件Default变量不完全一致' in MAIN
assert 'Format-SecureBootUEFI -Name db' in MAIN
assert 'Confirm-AdvancedRecoveryWarning' in MAIN
assert "Origin = 'NormalRepair'" in MAIN
assert "Origin 'ImportedRecoveryPackage'" in MAIN
assert "Origin 'ManualEvidenceReconstruction'" in MAIN
assert 'No UEFI write was performed automatically' in MAIN
assert "Status = 'Locked'" in MAIN
assert 'NeedsReview' not in MAIN

# Recovery ZIP extraction must reject traversal and non-evidence file types.
assert 'Expand-RecoveryPackageSafe' in MAIN
assert "The recovery package contains a path traversal entry" in MAIN
assert "@('.json','.bin','.cer','.crt')" in MAIN

print('ADVANCED_RECOVERY_OK')
