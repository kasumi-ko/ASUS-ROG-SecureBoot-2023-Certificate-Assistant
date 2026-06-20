from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / 'ASUS-ROG-SecureBoot-2023-Assistant.ps1').read_text(encoding='utf-8-sig')

# OOBE is freely resizable above a safe authored minimum.
for token in [
    '$form.Size = New-Object Drawing.Size(1040, 900)',
    '$form.MinimumSize = New-Object Drawing.Size(1040,900)',
    "$form.FormBorderStyle = 'Sizable'",
    "$risk.Anchor = 'Top, Bottom, Left, Right'",
    "$backupText.Anchor = 'Bottom, Left, Right'",
    "$continue.Anchor = 'Bottom, Right'",
]:
    assert token in MAIN, token

# Full-word English rendering contract.
for token in [
    '$title.UseCompatibleTextRendering = $true',
    '$subtitle.UseCompatibleTextRendering = $true',
    '$backupLabel.UseCompatibleTextRendering = $true',
    '$filePlan.WordWrap = $true',
]:
    assert token in MAIN, token

# Main form and tabs remain responsive.
for token in [
    '$form.Size = New-Object Drawing.Size(1240,920)',
    '$form.MinimumSize = New-Object Drawing.Size(1180,880)',
    "$tabs.Anchor = 'Top, Bottom, Left, Right'",
    "$script:OverviewGrid.Anchor = 'Top, Bottom, Left, Right'",
    "$script:LogBox.Anchor = 'Top, Bottom, Left, Right'",
    "$refresh.Anchor = 'Bottom, Right'",
    "$exit.Anchor = 'Bottom, Right'",
]:
    assert token in MAIN, token

# Detailed diagnostics reserves the larger pane for Check/Result.
for token in [
    '$detailsLayout = New-Object Windows.Forms.TableLayoutPanel',
    "$detailsLayout.Dock = 'Fill'",
    'SizeType]::Percent, 41',
    'SizeType]::Percent, 59',
    "$script:StepsList.Dock = 'Fill'",
    "$script:Grid.Dock = 'Fill'",
    '$script:Grid.Columns[0].FillWeight = 32',
    '$script:Grid.Columns[1].FillWeight = 68',
    '$script:Grid.Columns[1].MinimumWidth = 260',
]:
    assert token in MAIN, token

# About and recovery windows remain DPI-aware and resizable.
assert MAIN.count("AutoScaleMode = 'Dpi'") >= 4
assert "$about.FormBorderStyle = 'Sizable'" in MAIN
assert 'Recover an unfinished repair workflow' in MAIN


# Top risk area has a separate title/detail layout and keeps the rest of the minimum-size geometry intact.
for token in [
    '$script:RiskPanel.Size = New-Object Drawing.Size(1180, 100)',
    '$script:RiskTitleLabel.Size = New-Object Drawing.Size(1162, 24)',
    '$script:WarningBox.Size = New-Object Drawing.Size(1162, 62)',
    '$nextPanel.Location = New-Object Drawing.Point(20, 198)',
    '$tabs.Location = New-Object Drawing.Point(20, 290)',
    '$tabs.Size = New-Object Drawing.Size(1180, 481)',
]:
    assert token in MAIN, token

print('UI_LAYOUT_OK')
