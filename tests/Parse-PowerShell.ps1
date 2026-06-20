param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$path = Join-Path $root 'ASUS-ROG-SecureBoot-2023-Assistant.ps1'
$tokens = $null
$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) {
    $errors | Format-List Message,Extent,ErrorId
    exit 1
}
Write-Host 'Windows PowerShell AST syntax check passed.' -ForegroundColor Green
