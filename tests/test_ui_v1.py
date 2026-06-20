from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / 'ASUS-ROG-SecureBoot-2023-Assistant.ps1').read_text(encoding='utf-8-sig')
VERIFY = (ROOT / 'Verify-Package.ps1').read_text(encoding='ascii')

# Build verifier remains ASCII and parse-safe on Windows PowerShell 5.1.
assert 'PACKAGE_SHA256_OK' in VERIFY
assert all(ord(ch) < 128 for ch in VERIFY)

# Formal release version, no RC identifier.
assert "$script:AppVersion = '1.0.1.2'" in MAIN
assert '1.0.1.2-rc' not in MAIN

# Responsive/DPI contract.
assert MAIN.count("AutoScaleMode = 'Dpi'") >= 4
assert "FormBorderStyle = 'Sizable'" in MAIN
assert "MinimumSize = New-Object Drawing.Size(1040,900)" in MAIN
assert "MinimumSize = New-Object Drawing.Size(1180,880)" in MAIN

# OOBE long English text is separated into a short title, wrapped subtitle, short field label,
# and a word-wrapped scrollable creation-plan panel.
for token in [
    "'First-run setup'",
    'Choose a language, read the complete safety notice, and select where the assistant may store files.',
    "'Storage folder:'",
    '$title.UseCompatibleTextRendering = $true',
    '$subtitle.AutoEllipsis = $false',
    '$subtitle.UseCompatibleTextRendering = $true',
    '$backupLabel.AutoEllipsis = $false',
    '$backupLabel.UseCompatibleTextRendering = $true',
    '$filePlan = New-Object Windows.Forms.RichTextBox',
    '$filePlan.WordWrap = $true',
    "$filePlan.ScrollBars = 'Vertical'",
]:
    assert token in MAIN, token

# Detailed diagnostics keeps Result visible and the final English step fits.
assert '$detailsLayout = New-Object Windows.Forms.TableLayoutPanel' in MAIN
assert 'SizeType]::Percent, 41' in MAIN and 'SizeType]::Percent, 59' in MAIN
assert "$script:StepsList.Columns.Add((L '环节' 'Step'), 300)" in MAIN
assert 'Final verification / Factory Keys warning' in MAIN
assert '$script:Grid.Columns[1].MinimumWidth = 260' in MAIN

# Overview prioritizes result content.
assert '$script:OverviewGrid.Columns[0].FillWeight = 15' in MAIN
assert '$script:OverviewGrid.Columns[1].FillWeight = 85' in MAIN

# Grids remain locked against manual resizing, ordering, and sorting.
for token in [
    'AllowUserToOrderColumns = $false',
    'AllowUserToResizeColumns = $false',
    'AllowUserToResizeRows = $false',
    'DataGridViewTriState]::False',
    'Lock-ListViewColumnWidths',
    '$eventArgs.Cancel = $true',
]:
    assert token in MAIN, token

# Contextual next action and prior display regressions.
assert '$script:PrimaryButton.Visible = $false' in MAIN
assert '$script:PrimaryPulseTimer.Interval = 650' in MAIN
assert 'Set-ContextButtonVisibility' in MAIN
assert 'System.Object[]' not in MAIN
assert '[string]::Join([Environment]::NewLine' in MAIN
assert "'版本：{0}`r`n许可" not in MAIN
assert 'certificateMeta' not in MAIN

# Risk summary is split into a bold level heading and a wrapped explanation.
for token in [
    '$script:RiskPanel = New-Object Windows.Forms.Panel',
    '$script:RiskTitleLabel.Font = New-Object Drawing.Font',
    "'风险等级：{0}'",
    "'Risk level: {0}'",
    "$script:CurrentState.DefaultResetRiskLevel -eq 'High'" if False else "'Low' {",
    '[Drawing.Color]::FromArgb(232,245,233)',
    '主板BIOS固件预置的Default Keys中已经包含本次2023更新所需的证书条目',
    '$script:RiskPanel.Size = New-Object Drawing.Size(1180, 100)',
    '$script:WarningBox.Size = New-Object Drawing.Size(1162, 62)',
    '$script:WarningBox.AutoSize = $false',
    '$script:WarningBox.TextAlign = [Drawing.ContentAlignment]::TopLeft',
]:
    assert token in MAIN, token

print('UI_V1_OK')
