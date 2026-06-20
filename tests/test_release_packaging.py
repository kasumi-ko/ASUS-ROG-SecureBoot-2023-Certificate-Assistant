from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
BUILD = (ROOT / 'Build-EXE.ps1').read_text(encoding='utf-8-sig')
VERIFY = (ROOT / 'Verify-Package.ps1').read_text(encoding='ascii')

assert "$version = '1.0.1.2'" in BUILD
assert 'ASUS-ROG-SecureBoot-2023-Assistant-v$version-windows-x64' in BUILD
assert "Add-IfSupported $parameters $ps2exe 'version' '1.0.1.2'" in BUILD
assert "$exeConfigName = $exeName + '.config'" in BUILD
assert "Parameters.ContainsKey('longPaths')" in BUILD
assert "Add-IfSupported $parameters $ps2exe 'longPaths' $true" in BUILD
assert 'required .exe.config file for long-path support' in BUILD
for token in ["'README.txt'", "'LICENSE.txt'", "'checksums.sha256'", '$exeConfigName']:
    assert token in BUILD, token
assert 'Assert-ExactRuntimeLayout -Directory $stage' in BUILD
assert 'Expand-Archive -LiteralPath $zipPath' in BUILD
assert 'Assert-ExactRuntimeLayout -Directory $extractCheck' in BUILD
assert 'Invoke-PackageVerifier -Directory $extractCheck' in BUILD
assert "Compress-Archive -Path (Join-Path $stage '*')" in BUILD

for forbidden in [
    "Copy-ReleaseFile 'START-HERE-EXE.txt'",
    "New-Item -ItemType Directory -Path (Join-Path $stage 'source')",
    "'source\\Build-EXE.cmd'",
    "Copy-Item -LiteralPath (Join-Path $root 'tests')",
    "Copy-ReleaseFile 'README.md'",
    "Copy-ReleaseFile 'SECURITY.md'",
    "Copy-ReleaseFile 'Verify-Package.ps1'",
]:
    assert forbidden not in BUILD, forbidden

for obsolete in ['BUILD-EXE.md','START-HERE.txt','START-HERE-EXE.txt','BUILD-ONE-LINE.txt','FIXES-v1.0.0.txt']:
    assert not (ROOT / obsolete).exists(), obsolete

assert (ROOT / 'README_EN.md').exists()
assert '<a href="./README_EN.md">English</a>' in (ROOT / 'README.md').read_text(encoding='utf-8')
assert '<a href="./README.md">简体中文</a>' in (ROOT / 'README_EN.md').read_text(encoding='utf-8')
assert 'v1.0.1.2-windows-x64.zip' in (ROOT / 'README.md').read_text(encoding='utf-8')
assert 'ASUS-ROG-SecureBoot-2023-Assistant.exe.config' in (ROOT / 'README.md').read_text(encoding='utf-8')
assert 'ASUS-ROG-SecureBoot-2023-Assistant.exe.config' in (ROOT / 'GITHUB-PUBLISH-GUIDE.md').read_text(encoding='utf-8')
assert 'BUILD-EXE.md' not in (ROOT / 'README.md').read_text(encoding='utf-8')

for token in ['Unsafe manifest path','Duplicate manifest path','Manifest path escapes package root','File is not listed in checksums.sha256','Manifest entry has no matching package file']:
    assert token in VERIFY

match = re.search(r'\$runtimeLayout\s*=\s*@\((.*?)\)', BUILD, flags=re.S)
assert match, 'runtime layout declaration missing'
layout = match.group(1)
for item in ["$exeName", "$exeConfigName", "'README.txt'", "'LICENSE.txt'", "'checksums.sha256'"]:
    assert item in layout
assert layout.count(',') == 4

runtime = (ROOT / 'RUNTIME-README.txt').read_text(encoding='ascii')
assert 'v1.0.1.2' in runtime
assert '.exe.config beside the EXE' in runtime
assert (ROOT / 'RELEASE-NOTES-v1.0.1.2.md').exists()
assert not (ROOT / 'RELEASE-NOTES-v1.0.1.md').exists()
assert not (ROOT / 'RELEASE-NOTES-v1.0.1.1.md').exists()

print('RELEASE_PACKAGING_CONTRACT_OK')
