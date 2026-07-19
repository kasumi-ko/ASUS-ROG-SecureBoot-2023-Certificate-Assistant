param(
    [switch]$Resume,
    [string]$ResumeReason = '',
    [ValidateSet('Auto','zh-CN','en-US')]
    [string]$Language = 'Auto'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# Capture entry-command metadata early. In a PS2EXE build, script-only
# variables such as $PSScriptRoot/$PSCommandPath are not reliable for locating the EXE.
$script:EntryCommandType = [string]$MyInvocation.MyCommand.CommandType
$script:EntryCommandDefinition = [string]$MyInvocation.MyCommand.Definition

function Get-DefaultAppLanguage {
    try {
        $culture = [Globalization.CultureInfo]::CurrentUICulture.Name
        if ($culture -match '^zh') { return 'zh-CN' }
    } catch {}
    return 'en-US'
}

$script:Language = if ($Language -eq 'Auto') { Get-DefaultAppLanguage } else { $Language }

function L {
    param(
        [Parameter(Mandatory)][string]$Zh,
        [Parameter(Mandatory)][string]$En
    )
    if ($script:Language -eq 'en-US') { return $En }
    return $Zh
}

function Set-AppLanguage {
    param([ValidateSet('zh-CN','en-US')][string]$Value)
    $script:Language = $Value
    $script:AppName = L 'ASUS/ROG Secure Boot 2023 助手' 'ASUS/ROG Secure Boot 2023 Assistant'
}

function Get-LocalizedFontName {
    if ($script:Language -eq 'en-US') { return 'Segoe UI' }
    return 'Microsoft YaHei UI'
}

function Get-ClassificationDisplay {
    param([string]$Code)
    $map = @{
        UnsupportedLegacy = @('不支持：Legacy/非UEFI启动','Unsupported: Legacy/non-UEFI boot')
        ReadOnlyNonAsus = @('只读：非ASUS/ROG设备','Read-only: non-ASUS/ROG device')
        FirmwareVariableReadFailure = @('固件变量读取失败','Firmware variable read failure')
        PkWrittenPendingReboot = @('PK已写入，重启后复查','PK written. Restart is required for verification')
        BlockedUnsafe = @('状态异常，已禁止写入','Unsafe state. Writes are blocked')
        AdvancedRecoveryRequired = @('需要恢复校验资料','Recovery information required')
        Completed = @('2023轮换已完成','2023 rotation completed')
        TransactionMismatch = @('上次进度与设备状态不匹配','Saved progress does not match this device')
        MissingDefaultVariables = @('BIOS 默认 Keys 缺失或为空','BIOS factory Keys missing or empty')
        ReadyForRepair = @('可以按步骤修复','Ready to repair')
        RecoverableIntermediate = @('可恢复的中间状态','Recoverable intermediate state')
        AbnormalPartialKeys = @('异常的部分Keys状态','Abnormal partial-key state')
        OfficialRotationError = @('官方轮换错误','Official rotation error')
        UpdatedButVerificationMismatch = @('Windows状态与证书验证不一致','Windows status/certificate verification mismatch')
        OfficialRotationNeedsReboot = @('官方轮换需要重启','Official rotation requires restart')
        NeedsOfficialRotation = @('需要运行微软官方轮换','Microsoft official rotation required')
        SecureBootDisabledWithKeys = @('Keys完整但Secure Boot未启用','Keys present but Secure Boot disabled')
        BootChainRepairRequired = @('启动链需修复后再启用Secure Boot','Boot chain repair required before enabling Secure Boot')
        BootChainReviewRequired = @('启动链需要先排查后再启用Secure Boot','Boot chain review required before enabling Secure Boot')
        InvalidSetupModeState = @('无效的Setup Mode状态','Invalid Setup Mode state')
        NeedsFirmwareSetup = @('需要进入UEFI Setup Mode','UEFI Setup Mode required')
    }
    if ($map.ContainsKey($Code)) { return L $map[$Code][0] $map[$Code][1] }
    return $Code
}

function Get-StepStatusDisplay {
    param([string]$Status)
    $map = @{
        Pending = @('待执行','Pending')
        Complete = @('完成','Complete')
        Failed = @('失败','Failed')
        Scheduled = @('已安排','Scheduled')
        Locked = @('已锁定','Locked')
        '待处理' = @('待处理','Pending')
        '通过' = @('通过','Passed')
        '阻止' = @('阻止','Blocked')
    }
    if ($map.ContainsKey($Status)) { return L $map[$Status][0] $map[$Status][1] }
    return $Status
}

function Get-DefaultResetRiskLevelDisplay {
    param([string]$Level)
    $map = @{
        Unknown = @('未知','Unknown')
        High = @('高','High')
        Warning = @('注意','Warning')
        Low = @('较低','Low')
        Pending = @('待评估','Pending assessment')
    }
    if ($map.ContainsKey($Level)) { return L $map[$Level][0] $map[$Level][1] }
    return $Level
}

# ASUS/ROG Secure Boot 2023 checker and repair assistant
# Target runtime: Windows 10/11, Windows PowerShell 5.1, administrator rights

function Get-CurrentProgramPath {
    # Script mode: use the entry script definition. PS2EXE mode: use argv[0], which
    # is the generated executable path. Do not prefer $PSCommandPath in a compiled
    # build: PS2EXE documents that script-related variables are not reliable there.
    if ($script:EntryCommandType -eq 'ExternalScript') {
        $candidate = [string]$script:EntryCommandDefinition
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
            return [IO.Path]::GetFullPath($candidate)
        }
    }

    try {
        $argv0 = [string]([Environment]::GetCommandLineArgs()[0])
        if (-not [string]::IsNullOrWhiteSpace($argv0) -and (Test-Path -LiteralPath $argv0)) {
            return [IO.Path]::GetFullPath($argv0)
        }
    } catch {}

    try {
        $processPath = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        if (-not [string]::IsNullOrWhiteSpace($processPath) -and (Test-Path -LiteralPath $processPath)) {
            return [IO.Path]::GetFullPath($processPath)
        }
    } catch {}
    throw 'Unable to resolve the current program path.'
}

$script:ProgramPath = Get-CurrentProgramPath
$script:ProgramRoot = Split-Path -Parent $script:ProgramPath
$script:IsCompiledExe = ([IO.Path]::GetExtension($script:ProgramPath) -ieq '.exe')
$script:ProgramKind = if ($script:IsCompiledExe) { 'PS2EXE' } else { 'PowerShellScript' }

$script:AppName = L 'ASUS/ROG Secure Boot 2023 助手' 'ASUS/ROG Secure Boot 2023 Assistant'
$script:AppVersion = '1.4'
$script:AuthorName = '霞詩'
$script:AuthorPlatform = '@BILIBILI'
$script:AuthorUrl = 'https://space.bilibili.com/4216920'
$script:RepositoryUrl = 'https://github.com/kasumi-ko/ASUS-ROG-SecureBoot-2023-Assistant'
$script:LicenseName = 'GNU GPL v3.0'
$script:OobeVersion = '2026-07-19-v1.4-r1'
$script:OfficialCertificateUrl = 'https://go.microsoft.com/fwlink/?linkid=2239776'
$script:OfficialCertificateFileName = 'Windows UEFI CA 2023.cer'
$script:OfficialCertificateSize = 1454
$script:OfficialCertificateSha256 = '076F1FEA90AC29155EBF77C17682F75F1FDD1BE196DA302DC8461E350A9AE330'
$script:OfficialCertificateThumbprint = '45A0FA32604773C82433C3B7D59E7466B3AC0C67'
$script:OfficialCertificateSubject = 'CN=Windows UEFI CA 2023, O=Microsoft Corporation, C=US'
$script:OfficialCertificateIssuer = 'CN=Microsoft Root Certificate Authority 2010, O=Microsoft Corporation, L=Redmond, S=Washington, C=US'
$script:OfficialCertificateSignatureOwner = [Guid]'77fa9abd-0359-4d32-bd60-28f4e78f784b'
$script:AvailableUpdatesAll = 0x5944
$script:AvailableUpdatesComplete = 0x4000
$script:ResumeTaskName = 'ASUSROG-SecureBoot2023-Resume'
$script:AppDataRoot = Join-Path $env:ProgramData 'ASUSROG-SecureBoot2023Assistant'
$script:SettingsPath = Join-Path $script:AppDataRoot 'settings.json'
$script:TransactionMirrorPath = Join-Path $script:AppDataRoot 'current-transaction.json'
$script:ResumeLauncherPath = Join-Path $script:AppDataRoot 'resume-launch.ps1'
$script:ProtectedRuntimeRoot = Join-Path $script:AppDataRoot 'runtime'
$script:ProtectedRuntimePath = Join-Path $script:ProtectedRuntimeRoot $(if ($script:IsCompiledExe) { 'ASUS-ROG-SecureBoot-2023-Assistant.exe' } else { 'ASUS-ROG-SecureBoot-2023-Assistant.ps1' })
$script:ProtectedEvidenceRoot = Join-Path $script:AppDataRoot 'evidence'
$script:SessionId = [Guid]::NewGuid().ToString('N')
$script:SessionLogRoot = $null
$script:BackupRoot = $null
$script:CurrentTransaction = $null
$script:CurrentState = $null
$script:DeveloperModeEnabled = $false
$script:DeveloperForceActive = $false
$script:DeveloperModeAcknowledgedAt = $null
$script:PendingRebootOverride = $false
$script:PendingRebootOverrideAcknowledgedAt = $null
$script:SelectedCertificatePath = $null
$script:MainForm = $null
$script:Grid = $null
$script:StepsList = $null
$script:StatusLabel = $null
$script:RiskPanel = $null
$script:RiskTitleLabel = $null
$script:WarningBox = $null
$script:PrimaryButton = $null
$script:CertificateButton = $null
$script:OfficialButton = $null
$script:RestartButton = $null
$script:RecoveryImportButton = $null
$script:RecoveryExportButton = $null
$script:LogBox = $null
$script:OverviewGrid = $null
$script:NextActionLabel = $null
$script:ActionBlockReasonLabel = $null
$script:ContextActionsPanel = $null
$script:CertificateSourceButton = $null
$script:PendingOverrideButton = $null
$script:DeveloperForceButton = $null
$script:DeveloperModeStatusLabel = $null
$script:BitLockerButton = $null
$script:MainToolTip = $null
$script:CreatedFilesButton = $null
$script:OpenLogsButton = $null
$script:OpenBackupButton = $null
$script:ExportDiagnosticsButton = $null
$script:LanguageBox = $null
$script:RequestedLanguage = $null
$script:PrimaryPulseTimer = $null
$script:ResumeDetected = $Resume.IsPresent
$script:TransactionLoadError = ''

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-InteractiveIdentityMatch {
    try {
        $interactive = [string](Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).UserName
        $current = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        if ([string]::IsNullOrWhiteSpace($interactive)) { return $true }
        return [string]::Equals($interactive, $current, [StringComparison]::OrdinalIgnoreCase)
    } catch {
        return $false
    }
}

function Protect-AppDataDirectory {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null
    }

    $admins = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
    $system = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
    $allow = [Security.AccessControl.AccessControlType]::Allow
    $full = [Security.AccessControl.FileSystemRights]::FullControl

    $applyAcl = {
        param([IO.FileSystemInfo]$Item)
        if (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw (L ('受保护状态目录中存在重解析点，已停止运行：' + $Item.FullName) ('A reparse point was found in the protected state directory. Operation stopped: ' + $Item.FullName))
        }
        if ($Item.PSIsContainer) {
            $security = New-Object Security.AccessControl.DirectorySecurity
            $inherit = [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
            $propagation = [Security.AccessControl.PropagationFlags]::None
        } else {
            $security = New-Object Security.AccessControl.FileSecurity
            $inherit = [Security.AccessControl.InheritanceFlags]::None
            $propagation = [Security.AccessControl.PropagationFlags]::None
        }
        $security.SetAccessRuleProtection($true, $false)
        $security.SetOwner($admins)
        $security.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($admins, $full, $inherit, $propagation, $allow)))
        $security.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($system, $full, $inherit, $propagation, $allow)))
        Set-Acl -LiteralPath $Item.FullName -AclObject $security -ErrorAction Stop
    }

    $rootItem = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    & $applyAcl $rootItem

    # Secure pre-existing children without following junctions/symlinks. This prevents a
    # low-privilege user from pre-creating mutable resume metadata.
    $stack = New-Object 'System.Collections.Generic.Stack[string]'
    $stack.Push($rootItem.FullName)
    while ($stack.Count -gt 0) {
        $current = $stack.Pop()
        foreach ($child in @(Get-ChildItem -LiteralPath $current -Force -ErrorAction Stop)) {
            if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw (L ('受保护状态目录中存在重解析点，已停止运行：' + $child.FullName) ('A reparse point was found in the protected state directory. Operation stopped: ' + $child.FullName))
            }
            & $applyAcl $child
            if ($child.PSIsContainer) { $stack.Push($child.FullName) }
        }
    }
}

function Restart-Elevated {
    if ($script:IsCompiledExe) {
        # -end prevents PS2EXE's own runtime switches from consuming application arguments.
        $args = @('-end', '-Language', $script:Language)
        if ($Resume) {
            $args += '-Resume'
            if ($ResumeReason) { $args += @('-ResumeReason', $ResumeReason) }
        }
        Start-Process -FilePath $script:ProgramPath -ArgumentList $args -Verb RunAs
    } else {
        $args = @(
            '-NoProfile',
            '-STA',
            '-WindowStyle', 'Hidden',
            '-ExecutionPolicy', 'Bypass',
            '-File', ('"{0}"' -f $script:ProgramPath)
        )
        $args += '-Language'
        $args += $script:Language
        if ($Resume) {
            $args += '-Resume'
            if ($ResumeReason) {
                $args += '-ResumeReason'
                $args += ('"{0}"' -f $ResumeReason.Replace('"','\"'))
            }
        }
        Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList ($args -join ' ') -Verb RunAs
    }
    exit
}

if (-not (Test-IsAdministrator)) {
    Restart-Elevated
}

if (-not (Test-InteractiveIdentityMatch)) {
    [System.Windows.Forms.MessageBox]::Show((L '当前管理员账户与正在登录的 Windows 账户不一致。请从当前登录账户以管理员身份运行。' 'The elevated administrator account does not match the signed-in Windows account. Run the app as administrator from the signed-in account.'), $script:AppName, 'OK', 'Error') | Out-Null
    exit
}

# The protected ProgramData state directory is created after OOBE confirmation.
# Save-Settings or a confirmed recovery/resume operation creates it.

$createdNew = $false
$script:Mutex = New-Object Threading.Mutex($true, 'Global\ASUSROG-SecureBoot2023Assistant', [ref]$createdNew)
if (-not $createdNew) {
    [System.Windows.Forms.MessageBox]::Show((L '程序已经在运行。' 'The app is already running.'), $script:AppName, 'OK', 'Information') | Out-Null
    exit
}

function ConvertTo-Hashtable {
    param([object]$InputObject)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($key in $InputObject.Keys) { $result[$key] = ConvertTo-Hashtable $InputObject[$key] }
        return $result
    }
    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $result = @{}
        foreach ($property in $InputObject.PSObject.Properties) { $result[$property.Name] = ConvertTo-Hashtable $property.Value }
        return $result
    }
    if (($InputObject -is [System.Collections.IEnumerable]) -and -not ($InputObject -is [string])) {
        $list = @()
        foreach ($item in $InputObject) { $list += ,(ConvertTo-Hashtable $item) }
        return $list
    }
    return $InputObject
}

function Get-NormalizedFullPath {
    param([Parameter(Mandatory)][string]$Path)
    return ([IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Path))).TrimEnd([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
}

function Test-PathIsUnderRoot {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Root,
        [switch]$AllowRoot
    )
    try {
        $fullPath = Get-NormalizedFullPath $Path
        $fullRoot = Get-NormalizedFullPath $Root
        if ($AllowRoot -and [string]::Equals($fullPath, $fullRoot, [StringComparison]::OrdinalIgnoreCase)) { return $true }
        $prefix = $fullRoot + [IO.Path]::DirectorySeparatorChar
        return $fullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
    } catch {
        return $false
    }
}

function Test-PathContainsReparsePoint {
    param([Parameter(Mandatory)][string]$Path)
    try {
        $full = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Path))
        $root = [IO.Path]::GetPathRoot($full)
        if ([string]::IsNullOrWhiteSpace($root)) { return $true }
        $relative = $full.Substring($root.Length).TrimStart([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
        $current = $root
        if (Test-Path -LiteralPath $current) {
            $rootItem = Get-Item -LiteralPath $current -Force -ErrorAction Stop
            if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $true }
        }
        foreach ($segment in @($relative -split '[\\/]' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
            $current = Join-Path $current $segment
            if (-not (Test-Path -LiteralPath $current)) { continue }
            $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $true }
        }
        return $false
    } catch {
        return $true
    }
}

function Assert-NoReparsePoint {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-PathContainsReparsePoint -Path $Path) {
        throw (L '所选路径包含符号链接、目录联接或其他重解析点。请选择普通本地文件夹。' 'The selected path contains a symbolic link, directory junction, or another reparse point. Select a regular local folder.')
    }
}


function Assert-PackageIntegrity {
    if ($Resume) { return }
    $root = $script:ProgramRoot
    $manifestPath = Join-Path $root 'checksums.sha256'
    if (-not (Test-Path -LiteralPath $manifestPath)) { throw (L '软件包缺少 checksums.sha256，已停止运行。' 'The package is missing checksums.sha256. Operation stopped.') }
    $failures = @()
    foreach ($line in @(Get-Content -LiteralPath $manifestPath -ErrorAction Stop)) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
        $parts = $line -split '\s{2,}', 2
        if ($parts.Count -ne 2) { $failures += (L '校验清单格式错误。' 'Invalid checksum manifest format.'); continue }
        $expected = $parts[0].Trim().ToUpperInvariant()
        $relative = $parts[1].Trim()
        $path = Join-Path $root $relative
        if (-not (Test-PathIsUnderRoot -Path $path -Root $root) -or -not (Test-Path -LiteralPath $path)) {
            $failures += ((L '缺少或越界文件：{0}' 'Missing or out-of-bounds file: {0}') -f $relative)
            continue
        }
        if (Test-PathContainsReparsePoint -Path $path) { $failures += ((L '文件路径包含重解析点：{0}' 'File path contains a reparse point: {0}') -f $relative); continue }
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToUpperInvariant()
        if ($actual -ne $expected) { $failures += ((L 'SHA-256不匹配：{0}' 'SHA-256 mismatch: {0}') -f $relative) }
    }
    if ($failures.Count -gt 0) { throw ((L '软件包完整性校验失败：' 'Package integrity validation failed: ') + ($failures -join ', ')) }
}

function Test-PathsEqual {
    param(
        [string]$First,
        [string]$Second
    )
    try {
        if ([string]::IsNullOrWhiteSpace($First) -or [string]::IsNullOrWhiteSpace($Second)) { return $false }
        return [string]::Equals((Get-NormalizedFullPath $First), (Get-NormalizedFullPath $Second), [StringComparison]::OrdinalIgnoreCase)
    } catch {
        return $false
    }
}


function Write-JsonAtomic {
    param(
        [Parameter(Mandatory)][string]$Path,
        [AllowNull()][object]$Object = $null,
        [int]$Depth = 10
    )
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $temp = "$Path.tmp.$PID"
    if ($null -eq $Object) {
        $json = 'null'
    } elseif ($Object -is [System.Array] -and $Object.Count -eq 0) {
        $json = '[]'
    } else {
        $json = ConvertTo-Json -InputObject $Object -Depth $Depth
        if ($null -eq $json) { $json = 'null' }
    }
    [IO.File]::WriteAllText($temp, $json, (New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Read-JsonSafe {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        $raw = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return ConvertTo-Hashtable ($raw | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Get-OptionalPropertyValue {
    param(
        [object]$Object,
        [Parameter(Mandatory)][string]$Name,
        [object]$Default = $null
    )
    if ($null -eq $Object) { return $Default }
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $Default
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

function Get-SystemBootTime {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $value = Get-OptionalPropertyValue -Object $os -Name 'LastBootUpTime'
        if ($null -eq $value) { return $null }
        return [datetime]$value
    } catch {
        return $null
    }
}

function Protect-EventMessagePrivacy {
    param([string]$Message)
    if ([string]::IsNullOrEmpty($Message)) { return $Message }
    $safe = $Message
    foreach ($field in @('SerialNumber','SystemSerialNumber','ChassisSerialNumber','UUID')) {
        $safe = [regex]::Replace(
            $safe,
            ('(?i)({0})\s*[:=]\s*[^;\r\n]+' -f [regex]::Escape($field)),
            ('${1}:[REDACTED]')
        )
    }
    return $safe
}

function Open-TrustedUrl {
    param([Parameter(Mandatory)][string]$Url)
    $uri = [Uri]$Url
    $allowedUrls = @(
        $script:OfficialCertificateUrl,
        $script:RepositoryUrl,
        $script:AuthorUrl
    )
    $allowed = $false
    foreach ($candidate in $allowedUrls) {
        $candidateUri = [Uri]$candidate
        if ([string]::Equals($uri.AbsoluteUri.TrimEnd('/'), $candidateUri.AbsoluteUri.TrimEnd('/'), [StringComparison]::OrdinalIgnoreCase)) {
            $allowed = $true
            break
        }
    }
    if ($uri.Scheme -ne 'https' -or -not $allowed) {
        throw (L '此 URL 不在允许打开的 Microsoft HTTPS 地址中。' 'This URL is not in the allowed Microsoft HTTPS address list.')
    }

    # UseShellExecute invokes the user's registered default browser. Passing an HTTPS
    # URL to explorer.exe can open File Explorer instead on some Windows builds.
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $uri.AbsoluteUri
    $startInfo.UseShellExecute = $true
    [Diagnostics.Process]::Start($startInfo) | Out-Null
}

function Get-DefaultBackupRoot {
    $specialFolderType = [Environment].GetNestedType('SpecialFolder')
    $myDocuments = [Enum]::Parse($specialFolderType, 'MyDocuments')
    $documents = [Environment]::GetFolderPath($myDocuments)
    if ([string]::IsNullOrWhiteSpace($documents)) { $documents = $env:USERPROFILE }
    return (Join-Path $documents 'ASUS-ROG Secure Boot Backup')
}

function Test-WritableDirectory {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return $false }
    # CreateIfMissing is safe here because the directory already exists; it only performs
    # the write probe. Missing saved folders are never recreated without showing OOBE.
    return (Get-BackupDirectoryValidation -Path $Path -CreateIfMissing).IsValid
}

function Get-BackupDirectoryValidation {
    param(
        [string]$Path,
        [switch]$CreateIfMissing
    )
    $result = [ordered]@{
        IsValid = $false
        IsWritable = $false
        FreeBytes = [int64]0
        IsNetworkPath = $false
        DriveType = ''
        ResolvedPath = ''
        Error = ''
    }
    try {
        if ([string]::IsNullOrWhiteSpace($Path)) { throw '备份目录为空。' }
        $candidate = [Environment]::ExpandEnvironmentVariables($Path.Trim())
        if (-not [IO.Path]::IsPathRooted($candidate)) { throw '备份目录必须使用绝对路径。' }
        $result.IsNetworkPath = $candidate.StartsWith('\\')
        if ($result.IsNetworkPath) { throw (L '为保证重启续跑和恢复可靠，备份目录不能使用网络/UNC路径。请选择本地固定磁盘。' 'For reliable restart resume and transaction recovery, the backup folder cannot be a network/UNC path. Select a local fixed disk.') }

        $targetExists = Test-Path -LiteralPath $candidate
        if ($targetExists) {
            $item = Get-Item -LiteralPath $candidate -ErrorAction Stop
            if (-not $item.PSIsContainer) { throw '选择的路径不是文件夹。' }
            $resolved = $item.FullName
            $probeRoot = $resolved
        } else {
            $resolved = [IO.Path]::GetFullPath($candidate)
            $parent = Split-Path -Parent $resolved
            while ($parent -and -not (Test-Path -LiteralPath $parent)) {
                $next = Split-Path -Parent $parent
                if ($next -eq $parent) { break }
                $parent = $next
            }
            if (-not $parent -or -not (Test-Path -LiteralPath $parent)) { throw '找不到可用的上级目录。' }
            if ($CreateIfMissing) {
                New-Item -ItemType Directory -Path $resolved -Force -ErrorAction Stop | Out-Null
                $probeRoot = $resolved
            } else {
                # During OOBE input, probe only the nearest existing parent folder to avoid creating folders for unfinished paths.
                $probeRoot = (Resolve-Path -LiteralPath $parent -ErrorAction Stop).Path
            }
        }

        Assert-NoReparsePoint -Path $probeRoot
        if ($CreateIfMissing) { Assert-NoReparsePoint -Path $resolved }

        if ($CreateIfMissing) {
            $probe = Join-Path $probeRoot ('.write-test-{0}.tmp' -f [Guid]::NewGuid().ToString('N'))
            [IO.File]::WriteAllText($probe, 'ASUSROG-SecureBoot-Backup-Probe', [Text.Encoding]::ASCII)
            Remove-Item -LiteralPath $probe -Force
        }
        $result.IsWritable = $true
        $result.ResolvedPath = $resolved

        try {
            $root = [IO.Path]::GetPathRoot($resolved)
            if (-not $root) { throw (L '无法确定备份目录所在磁盘。' 'Unable to determine the drive that contains the backup folder.') }
            $drive = New-Object IO.DriveInfo($root)
            $result.DriveType = $drive.DriveType.ToString()
            if ($drive.IsReady) { $result.FreeBytes = [int64]$drive.AvailableFreeSpace }
        } catch {
            throw (L ('无法验证备份目录所在磁盘：' + $_.Exception.Message) ('Unable to validate the drive that contains the backup folder: ' + $_.Exception.Message))
        }
        if ($drive.DriveType -ne [IO.DriveType]::Fixed) {
            throw (L ('备份目录必须位于本地固定磁盘。当前类型：' + $drive.DriveType) ('The backup folder must be on a local fixed disk. Current type: ' + $drive.DriveType))
        }
        if (-not $result.IsNetworkPath -and $result.FreeBytes -gt 0 -and $result.FreeBytes -lt 20971520) {
            throw '备份目录所在磁盘可用空间不足20 MB。'
        }
        $result.IsValid = $true
    } catch {
        $result.Error = $_.Exception.Message
    }
    return [pscustomobject]$result
}

function Get-PendingWindowsRebootState {
    $sources = New-Object Collections.Generic.List[string]
    $renameItems = @()
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        [void]$sources.Add('CBS RebootPending')
    }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        [void]$sources.Add('Windows Update RebootRequired')
    }
    try {
        $volatile = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Updates' -Name UpdateExeVolatile -ErrorAction Stop
        if ([int]$volatile -ne 0) { [void]$sources.Add(('UpdateExeVolatile={0}' -f $volatile)) }
    } catch {}
    try {
        $pending = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
        if ($null -ne $pending.PendingFileRenameOperations) {
            $renameItems = @($pending.PendingFileRenameOperations | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
            if ($renameItems.Count -gt 0) { [void]$sources.Add('PendingFileRenameOperations') }
        }
    } catch {}
    return [pscustomobject]@{
        IsPending = ($sources.Count -gt 0)
        Sources = @($sources)
        PendingFileRenameOperations = @($renameItems)
        Summary = if ($sources.Count -gt 0) { $sources -join ', ' } else { '' }
        OverrideActive = [bool]$script:PendingRebootOverride
    }
}

function Test-PendingWindowsReboot {
    return [bool](Get-PendingWindowsRebootState).IsPending
}

function Get-FileHashHex {
    param([Parameter(Mandatory)][string]$Path, [ValidateSet('SHA256','MD5','SHA1')][string]$Algorithm = 'SHA256')
    return (Get-FileHash -LiteralPath $Path -Algorithm $Algorithm).Hash.ToUpperInvariant()
}

function Get-ByteHashHex {
    param([Parameter(Mandatory)][byte[]]$Bytes, [ValidateSet('SHA256','MD5','SHA1')][string]$Algorithm = 'SHA256')
    $algorithmObject = switch ($Algorithm) {
        'SHA256' { [Security.Cryptography.SHA256]::Create() }
        'SHA1'   { [Security.Cryptography.SHA1]::Create() }
        'MD5'    { [Security.Cryptography.MD5]::Create() }
    }
    try {
        return ([BitConverter]::ToString($algorithmObject.ComputeHash($Bytes))).Replace('-','')
    } finally {
        $algorithmObject.Dispose()
    }
}

function Test-ByteArrayEqual {
    param([byte[]]$A, [byte[]]$B)
    if ($null -eq $A -or $null -eq $B -or $A.Length -ne $B.Length) { return $false }
    for ($i = 0; $i -lt $A.Length; $i++) { if ($A[$i] -ne $B[$i]) { return $false } }
    return $true
}

function Test-ContainsByteSequence {
    param([byte[]]$Container, [byte[]]$Sequence)
    if ($null -eq $Container -or $null -eq $Sequence -or $Sequence.Length -eq 0 -or $Container.Length -lt $Sequence.Length) { return $false }
    for ($i = 0; $i -le $Container.Length - $Sequence.Length; $i++) {
        $match = $true
        for ($j = 0; $j -lt $Sequence.Length; $j++) {
            if ($Container[$i + $j] -ne $Sequence[$j]) { $match = $false; break }
        }
        if ($match) { return $true }
    }
    return $false
}

function Join-ByteArrays {
    param([byte[]]$First, [byte[]]$Second)
    $result = New-Object byte[] ($First.Length + $Second.Length)
    [Buffer]::BlockCopy($First, 0, $result, 0, $First.Length)
    [Buffer]::BlockCopy($Second, 0, $result, $First.Length, $Second.Length)
    return $result
}

function Write-UiLog {
    param([string]$Message, [ValidateSet('INFO','WARN','ERROR','SUCCESS')][string]$Level = 'INFO')
    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'HH:mm:ss'), $Level, $Message
    if ($script:LogBox) {
        $script:LogBox.AppendText($line + [Environment]::NewLine)
        $script:LogBox.SelectionStart = $script:LogBox.TextLength
        $script:LogBox.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }
    if ($script:SessionLogRoot) {
        Add-Content -LiteralPath (Join-Path $script:SessionLogRoot 'app.log') -Value $line -Encoding UTF8
    }
}

function Start-SessionLog {
    param([string]$BackupRoot)
    if (-not $BackupRoot) { return }
    $logsRoot = Join-Path $BackupRoot 'Logs'
    if (-not (Test-Path $logsRoot)) { New-Item -ItemType Directory -Path $logsRoot -Force | Out-Null }
    $folderName = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $script:SessionId.Substring(0,8)
    $script:SessionLogRoot = Join-Path $logsRoot $folderName
    New-Item -ItemType Directory -Path $script:SessionLogRoot -Force | Out-Null
    $appInfo = [ordered]@{
        AppName = $script:AppName
        AppVersion = $script:AppVersion
        SessionId = $script:SessionId
        StartedAt = (Get-Date).ToString('o')
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        IsResumeLaunch = $script:ResumeDetected
        ResumeReason = $ResumeReason
        ProgramSha256 = Get-FileHashHex -Path $script:ProgramPath -Algorithm SHA256
        ProgramKind = $script:ProgramKind
        ProgramPath = $script:ProgramPath
    }
    Write-JsonAtomic -Path (Join-Path $script:SessionLogRoot 'app-info.json') -Object $appInfo
}

function Get-RecentSecureBootEvents {
    param([datetime]$StartTime = (Get-Date).AddDays(-7))
    $eventIds = @(1032,1036,1037,1043,1044,1045,1795,1796,1797,1799,1800,1801,1802,1803,1808)
    try {
        $events = Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            ProviderName = 'Microsoft-Windows-TPM-WMI'
            StartTime = $StartTime
        } -ErrorAction Stop | Where-Object { $eventIds -contains $_.Id } | Select-Object -First 100
        return @($events | ForEach-Object {
            [ordered]@{
                TimeCreated = $_.TimeCreated.ToString('o')
                Id = $_.Id
                Level = $_.LevelDisplayName
                Message = Protect-EventMessagePrivacy -Message ([string]$_.Message)
            }
        })
    } catch {
        return @()
    }
}

function Export-DiagnosticSnapshot {
    param([object]$State, [string]$Reason = 'Snapshot')
    if (-not $script:SessionLogRoot -or $null -eq $State) { return }
    try {
        $safeState = Get-LoggableState $State
        $events = @(Get-RecentSecureBootEvents -StartTime (Get-Date).AddDays(-30))
        $payload = [ordered]@{
            CapturedAt = (Get-Date).ToString('o')
            Reason = $Reason
            State = $safeState
            Events = $events
            Transaction = Get-LoggableTransaction $script:CurrentTransaction
        }
        Write-JsonAtomic -Path (Join-Path $script:SessionLogRoot 'diagnostic.json') -Object $payload -Depth 12
        Write-JsonAtomic -Path (Join-Path $script:SessionLogRoot 'events.json') -Object $events -Depth 8
        Update-SummaryFile -State $State -Reason $Reason
    } catch {
        try { Write-UiLog ((L '诊断报告写入失败，不影响当前检测结果：{0}' 'Diagnostic snapshot write failed. Current detection continues: {0}') -f $_.Exception.Message) 'WARN' } catch {}
    }
}

function Append-StateHistory {
    param([object]$State, [string]$Reason)
    if (-not $script:SessionLogRoot -or $null -eq $State) { return }
    $entry = [ordered]@{
        Time = (Get-Date).ToString('o')
        Reason = $Reason
        State = Get-LoggableState $State
    }
    $line = $entry | ConvertTo-Json -Depth 8 -Compress
    Add-Content -LiteralPath (Join-Path $script:SessionLogRoot 'state-history.jsonl') -Value $line -Encoding UTF8
}

function Get-LoggableTransaction {
    param([System.Collections.IDictionary]$Transaction)
    if ($null -eq $Transaction) { return $null }
    return [ordered]@{
        SchemaVersion = $Transaction.SchemaVersion
        TransactionId = $Transaction.TransactionId
        Status = $Transaction.Status
        CurrentStep = $Transaction.CurrentStep
        PendingOperation = $Transaction.PendingOperation
        CreatedAt = $Transaction.CreatedAt
        UpdatedAt = $Transaction.UpdatedAt
        Device = $Transaction.Device
        DefaultLengths = $Transaction.DefaultLengths
        ExpectedHashes = $Transaction.ExpectedHashes
        Certificate = [ordered]@{
            Validated = $Transaction.Certificate.Validated
            SHA256 = $Transaction.Certificate.SHA256
            MD5 = $Transaction.Certificate.MD5
            Thumbprint = $Transaction.Certificate.Thumbprint
            FormattedLength = $Transaction.Certificate.FormattedLength
        }
        Steps = $Transaction.Steps
        LastError = $Transaction.LastError
        LastWriteIntent = $Transaction.LastWriteIntent
        LastVerifiedAt = $Transaction.LastVerifiedAt
        PkWrittenAt = Get-OptionalPropertyValue -Object $Transaction -Name 'PkWrittenAt' -Default ''
        BootTimeAtPk = Get-OptionalPropertyValue -Object $Transaction -Name 'BootTimeAtPk' -Default ''
        Origin = Get-OptionalPropertyValue -Object $Transaction -Name 'Origin' -Default 'NormalRepair'
        AdvancedRecoveryAcknowledgedAt = Get-OptionalPropertyValue -Object $Transaction -Name 'AdvancedRecoveryAcknowledgedAt' -Default ''
    }
}

function Get-LoggableVariable {
    param([object]$Variable)
    return [ordered]@{
        Exists = $Variable.Exists
        IsMissing = $Variable.IsMissing
        ReadSucceeded = $Variable.ReadSucceeded
        ReadStatus = $Variable.ReadStatus
        Length = $Variable.Length
        Sha256 = $Variable.Sha256
        Attributes = $Variable.Attributes
        ErrorCode = $Variable.ErrorCode
        Error = $Variable.Error
    }
}

function Get-LoggableState {
    param([object]$State)
    $variables = [ordered]@{}
    foreach ($name in @('PK','KEK','db','dbx','PKDefault','KEKDefault','dbDefault','dbxDefault')) {
        $variables[$name] = Get-LoggableVariable $State.Variables[$name]
    }
    return [ordered]@{
        Classification = $State.Classification
        NextStep = $State.NextStep
        WriteAllowed = $State.WriteAllowed
        BlockReason = $State.BlockReason
        Manufacturer = $State.Manufacturer
        Model = $State.Model
        BaseBoard = $State.BaseBoard
        BaseBoardManufacturer = $State.BaseBoardManufacturer
        BIOSVersion = $State.BIOSVersion
        WindowsVersion = $State.WindowsVersion
        IsAsus = $State.IsAsus
        IsUEFI = $State.IsUEFI
        SetupMode = $State.SetupMode
        SecureBootVariable = $State.SecureBootVariable
        ConfirmSecureBoot = $State.ConfirmSecureBoot
        ConfirmSecureBootReadable = $State.ConfirmSecureBootReadable
        ConfirmSecureBootError = $State.ConfirmSecureBootError
        ActiveVariablesReadable = $State.ActiveVariablesReadable
        DefaultVariablesReadable = $State.DefaultVariablesReadable
        Variables = $variables
        CertificateFlags = $State.CertificateFlags
        RotationVerification = $State.RotationVerification
        Servicing = $State.Servicing
        ScheduledTask = $State.ScheduledTask
        BootChain = $State.BootChain
        Power = $State.Power
        BitLocker = [ordered]@{
            Available = $State.BitLocker.Available
            IsKnown = $State.BitLocker.IsKnown
            IsProtected = $State.BitLocker.IsProtected
            IsFullyDecrypted = $State.BitLocker.IsFullyDecrypted
            ProtectionStatus = $State.BitLocker.ProtectionStatus
            VolumeStatus = $State.BitLocker.VolumeStatus
        }
        DefaultResetRisk = $State.DefaultResetRisk
        DefaultResetRiskLevel = $State.DefaultResetRiskLevel
        TransactionConsistency = $State.TransactionConsistency
    }
}

function Update-SummaryFile {
    param([object]$State, [string]$Reason)
    if (-not $script:SessionLogRoot) { return }
    $none = L '无' 'None'
    $lines = @(
        $script:AppName,
        ((L '版本：{0}' 'Version: {0}') -f $script:AppVersion),
        ((L '界面语言：{0}' 'UI language: {0}') -f $script:Language),
        ((L '生成时间：{0}' 'Generated: {0}') -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')),
        ((L '原因：{0}' 'Reason: {0}') -f $Reason),
        '',
        ((L '设备：{0} / {1}' 'Device: {0} / {1}') -f $State.Manufacturer, $State.Model),
        ((L '主板厂商：{0}' 'Baseboard manufacturer: {0}') -f $State.BaseBoardManufacturer),
        ((L '主板：{0}' 'Baseboard: {0}') -f $State.BaseBoard),
        ((L 'BIOS：{0}' 'BIOS: {0}') -f $State.BIOSVersion),
        ((L '当前状态：{0} ({1})' 'Current state: {0} ({1})') -f (Get-ClassificationDisplay $State.Classification), $State.Classification),
        ((L '下一步：{0}' 'Next step: {0}') -f $State.NextStep),
        ((L '允许写入：{0}' 'Write allowed: {0}') -f $State.WriteAllowed),
        ((L '阻止原因：{0}' 'Block reason: {0}') -f $State.BlockReason),
        ((L 'BitLocker状态可判定：{0}' 'BitLocker state known: {0}') -f $State.BitLocker.IsKnown),
        ((L '系统盘已完全解密：{0}' 'System drive fully decrypted: {0}') -f $State.BitLocker.IsFullyDecrypted),
        ((L 'BitLocker保护状态：{0}' 'BitLocker protection status: {0}') -f $State.BitLocker.ProtectionStatus),
        ((L 'BitLocker卷状态：{0}' 'BitLocker volume status: {0}') -f $State.BitLocker.VolumeStatus),
        ('SetupMode: {0}' -f $State.SetupMode),
        ('SecureBoot: {0}' -f $State.ConfirmSecureBoot),
        ((L '2023轮换状态：{0}' '2023 rotation status: {0}') -f $State.Servicing.UEFICA2023Status),
        ((L '适用证书验证：{0}' 'Applicable certificate verification: {0}') -f $State.RotationVerification.Message),
        ('AvailableUpdates: {0}' -f $State.Servicing.AvailableUpdatesHex),
        ((L '启动链检查：{0}' 'Boot chain check: {0}') -f $State.BootChain.Message),
        ((L 'Windows Boot Manager首启动：{0}' 'Windows Boot Manager first: {0}') -f $State.BootChain.WindowsBootManagerFirst),
        ((L 'Windows Boot Manager路径：{0}' 'Windows Boot Manager path: {0}') -f $State.BootChain.WindowsBootManagerPath),
        ((L 'BIOS默认Keys重置风险等级：{0}' 'BIOS Default Keys reset risk level: {0}') -f (Get-DefaultResetRiskLevelDisplay $State.DefaultResetRiskLevel)),
        ((L '风险说明：{0}' 'Risk details: {0}') -f $State.DefaultResetRisk),
        ((L '进度ID：{0}' 'Progress ID: {0}') -f $(if ($script:CurrentTransaction) { $script:CurrentTransaction.TransactionId } else { $none })),
        ((L '进度状态：{0}' 'Progress status: {0}') -f $(if ($script:CurrentTransaction) { $script:CurrentTransaction.Status } else { $none })),
        ((L '当前步骤：{0}' 'Progress step: {0}') -f $(if ($script:CurrentTransaction) { $script:CurrentTransaction.CurrentStep } else { $none })),
        ((L '上次错误：{0}' 'Last error: {0}') -f $(if ($script:CurrentTransaction -and -not [string]::IsNullOrWhiteSpace([string]$script:CurrentTransaction.LastError)) { if ($script:Language -eq 'en-US') { 'A previous progress error was recorded. See diagnostic.json for the technical detail.' } else { $script:CurrentTransaction.LastError } } else { '' })),
        '',
        (L '隐私说明：日志不保存用户文件、BitLocker恢复密钥、序列号或UEFI变量原始内容。' 'Privacy: logs do not store user files, BitLocker recovery keys, serial numbers, or raw UEFI variable contents.')
    )
    [IO.File]::WriteAllLines((Join-Path $script:SessionLogRoot 'summary.txt'), $lines, (New-Object Text.UTF8Encoding($true)))
}

function Get-UefiVariableInfo {
    param([Parameter(Mandatory)][string]$Name)
    try {
        $value = Get-SecureBootUEFI -Name $Name -ErrorAction Stop
        $bytes = [byte[]]$value.Bytes
        return [pscustomobject]@{
            Name = $Name
            Exists = $true
            IsMissing = $false
            ReadSucceeded = $true
            ReadStatus = 'Present'
            Bytes = $bytes
            Length = $bytes.Length
            Sha256 = Get-ByteHashHex -Bytes $bytes -Algorithm SHA256
            Attributes = (($value.Attributes | ForEach-Object { $_.ToString() }) -join ', ')
            ErrorCode = ''
            Error = ''
        }
    } catch {
        $message = $_.Exception.Message
        $code = if ($message -match '0x[0-9A-Fa-f]+') { $matches[0].ToUpperInvariant() } else { '' }
        $isMissing = ($code -eq '0XC0000100')
        return [pscustomobject]@{
            Name = $Name
            Exists = $false
            IsMissing = $isMissing
            ReadSucceeded = $isMissing
            ReadStatus = if ($isMissing) { 'Missing' } else { 'Error' }
            Bytes = [byte[]]@()
            Length = 0
            Sha256 = ''
            Attributes = ''
            ErrorCode = $code
            Error = $message
        }
    }
}

function Get-BitLockerState {
    $result = [ordered]@{
        Available = $false
        IsKnown = $false
        ProtectionStatus = 'Unknown'
        VolumeStatus = 'Unknown'
        IsProtected = $true
        IsFullyDecrypted = $false
        Raw = ''
    }
    try {
        $volume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
        $protection = $volume.ProtectionStatus.ToString()
        $volumeStatus = $volume.VolumeStatus.ToString()
        $result.Available = $true
        $result.IsKnown = $true
        $result.ProtectionStatus = $protection
        $result.VolumeStatus = $volumeStatus
        $result.IsProtected = ($protection -match 'On|1')
        $result.IsFullyDecrypted = ($volumeStatus -eq 'FullyDecrypted')
        return [pscustomobject]$result
    } catch {
        try {
            $raw = (& "$env:SystemRoot\System32\manage-bde.exe" -status $env:SystemDrive 2>&1 | Out-String)
            $result.Raw = $raw
            $result.Available = $true
            $isOn = ($raw -match 'Protection Status:\s+Protection On' -or $raw -match '保护状态:\s+保护已启用' -or $raw -match '保护状态：\s*保护已打开')
            $isOff = ($raw -match 'Protection Status:\s+Protection Off' -or $raw -match '保护状态:\s+保护已禁用' -or $raw -match '保护状态：\s*保护已关闭')
            $isFullyDecrypted = ($raw -match 'Conversion Status:\s+Fully Decrypted' -or $raw -match '转换状态:\s*已完全解密' -or $raw -match '转换状态：\s*已完全解密' -or $raw -match '转换状态:\s*完全解密' -or $raw -match '转换状态：\s*完全解密' -or $raw -match 'Percentage Encrypted:\s+0(\.0)?%' -or $raw -match '加密百分比:\s*0(\.0)?%' -or $raw -match '加密百分比：\s*0(\.0)?%')
            $hasConversion = ($raw -match 'Conversion Status:' -or $raw -match '转换状态')
            $result.IsKnown = (($isOn -or $isOff) -and ($hasConversion -or $isFullyDecrypted))
            $result.IsProtected = if ($isOn) { $true } elseif ($isOff) { $false } else { $true }
            $result.IsFullyDecrypted = ($result.IsKnown -and $isFullyDecrypted)
            $result.ProtectionStatus = if ($isOn) { 'On' } elseif ($isOff) { 'Off' } else { 'Unknown-FailClosed' }
            $result.VolumeStatus = if ($isFullyDecrypted) { 'FullyDecrypted' } elseif ($hasConversion) { 'EncryptedOrInProgress' } else { 'Unknown-FailClosed' }
        } catch {
            $result.IsKnown = $false
            $result.IsProtected = $true
            $result.IsFullyDecrypted = $false
            $result.ProtectionStatus = 'Unknown-FailClosed'
            $result.VolumeStatus = 'Unknown-FailClosed'
        }
        return [pscustomobject]$result
    }
}

function Get-BitLockerBlockReason {
    param([object]$BitLocker)
    if (-not $BitLocker.IsKnown) {
        return (L '未检测到系统盘已完全解密，禁止继续写入。' 'System drive is not detected as fully decrypted. Writes are blocked.')
    }
    if (-not $BitLocker.IsFullyDecrypted) {
        return (L '系统盘未完全解密，禁止继续写入。' 'System drive is not fully decrypted. Writes are blocked.')
    }
    return ''
}

function Get-WriteGate {
    param([object]$Power, [object]$BitLocker, [bool]$PendingReboot)
    $bitLockerReason = Get-BitLockerBlockReason -BitLocker $BitLocker
    if (-not [string]::IsNullOrWhiteSpace($bitLockerReason)) { return [pscustomobject]@{ Allowed = $false; Reason = $bitLockerReason } }
    if (-not $Power.IsSafeForWrite) { return [pscustomobject]@{ Allowed = $false; Reason = (L '笔记本未连接交流电源或电量低于30%。' 'The laptop is not connected to AC power or battery level is below 30%.') } }
    if ($PendingReboot -and -not $script:PendingRebootOverride) { return [pscustomobject]@{ Allowed = $false; Reason = (L 'Windows存在待处理重启。建议先重启。也可开启开发者模式后强制继续。' 'Windows has a pending restart. Restart first, or enable Developer mode and force continue.') } }
    return [pscustomobject]@{ Allowed = $true; Reason = '' }
}
function Get-PowerState {
    $status = [System.Windows.Forms.SystemInformation]::PowerStatus
    $batteryPercent = if ($status.BatteryLifePercent -ge 0) { [math]::Round($status.BatteryLifePercent * 100) } else { $null }
    $lineStatus = $status.PowerLineStatus.ToString()
    $hasBattery = ($status.BatteryChargeStatus.ToString() -notmatch 'NoSystemBattery') -and ($null -ne $batteryPercent)
    $safe = (-not $hasBattery) -or ($lineStatus -eq 'Online' -and $batteryPercent -ge 30)
    return [pscustomobject]@{
        HasBattery = $hasBattery
        PowerLineStatus = $lineStatus
        BatteryPercent = $batteryPercent
        IsSafeForWrite = $safe
    }
}

function Get-ScheduledTaskState {
    try {
        $task = Get-ScheduledTask -TaskPath '\Microsoft\Windows\PI\' -TaskName 'Secure-Boot-Update' -ErrorAction Stop
        $info = Get-ScheduledTaskInfo -InputObject $task
        return [pscustomobject]@{
            Exists = $true
            State = $task.State.ToString()
            LastRunTime = $info.LastRunTime
            LastTaskResult = ('0x{0:X8}' -f [uint32]$info.LastTaskResult)
        }
    } catch {
        return [pscustomobject]@{ Exists = $false; State = 'Missing'; LastRunTime = $null; LastTaskResult = '' }
    }
}

function Invoke-BcdeditCapture {
    param([string[]]$Arguments)
    $exe = Join-Path $env:SystemRoot 'System32\bcdedit.exe'
    $result = [ordered]@{ Succeeded = $false; ExitCode = -1; Text = ''; Error = '' }
    try {
        $output = & $exe @Arguments 2>&1 | Out-String
        $exit = [int]$LASTEXITCODE
        $result.Succeeded = ($exit -eq 0)
        $result.ExitCode = $exit
        $result.Text = [string]$output
    } catch {
        $result.Error = $_.Exception.Message
    }
    return [pscustomobject]$result
}

function Get-ReferenceBootmgfwSignatureState {
    $path = Join-Path $env:SystemRoot 'Boot\EFI\bootmgfw.efi'
    $result = [ordered]@{
        Checked = $false
        Exists = $false
        Path = $path
        Status = 'Unknown'
        Signer = ''
        Message = ''
    }
    try {
        if (Test-Path -LiteralPath $path) {
            $result.Exists = $true
            $sig = Get-AuthenticodeSignature -LiteralPath $path -ErrorAction Stop
            $result.Checked = $true
            $result.Status = [string]$sig.Status
            if ($null -ne $sig.SignerCertificate) { $result.Signer = [string]$sig.SignerCertificate.Subject }
            if ($sig.Status -eq 'Valid') {
                $result.Message = L 'Windows参考bootmgfw.efi签名有效。该检查不等同于EFI分区实际文件签名。' 'The Windows reference bootmgfw.efi signature is valid. This is not the same as verifying the actual file on the EFI partition.'
            } else {
                $result.Message = ((L 'Windows 参考 bootmgfw.efi 签名状态异常：{0}。需要先检查启动文件。' 'The Windows reference bootmgfw.efi signature is abnormal: {0}. Check the boot file first.') -f $result.Status)
            }
        } else {
            $result.Message = L '未找到Windows参考bootmgfw.efi，无法验证启动文件签名。' 'The Windows reference bootmgfw.efi file was not found. Boot-file signature cannot be verified.'
        }
    } catch {
        $result.Message = ((L 'bootmgfw.efi签名检查失败：{0}' 'bootmgfw.efi signature check failed: {0}') -f $_.Exception.Message)
    }
    return [pscustomobject]$result
}


function New-BootChainNotNeededState {
    param([bool]$SecureBootEnabled = $false)
    $message = if ($SecureBootEnabled) {
        L 'Secure Boot 已启用。启动链检查当前无需处理。' 'Secure Boot is already enabled. Boot-chain check is not needed now.'
    } else {
        L '当前状态不需要启用前启动链检查。' 'This state does not need a pre-enable boot-chain check.'
    }
    return [pscustomobject][ordered]@{
        IsKnown = $true
        WindowsBootManagerPresent = $false
        WindowsBootManagerFirst = $false
        WindowsBootManagerPath = ''
        PathLooksStandard = $false
        SuspiciousFirmwareEntries = ''
        ThirdPartyEfiIndicators = ''
        ExternalBootIndicators = ''
        EfiPartitionScanStatus = L '未执行。当前状态无需检查。' 'Not run. Not needed for the current state.'
        BootmgfwSignatureStatus = 'NotNeeded'
        BootmgfwSignatureMessage = $message
        CsmOptionRomStatus = L '未执行。当前状态无需检查。' 'Not run. Not needed for the current state.'
        OfficialRotationEventSummary = ''
        DeepDiagnosticsMessage = $message
        ManualActionMessage = L '无需处理。' 'No action needed.'
        ManualReviewWorkflow = L '无需处理。' 'No action needed.'
        RiskDisposition = L '无需处理' 'Not needed'
        RepairAvailable = $false
        IsSafeToEnableSecureBoot = $SecureBootEnabled
        NeedsManualReview = $false
        Message = $message
        FirmwareExitCode = ''
        BootManagerExitCode = ''
    }
}

function Get-BootChainState {
    $result = [ordered]@{
        IsKnown = $false
        WindowsBootManagerPresent = $false
        WindowsBootManagerFirst = $false
        WindowsBootManagerPath = ''
        PathLooksStandard = $false
        SuspiciousFirmwareEntries = ''
        ThirdPartyEfiIndicators = ''
        ExternalBootIndicators = ''
        EfiPartitionScanStatus = ''
        BootmgfwSignatureStatus = ''
        BootmgfwSignatureMessage = ''
        CsmOptionRomStatus = ''
        OfficialRotationEventSummary = ''
        DeepDiagnosticsMessage = ''
        ManualActionMessage = ''
        ManualReviewWorkflow = ''
        RiskDisposition = ''
        RepairAvailable = $false
        IsSafeToEnableSecureBoot = $false
        NeedsManualReview = $false
        Message = ''
        FirmwareExitCode = ''
        BootManagerExitCode = ''
    }

    $fw = Invoke-BcdeditCapture -Arguments @('/enum','{fwbootmgr}')
    $firmware = Invoke-BcdeditCapture -Arguments @('/enum','firmware')
    $bootmgr = Invoke-BcdeditCapture -Arguments @('/enum','{bootmgr}')
    $result.FirmwareExitCode = $fw.ExitCode
    $result.BootManagerExitCode = $bootmgr.ExitCode

    $referenceSig = Get-ReferenceBootmgfwSignatureState
    $result.BootmgfwSignatureStatus = $referenceSig.Status
    $result.BootmgfwSignatureMessage = $referenceSig.Message
    $result.EfiPartitionScanStatus = L '未自动挂载EFI分区。如仍红屏，需要检查EFI分区中的实际启动文件。' 'The EFI partition was not mounted automatically. If the violation persists, check the actual boot files on the EFI partition.'
    $result.CsmOptionRomStatus = L 'Windows中无法可靠判断CSM/Option ROM。如仍红屏，请在BIOS中确认CSM关闭，并检查外设和Option ROM。' 'CSM/Option ROM cannot be reliably determined from Windows. If the violation persists, check BIOS CSM, external devices, and Option ROM settings.'

    if ((-not $fw.Succeeded -and -not $firmware.Succeeded) -or -not $bootmgr.Succeeded) {
        $result.NeedsManualReview = $true
        $result.Message = L '无法读取Windows固件启动项。启用Secure Boot前需要先确认当前启动项。' 'Unable to read Windows firmware boot entries. Check the current boot entry before enabling Secure Boot.'
        $result.DeepDiagnosticsMessage = $result.Message
        $result.ManualActionMessage = L '不要清 Keys，也不要使用 Restore Factory Keys。先以管理员身份运行 bcdedit /enum firmware。没有 Windows Boot Manager 时，运行 Windows 启动修复或 bcdboot %SystemRoot% /f UEFI，重启后点「重新检测」。' 'Do not clear Keys or use Restore Factory Keys. Run bcdedit /enum firmware as administrator. If Windows Boot Manager is missing, use Windows Startup Repair or run bcdboot %SystemRoot% /f UEFI, restart, and select Detect again.'
        $result.ManualReviewWorkflow = L '处理完成后重启，回到 Windows 点「重新检测」。检测通过后再进入 BIOS 开启 Secure Boot。' 'Restart after fixing the issue, return to Windows, and select Detect again. Enable Secure Boot in BIOS after the check passes.'
        $result.RiskDisposition = L '需要先检查 Windows 启动项' 'Check the Windows boot entry first'
        return [pscustomobject]$result
    }

    $firmwareText = [string]$firmware.Text
    $fwText = if ($fw.Succeeded) { [string]$fw.Text } else { [string]$firmware.Text }
    $bootmgrText = [string]$bootmgr.Text
    $combined = $fwText + [Environment]::NewLine + $firmwareText + [Environment]::NewLine + $bootmgrText

    $result.WindowsBootManagerPresent = ($combined -match '(?i)\{bootmgr\}')
    if ($bootmgrText -match '(?im)^\s*(?:path|路径|路徑)\s+(.+?)\s*$') {
        $result.WindowsBootManagerPath = $Matches[1].Trim()
    }
    $result.PathLooksStandard = ($result.WindowsBootManagerPath -match '(?i)\\EFI\\Microsoft\\Boot\\bootmgfw\.efi$')

    # Parse the first identifier after the localized firmware display-order field.
    $displayMatch = [regex]::Match($fwText, '(?ims)^\s*(?:displayorder|显示顺序|顯示順序)\s+(.+?)(?=^\S|\z)')
    if ($displayMatch.Success) {
        $ids = @([regex]::Matches($displayMatch.Groups[1].Value, '\{[^}]+\}') | ForEach-Object { $_.Value.ToLowerInvariant() })
        if ($ids.Count -gt 0) { $result.WindowsBootManagerFirst = ($ids[0] -eq '{bootmgr}') }
    } elseif ($firmwareText -match '(?is)Firmware Boot Manager.*?\{bootmgr\}') {
        # Use the full firmware list when the dedicated fwbootmgr query is unavailable.
        $result.WindowsBootManagerFirst = $true
    }

    $thirdParty = @()
    foreach ($pattern in @('ubuntu','grub','ventoy','refind','clover','opencore','opensuse','fedora','debian','manjaro','arch linux','android','linux','shim','systemd-boot')) {
        if ($firmwareText -match [regex]::Escape($pattern)) { $thirdParty += $pattern }
    }
    $external = @()
    foreach ($pattern in @('usb','external','removable','network','pxe','uefi os','cdrom','dvd','pe','winpe')) {
        if ($firmwareText -match [regex]::Escape($pattern)) { $external += $pattern }
    }
    $result.ThirdPartyEfiIndicators = (($thirdParty | Select-Object -Unique) -join ', ')
    $result.ExternalBootIndicators = (($external | Select-Object -Unique) -join ', ')
    $allSuspicious = @()
    if (-not [string]::IsNullOrWhiteSpace([string]$result.ThirdPartyEfiIndicators)) { $allSuspicious += $result.ThirdPartyEfiIndicators }
    if (-not [string]::IsNullOrWhiteSpace([string]$result.ExternalBootIndicators)) { $allSuspicious += $result.ExternalBootIndicators }
    $result.SuspiciousFirmwareEntries = ($allSuspicious -join ', ')

    $eventCount = 0
    try { if ($null -ne $script:ServicingState -and $null -ne $script:ServicingState.Events) { $eventCount = @($script:ServicingState.Events).Count } } catch { $eventCount = 0 }
    $result.OfficialRotationEventSummary = ((L '最近Secure Boot更新事件数量：{0}。如Windows状态与证书检测不一致，请导出诊断报告。' 'Recent Secure Boot update event count: {0}. Export diagnostics if Windows status and certificate detection disagree.') -f $eventCount)

    $signatureAbnormal = ($referenceSig.Checked -and $referenceSig.Status -ne 'Valid')
    $signatureUnknown = (-not $referenceSig.Checked)
    $thirdPartyDetected = (-not [string]::IsNullOrWhiteSpace([string]$result.ThirdPartyEfiIndicators))
    $externalDetected = (-not [string]::IsNullOrWhiteSpace([string]$result.ExternalBootIndicators))
    $bootManagerRepairNeeded = ($result.WindowsBootManagerPresent -and ((-not $result.WindowsBootManagerFirst) -or (-not $result.PathLooksStandard)))

    # Automatic repair is limited to the Windows Boot Manager order and standard path.
    # Third-party EFI, external boot, signature, CSM, and Option ROM findings require manual handling.
    $result.RepairAvailable = ($bootManagerRepairNeeded -and (-not $signatureAbnormal) -and (-not $signatureUnknown) -and (-not $thirdPartyDetected) -and (-not $externalDetected))
    $result.IsKnown = $true
    $result.NeedsManualReview = ($signatureAbnormal -or $signatureUnknown -or $thirdPartyDetected -or $externalDetected)
    $result.IsSafeToEnableSecureBoot = ($result.WindowsBootManagerPresent -and $result.WindowsBootManagerFirst -and $result.PathLooksStandard -and (-not $result.NeedsManualReview))

    $deepParts = @()
    $manualParts = @()
    if ($signatureAbnormal) {
        $deepParts += $referenceSig.Message
        $manualParts += L 'bootmgfw.efi 签名异常。先运行 sfc /scannow 和 DISM /Online /Cleanup-Image /RestoreHealth。仍异常时，运行 Windows 启动修复或 bcdboot %SystemRoot% /f UEFI。重启后点「重新检测」。' 'The bootmgfw.efi signature is invalid. Run sfc /scannow and DISM /Online /Cleanup-Image /RestoreHealth. If it remains invalid, use Windows Startup Repair or run bcdboot %SystemRoot% /f UEFI. Restart and select Detect again.'
    } elseif ($signatureUnknown) {
        $deepParts += $referenceSig.Message
        $manualParts += L '无法确认 bootmgfw.efi 签名。先运行 sfc /scannow 和 DISM /Online /Cleanup-Image /RestoreHealth，重启后点「重新检测」。' 'The bootmgfw.efi signature could not be confirmed. Run sfc /scannow and DISM /Online /Cleanup-Image /RestoreHealth, restart, and select Detect again.'
    }
    if ($thirdPartyDetected) {
        $deepParts += ((L '检测到第三方EFI/启动器线索：{0}。' 'Third-party EFI/bootloader indicators detected: {0}.') -f $result.ThirdPartyEfiIndicators)
        $manualParts += L '检测到第三方引导。只使用 Windows 时，把 BIOS 首启动项改为 Windows Boot Manager。使用双系统、Ventoy、grub、rEFInd 或 OpenCore 时，先按对应方案配置 Secure Boot。完成后点「重新检测」。' 'A third-party bootloader was detected. For Windows-only use, set Windows Boot Manager as the first BIOS boot entry. For dual boot, Ventoy, grub, rEFInd, or OpenCore, configure Secure Boot for that setup first. Then select Detect again.'
    }
    if ($externalDetected) {
        $deepParts += ((L '检测到外接/可移动/网络启动线索：{0}。' 'External/removable/network boot indicators detected: {0}.') -f $result.ExternalBootIndicators)
        $manualParts += L '拔掉 U 盘、移动硬盘和扩展坞启动盘。在 BIOS 中把 Windows Boot Manager 调到第一位，并关闭不需要的 PXE/网络启动。完成后点「重新检测」。' 'Disconnect USB drives, external disks, and dock boot media. Set Windows Boot Manager first in BIOS and disable unused PXE or network boot. Then select Detect again.'
    }
    if ($deepParts.Count -eq 0) { $deepParts += L '未发现明显的第三方或外接启动项。EFI 分区未检查。' 'No obvious third-party or external boot entry was found. The EFI partition was not checked.' }
    if ($manualParts.Count -eq 0) {
        if ($result.RepairAvailable) {
            $manualParts += L '点击主按钮修复 Windows Boot Manager。完成后点「重新检测」，通过后再进入 BIOS 开启 Secure Boot。' 'Select the main button to repair Windows Boot Manager. Then select Detect again. Enable Secure Boot in BIOS after the check passes.'
        } elseif ($result.IsSafeToEnableSecureBoot) {
            $manualParts += L '进入 BIOS 开启 Secure Boot。不要清 Keys，也不要使用 Restore Factory Keys。' 'Enable Secure Boot in BIOS. Do not clear Keys or use Restore Factory Keys.'
        } else {
            $manualParts += L '以管理员身份运行 bcdboot %SystemRoot% /f UEFI，重启后点「重新检测」。命令失败时使用 Windows 启动修复。' 'Run bcdboot %SystemRoot% /f UEFI as administrator, restart, and select Detect again. Use Windows Startup Repair if the command fails.'
        }
    }
    $result.DeepDiagnosticsMessage = ($deepParts -join ' ')
    $result.ManualActionMessage = ($manualParts -join ' ')
    $result.ManualReviewWorkflow = L '处理完成后重启，回到 Windows 点「重新检测」。检测通过后再进入 BIOS 开启 Secure Boot。不要清 Keys，也不要使用 Restore Factory Keys。' 'Restart after fixing the issue, return to Windows, and select Detect again. Enable Secure Boot in BIOS after the check passes. Do not clear Keys or use Restore Factory Keys.'

    if ($result.IsSafeToEnableSecureBoot) {
        $result.RiskDisposition = L '可以进入 BIOS 开启 Secure Boot' 'Secure Boot can be enabled in BIOS'
        $result.Message = L 'Windows Boot Manager已位于固件启动顺序首位，路径指向标准Windows启动文件，且未发现明显第三方/外接启动链风险。' 'Windows Boot Manager is first in firmware boot order, points to the standard Windows boot file, and no obvious third-party or external boot-chain risk was detected.'
    } elseif ($result.NeedsManualReview) {
        $result.RiskDisposition = L '需要先处理启动项' 'Fix the boot entries first'
        $result.Message = L '启动链存在需要先检查的项目。不要直接启用 Secure Boot，也不要继续清 Keys。请先检查 EFI 启动文件、第三方启动器、外接启动项或 CSM/Option ROM。' 'The boot chain contains items that need checking first. Do not directly enable Secure Boot or clear Keys. Check EFI boot files, third-party bootloaders, external boot entries, or CSM/Option ROM first.'
    } elseif ($result.RepairAvailable) {
        $result.RiskDisposition = L '可以修复 Windows Boot Manager' 'Windows Boot Manager can be repaired'
        $result.Message = L '检测到Windows Boot Manager，但它不是固件启动顺序首位，或启动路径不是标准Windows启动文件。请先修复启动顺序，再启用Secure Boot。' 'Windows Boot Manager was detected, but it is not first in firmware boot order or its path is not the standard Windows boot file. Repair the boot order before enabling Secure Boot.'
    } else {
        $result.RiskDisposition = L '需要先修复 Windows 启动项' 'Repair the Windows boot entry first'
        $result.Message = L '未检测到可直接修复的Windows Boot Manager启动项。请先在Windows中修复启动项，再启用Secure Boot。' 'No repairable Windows Boot Manager entry was detected. Repair the Windows boot entry in Windows before enabling Secure Boot.'
    }
    return [pscustomobject]$result
}

function Repair-WindowsBootManagerOrder {
    $bcdedit = Join-Path $env:SystemRoot 'System32\bcdedit.exe'
    $pathResult = & $bcdedit /set '{bootmgr}' path '\EFI\Microsoft\Boot\bootmgfw.efi' 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw ((L '修复Windows Boot Manager路径失败：{0}' 'Failed to repair Windows Boot Manager path: {0}') -f $pathResult.Trim()) }
    $orderResult = & $bcdedit /set '{fwbootmgr}' displayorder '{bootmgr}' /addfirst 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw ((L '将Windows Boot Manager设为首启动项失败：{0}' 'Failed to set Windows Boot Manager as the first boot entry: {0}') -f $orderResult.Trim()) }
}

function Get-ServicingState {
    $root = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
    $servicing = "$root\Servicing"
    $rootState = Get-ItemProperty $root -ErrorAction SilentlyContinue
    $serviceState = Get-ItemProperty $servicing -ErrorAction SilentlyContinue
    $availableRaw = Get-OptionalPropertyValue -Object $rootState -Name 'AvailableUpdates'
    $statusRaw = Get-OptionalPropertyValue -Object $serviceState -Name 'UEFICA2023Status'
    $errorRaw = Get-OptionalPropertyValue -Object $serviceState -Name 'UEFICA2023Error'
    $errorEventRaw = Get-OptionalPropertyValue -Object $serviceState -Name 'UEFICA2023ErrorEvent'
    $available = if ($null -ne $availableRaw) { [uint32]$availableRaw } else { [uint32]0 }
    return [pscustomobject]@{
        AvailableUpdates = $available
        AvailableUpdatesHex = ('0x{0:X4}' -f $available)
        UEFICA2023Status = if (-not [string]::IsNullOrWhiteSpace([string]$statusRaw)) { [string]$statusRaw } else { 'NotSet' }
        UEFICA2023Error = if ($null -ne $errorRaw) { ('0x{0:X8}' -f [uint32]$errorRaw) } else { '' }
        UEFICA2023ErrorEvent = $errorEventRaw
    }
}

function Test-TransactionIntermediateState {
    param([object]$State, [System.Collections.IDictionary]$Transaction)
    if ($null -eq $Transaction) { return [pscustomobject]@{ IsConsistent = $false; RecognizedStage = ''; Message = '没有可验证的上次进度。' } }
    try {
        $status = [string]$Transaction.Status
        if ($status -eq 'Locked') {
            return [pscustomobject]@{ IsConsistent = $false; RecognizedStage = ''; Message = L '上次进度已锁定。只有导入并验证恢复文件，或使用备份文件重新校验后，才可能继续。' 'The previous progress is locked. You can continue only after importing and validating a recovery file, or checking the saved backups again.' }
        }
        if ($status -ne 'Active') {
            return [pscustomobject]@{ IsConsistent = $false; RecognizedStage = ''; Message = ((L '上次进度不是 Active：{0}' 'The saved progress status is not Active: {0}') -f $status) }
        }

        $devicePairs = @(
            @([string]$State.Manufacturer, [string]$Transaction.Device.Manufacturer, 'Manufacturer'),
            @([string]$State.Model, [string]$Transaction.Device.Model, 'Model'),
            @([string]$State.BaseBoard, [string](Get-OptionalPropertyValue -Object $Transaction.Device -Name 'BaseBoard' -Default ''), 'BaseBoard'),
            @([string]$State.BaseBoardManufacturer, [string](Get-OptionalPropertyValue -Object $Transaction.Device -Name 'BaseBoardManufacturer' -Default ''), 'BaseBoardManufacturer'),
            @([string]$State.BIOSVersion, [string](Get-OptionalPropertyValue -Object $Transaction.Device -Name 'BIOSVersion' -Default ''), 'BIOSVersion')
        )
        foreach ($pair in $devicePairs) {
            if (-not [string]::Equals($pair[0], $pair[1], [StringComparison]::OrdinalIgnoreCase)) {
                return [pscustomobject]@{ IsConsistent = $false; RecognizedStage = ''; Message = ((L '设备指纹不匹配：{0}。' 'The saved device fingerprint does not match: {0}.') -f $pair[2]) }
            }
        }

        $hashes = $Transaction.ExpectedHashes
        $defaultChecks = @(
            @('PKDefault','PkDefault'),
            @('KEKDefault','KekDefault'),
            @('dbDefault','DbDefault'),
            @('dbxDefault','DbxDefault')
        )
        foreach ($check in $defaultChecks) {
            $variable = $State.Variables[$check[0]]
            $expected = [string]$hashes[$check[1]]
            if (-not $variable.Exists -or [string]::IsNullOrWhiteSpace($expected) -or $variable.Sha256 -ne $expected) {
                return [pscustomobject]@{ IsConsistent = $false; RecognizedStage = ''; Message = ((L '当前 {0} 与上次备份哈希不一致。' 'The current {0} does not match the saved backup hash.') -f $check[0]) }
            }
        }

        $pk = $State.Variables.PK.Exists
        $kek = $State.Variables.KEK.Exists
        $db = $State.Variables.db.Exists
        $dbx = $State.Variables.dbx.Exists
        if (-not $pk -and -not $kek -and -not $db -and -not $dbx) {
            return [pscustomobject]@{ IsConsistent = $true; RecognizedStage = 'NoKeysReady'; Message = L '识别为同一设备、同一 Default Keys 的未写入记录。' 'Recognized as an unwritten record for the same device and Default Keys.' }
        }
        if ($db -and -not $dbx -and -not $kek -and -not $pk) {
            $valid = ($State.Variables.db.Sha256 -eq $hashes.DbDefault) -or ($hashes.DbWith2023 -and $State.Variables.db.Sha256 -eq $hashes.DbWith2023)
            return [pscustomobject]@{ IsConsistent = $valid; RecognizedStage = if ($State.Variables.db.Sha256 -eq $hashes.DbWith2023) {'Db2023Written'} else {'DbDefaultWritten'}; Message = if ($valid) { L '识别为 db 写入后的可继续状态。' 'Recognized as a resumable state after db was written.' } else { L 'db 哈希与上次记录不一致。' 'The db hash does not match the saved record.' } }
        }
        if ($db -and $dbx -and -not $kek -and -not $pk) {
            $valid = ($State.Variables.db.Sha256 -eq $hashes.DbWith2023) -and ($State.Variables.dbx.Sha256 -eq $hashes.DbxDefault)
            return [pscustomobject]@{ IsConsistent = $valid; RecognizedStage = 'DbxWritten'; Message = if ($valid) { L '识别为合法的db+dbx中间态。' 'Recognized as a valid db + dbx intermediate state.' } else { L 'db或dbx哈希不一致。' 'The db or dbx hash does not match.' } }
        }
        if ($db -and $dbx -and $kek -and -not $pk) {
            $valid = ($State.Variables.db.Sha256 -eq $hashes.DbWith2023) -and ($State.Variables.dbx.Sha256 -eq $hashes.DbxDefault) -and ($State.Variables.KEK.Sha256 -eq $hashes.KekDefault)
            return [pscustomobject]@{ IsConsistent = $valid; RecognizedStage = 'KekWritten'; Message = if ($valid) { L '识别为合法的db+dbx+KEK中间态。' 'Recognized as a valid db + dbx + KEK intermediate state.' } else { L 'db、dbx或KEK哈希不一致。' 'The db, dbx, or KEK hash does not match.' } }
        }
        if ($db -and $dbx -and $kek -and $pk) {
            $valid = ($State.Variables.db.Sha256 -eq $hashes.DbWith2023) -and ($State.Variables.dbx.Sha256 -eq $hashes.DbxDefault) -and ($State.Variables.KEK.Sha256 -eq $hashes.KekDefault) -and ($State.Variables.PK.Sha256 -eq $hashes.PkDefault)
            return [pscustomobject]@{ IsConsistent = $valid; RecognizedStage = 'PkWritten'; Message = if ($valid) { L '识别为 PK 写入后的可继续状态。' 'Recognized as a resumable state after PK was written.' } else { L 'Active Keys 与上次记录不一致。' 'The Active Keys do not match the saved record.' } }
        }
    } catch {
        return [pscustomobject]@{ IsConsistent = $false; RecognizedStage = ''; Message = $_.Exception.Message }
    }
    return [pscustomobject]@{ IsConsistent = $false; RecognizedStage = ''; Message = L '当前 Key 组合不在可继续范围内。' 'The current key combination is not in a resumable state.' }
}

function Sync-TransactionProgressFromState {
    param(
        [object]$State,
        [System.Collections.IDictionary]$Transaction
    )
    if ($null -eq $Transaction -or [string]$Transaction.Status -ne 'Active') { return $false }
    if ($null -eq $State.TransactionConsistency -or -not $State.TransactionConsistency.IsConsistent) { return $false }

    $stage = [string]$State.TransactionConsistency.RecognizedStage
    $completedByStage = @{
        'NoKeysReady'      = @()
        'DbDefaultWritten' = @('DbDefault')
        'Db2023Written'    = @('DbDefault','Db2023')
        'DbxWritten'       = @('DbDefault','Db2023','DbxDefault')
        'KekWritten'       = @('DbDefault','Db2023','DbxDefault','KekDefault')
        'PkWritten'        = @('DbDefault','Db2023','DbxDefault','KekDefault','PkDefault')
    }
    if (-not $completedByStage.ContainsKey($stage)) { return $false }

    $changed = $false
    $orderedSteps = @('DbDefault','Db2023','DbxDefault','KekDefault','PkDefault')
    $verifiedComplete = @($completedByStage[$stage])
    foreach ($step in $orderedSteps) {
        $wanted = if ($verifiedComplete -contains $step) { 'Complete' } else { 'NotStarted' }
        if ([string]$Transaction.Steps[$step] -ne $wanted) {
            $Transaction.Steps[$step] = $wanted
            $changed = $true
        }
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$Transaction.PendingOperation)) {
        $Transaction.PendingOperation = ''
        $changed = $true
    }
    $repairPhaseNames = @('', 'BackupsCreated', 'NoKeysReady', 'DbDefault', 'DbDefaultWritten', 'Db2023', 'Db2023Written', 'DbxDefault', 'DbxWritten', 'KekDefault', 'KekWritten', 'PkDefault', 'PkWritten')
    if ($repairPhaseNames -contains [string]$Transaction.CurrentStep -and [string]$Transaction.CurrentStep -ne $stage) {
        $Transaction.CurrentStep = $stage
        $changed = $true
    }
    if ($changed) {
        $Transaction.LastVerifiedAt = (Get-Date).ToString('o')
        Save-Transaction $Transaction
        Write-UiLog ((L '已根据当前 UEFI 状态恢复进度：{0}。本次未写入 UEFI。' 'Progress was restored from the current UEFI state: {0}. No UEFI write occurred in this operation.') -f $stage) 'WARN'
    }
    return $changed
}

function Get-SystemState {
    $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
    $baseboard = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
    $manufacturer = [string](Get-OptionalPropertyValue -Object $computer -Name 'Manufacturer' -Default '')
    $model = [string](Get-OptionalPropertyValue -Object $computer -Name 'Model' -Default '')
    $baseBoardProduct = [string](Get-OptionalPropertyValue -Object $baseboard -Name 'Product' -Default '')
    $baseBoardManufacturer = [string](Get-OptionalPropertyValue -Object $baseboard -Name 'Manufacturer' -Default '')
    $smbiosVersion = [string](Get-OptionalPropertyValue -Object $bios -Name 'SMBIOSBIOSVersion' -Default '')
    $biosFallback = [string](Get-OptionalPropertyValue -Object $bios -Name 'Version' -Default '')
    $biosVersion = if (-not [string]::IsNullOrWhiteSpace($smbiosVersion)) { $smbiosVersion } else { $biosFallback }
    $hardwareIsAsus = ($manufacturer -match 'ASUSTeK|ASUS') -or ($baseBoardManufacturer -match 'ASUSTeK|ASUS') -or ($baseBoardProduct -match '^ROG|ASUS')
    $isAsus = $hardwareIsAsus -or $script:DeveloperModeEnabled

    $peFirmwareType = 0
    try { $peFirmwareType = [int](Get-ItemPropertyValue 'HKLM:\SYSTEM\CurrentControlSet\Control' 'PEFirmwareType' -ErrorAction Stop) } catch {}

    $variables = [ordered]@{}
    foreach ($name in @('PK','KEK','db','dbx','PKDefault','KEKDefault','dbDefault','dbxDefault','SetupMode','SecureBoot')) {
        $variables[$name] = Get-UefiVariableInfo $name
    }
    $isUefi = ($peFirmwareType -eq 2) -or $variables.SetupMode.Exists
    $setupMode = if ($variables.SetupMode.Exists -and $variables.SetupMode.Length -gt 0) { [int]$variables.SetupMode.Bytes[0] } else { $null }
    $secureBootVariable = if ($variables.SecureBoot.Exists -and $variables.SecureBoot.Length -gt 0) { [int]$variables.SecureBoot.Bytes[0] } else { $null }
    $confirm = $false
    $confirmReadable = $true
    $confirmError = ''
    try {
        $confirm = [bool](Confirm-SecureBootUEFI -ErrorAction Stop)
    } catch {
        $confirmReadable = $false
        $confirmError = $_.Exception.Message
    }

    $dbText = if ($variables.db.Exists) { [Text.Encoding]::ASCII.GetString($variables.db.Bytes) } else { '' }
    $kekText = if ($variables.KEK.Exists) { [Text.Encoding]::ASCII.GetString($variables.KEK.Bytes) } else { '' }
    $dbDefaultText = if ($variables.dbDefault.Exists) { [Text.Encoding]::ASCII.GetString($variables.dbDefault.Bytes) } else { '' }
    $kekDefaultText = if ($variables.KEKDefault.Exists) { [Text.Encoding]::ASCII.GetString($variables.KEKDefault.Bytes) } else { '' }

    $certificateFlags = [ordered]@{
        WindowsUEFICA2023 = ($dbText -match 'Windows UEFI CA 2023')
        MicrosoftUEFICA2023 = ($dbText -match 'Microsoft UEFI CA 2023')
        OptionROMUEFICA2023 = ($dbText -match 'Microsoft Option ROM UEFI CA 2023')
        KEK2KCA2023 = ($kekText -match 'Microsoft Corporation KEK 2K CA 2023')
        MicrosoftUEFICA2011 = ($dbText -match 'Microsoft Corporation UEFI CA 2011' -or $dbText -match 'Microsoft UEFI CA 2011')
        DefaultWindowsUEFICA2023 = ($dbDefaultText -match 'Windows UEFI CA 2023')
        DefaultMicrosoftUEFICA2023 = ($dbDefaultText -match 'Microsoft UEFI CA 2023')
        DefaultOptionROMUEFICA2023 = ($dbDefaultText -match 'Microsoft Option ROM UEFI CA 2023')
        DefaultKEK2KCA2023 = ($kekDefaultText -match 'Microsoft Corporation KEK 2K CA 2023')
    }

    $requiresThirdParty2023 = [bool]$certificateFlags.MicrosoftUEFICA2011
    $missingRotationItems = @()
    if (-not $certificateFlags.WindowsUEFICA2023) { $missingRotationItems += 'Windows UEFI CA 2023' }
    if (-not $certificateFlags.KEK2KCA2023) { $missingRotationItems += 'Microsoft Corporation KEK 2K CA 2023' }
    if ($requiresThirdParty2023 -and -not $certificateFlags.MicrosoftUEFICA2023) { $missingRotationItems += 'Microsoft UEFI CA 2023' }
    if ($requiresThirdParty2023 -and -not $certificateFlags.OptionROMUEFICA2023) { $missingRotationItems += 'Microsoft Option ROM UEFI CA 2023' }
    $rotationVerification = [pscustomobject]@{
        RequiresThirdParty2023 = $requiresThirdParty2023
        IsComplete = ($missingRotationItems.Count -eq 0)
        MissingItems = @($missingRotationItems)
        Message = if ($missingRotationItems.Count -eq 0) { L '适用于本机的2023证书与KEK均已检测到。' 'All 2023 certificates and KEK entries applicable to this device were detected.' } else { (L '缺少：' 'Missing: ') + ($missingRotationItems -join $(if ($script:Language -eq 'en-US') { ', ' } else { '、' })) }
    }

    $servicing = Get-ServicingState
    $task = Get-ScheduledTaskState
    $power = Get-PowerState
    $bitlocker = Get-BitLockerState
    $pendingRebootState = Get-PendingWindowsRebootState
    $pendingWindowsReboot = [bool]$pendingRebootState.IsPending
    $writeGate = Get-WriteGate -Power $power -BitLocker $bitlocker -PendingReboot $pendingWindowsReboot
    $windowsVersion = '{0} Build {1}' -f [Environment]::OSVersion.VersionString, [Environment]::OSVersion.Version.Build

    $activeNames = @('PK','KEK','db','dbx')
    $defaultNames = @('PKDefault','KEKDefault','dbDefault','dbxDefault')
    $activeVariablesReadable = (@($activeNames | Where-Object { -not $variables[$_].ReadSucceeded }).Count -eq 0)
    $defaultVariablesReadable = (@($defaultNames | Where-Object { -not $variables[$_].ReadSucceeded }).Count -eq 0)
    $activeExists = @($activeNames | ForEach-Object { $variables[$_].Exists })
    $activeCount = @($activeExists | Where-Object { $_ }).Count
    $defaultsAll = $defaultVariablesReadable -and $variables.PKDefault.Exists -and $variables.KEKDefault.Exists -and $variables.dbDefault.Exists -and $variables.dbxDefault.Exists -and $variables.PKDefault.Length -gt 0 -and $variables.KEKDefault.Length -gt 0 -and $variables.dbDefault.Length -gt 0 -and $variables.dbxDefault.Length -gt 0
    $noKeys = $activeVariablesReadable -and (@($activeNames | Where-Object { -not $variables[$_].IsMissing }).Count -eq 0)
    $allKeys = $activeVariablesReadable -and (@($activeNames | Where-Object { -not $variables[$_].Exists }).Count -eq 0)

    $state = [pscustomobject]@{
        Manufacturer = $manufacturer
        Model = $model
        BaseBoard = $baseBoardProduct
        BaseBoardManufacturer = $baseBoardManufacturer
        BIOSVersion = $biosVersion
        WindowsVersion = $windowsVersion
        IsAsus = $isAsus
        HardwareIsAsus = $hardwareIsAsus
        DeveloperMode = [bool]$script:DeveloperModeEnabled
        DeveloperForceActive = [bool]$script:DeveloperForceActive
        DeveloperOverrideAvailable = $false
        PendingReboot = $pendingRebootState
        PendingRebootOverride = [bool]$script:PendingRebootOverride
        IsUEFI = $isUefi
        SetupMode = $setupMode
        SecureBootVariable = $secureBootVariable
        ConfirmSecureBoot = $confirm
        ConfirmSecureBootReadable = $confirmReadable
        ConfirmSecureBootError = $confirmError
        ActiveVariablesReadable = $activeVariablesReadable
        DefaultVariablesReadable = $defaultVariablesReadable
        Variables = $variables
        CertificateFlags = [pscustomobject]$certificateFlags
        RotationVerification = $rotationVerification
        Servicing = $servicing
        ScheduledTask = $task
        BootChain = $null
        Power = $power
        BitLocker = $bitlocker
        NoKeys = $noKeys
        AllKeys = $allKeys
        DefaultsAllReadable = $defaultsAll
        Classification = ''
        NextStep = ''
        WriteAllowed = $false
        BlockReason = ''
        ActionBlockReason = ''
        DefaultResetRisk = ''
        DefaultResetRiskLevel = 'Unknown'
        SecureBootEnableWarning = ''
        BootChainWarning = ''
        PostPkActiveStateVerified = $false
        TransactionConsistency = $null
    }

    $state.TransactionConsistency = Test-TransactionIntermediateState -State $state -Transaction $script:CurrentTransaction

    $all2023 = $rotationVerification.IsComplete
    $activeNew = $certificateFlags.WindowsUEFICA2023 -or $certificateFlags.MicrosoftUEFICA2023 -or $certificateFlags.OptionROMUEFICA2023 -or $certificateFlags.KEK2KCA2023
    $needsPreEnableBootChainCheck = ($setupMode -eq 0 -and $confirmReadable -and ($confirm -eq $false) -and $allKeys -and $activeNew)
    if ($needsPreEnableBootChainCheck) {
        $state.BootChain = Get-BootChainState
    } else {
        $state.BootChain = New-BootChainNotNeededState -SecureBootEnabled:$confirm
    }
    $postPkActiveStateVerified = $confirm -and $setupMode -eq 0 -and $allKeys -and $activeNew
    $state.PostPkActiveStateVerified = $postPkActiveStateVerified
    $completed = $confirm -and $setupMode -eq 0 -and $rotationVerification.IsComplete -and $servicing.UEFICA2023Status -eq 'Updated'
    $pkRebootPending = $false
    if ($null -ne $script:CurrentTransaction -and $state.TransactionConsistency.IsConsistent -and $state.TransactionConsistency.RecognizedStage -eq 'PkWritten') {
        $pkStep = [string]$script:CurrentTransaction.Steps.PkDefault
        $rebootStep = [string]$script:CurrentTransaction.Steps.Reboot
        $pkRebootPending = ($pkStep -in @('Pending','Complete')) -and ($rebootStep -ne 'Complete')
    }

    if (-not $isUefi) {
        $state.Classification = 'UnsupportedLegacy'
        $state.NextStep = L '请先把系统转换为 UEFI 启动，再重新检测。' 'Convert the system to UEFI boot, then detect again.'
        $state.BlockReason = L '当前不是UEFI启动。' 'The current Windows installation is not booted in UEFI mode.'
    } elseif (-not $isAsus) {
        $state.Classification = 'ReadOnlyNonAsus'
        $state.NextStep = L '仅允许导出只读诊断。' 'Only read-only diagnostics and log export are available.'
        $state.BlockReason = L '本版本仅为ASUS/ROG专版。' 'This edition only permits writes on ASUS/ROG devices.'
    } elseif (-not $variables.SetupMode.ReadSucceeded -or -not $variables.SecureBoot.ReadSucceeded -or -not $variables.SetupMode.Exists -or -not $variables.SecureBoot.Exists -or -not $activeVariablesReadable -or ($setupMode -eq 0 -and -not $confirmReadable)) {
        $state.Classification = 'FirmwareVariableReadFailure'
        $state.NextStep = L '一个或多个固件变量无法可靠读取，禁止写入并导出日志。' 'One or more firmware variables could not be read reliably. Writes are blocked; export diagnostics.'
        $state.BlockReason = L '固件变量读取出现非「变量不存在」错误，或Secure Boot确认命令失败。' 'A firmware-variable read returned an error other than variable-not-found, or Secure Boot confirmation failed.'
    } elseif ($pkRebootPending) {
        $state.Classification = 'PkWrittenPendingReboot'
        $state.NextStep = L 'PK已写入并通过回读。必须重启后再进入官方轮换。' 'PK was written and verified. Restart before starting the official rotation.'
    } elseif ($null -ne $script:CurrentTransaction -and [string]$script:CurrentTransaction.Status -eq 'Locked' -and -not $postPkActiveStateVerified) {
        $state.Classification = 'BlockedUnsafe'
        $state.NextStep = L '上次进度已锁定。可导出日志，或进入中断恢复并重新校验备份。' 'Saved progress is locked. Export diagnostics, or use interrupted recovery and check the backups again.'
        $state.BlockReason = $state.TransactionConsistency.Message
    } elseif ($completed) {
        $state.Classification = 'Completed'
        $state.NextStep = L '无需继续操作。不要使用 Restore Factory Keys。' 'No further action is required. Do not use Restore Factory Keys.'
    } elseif ($setupMode -eq 1 -and $secureBootVariable -eq 0 -and $noKeys -and $defaultsAll -and $null -ne $script:CurrentTransaction -and -not $state.TransactionConsistency.IsConsistent) {
        $state.Classification = 'TransactionMismatch'
        $state.NextStep = L '当前设备或 Default Keys 与未完成进度不一致，禁止继续使用旧记录。' 'The device or Default Keys do not match the unfinished progress. The old record cannot be reused.'
        $state.BlockReason = $state.TransactionConsistency.Message
    } elseif ($setupMode -eq 1 -and $secureBootVariable -eq 0 -and $noKeys -and -not $defaultVariablesReadable) {
        $state.Classification = 'FirmwareVariableReadFailure'
        $state.NextStep = L 'BIOS默认Keys读取异常，禁止自动修复并导出日志。' 'BIOS factory Keys returned an unexpected read error. Automated repair is blocked. Export diagnostics.'
        $state.BlockReason = L '至少一个BIOS默认Keys无法可靠读取。' 'At least one BIOS factory Key could not be read reliably.'
    } elseif ($setupMode -eq 1 -and $secureBootVariable -eq 0 -and $noKeys -and -not $defaultsAll) {
        $state.Classification = 'MissingDefaultVariables'
        $state.NextStep = L 'Active Keys 已清空，但 BIOS 默认 Keys 有缺失或为空。已禁止自动修复。' 'Active Keys are empty, but BIOS factory Keys are missing or empty. Automated repair is blocked.'
        $state.BlockReason = L 'PKDefault/KEKDefault/dbDefault/dbxDefault至少一项不存在或为空。' 'At least one of PKDefault/KEKDefault/dbDefault/dbxDefault is missing or empty.'
    } elseif ($setupMode -eq 1 -and $secureBootVariable -eq 0 -and $noKeys -and $defaultsAll) {
        $state.Classification = 'ReadyForRepair'
        $state.NextStep = L '创建进度记录、备份 Default Keys，然后逐步重建信任链。' 'Create a progress record, back up the Default Keys, then rebuild the trust chain one step at a time.'
        $state.WriteAllowed = $writeGate.Allowed
        if (-not $writeGate.Allowed) { $state.BlockReason = $writeGate.Reason }
    } elseif ($activeCount -gt 0 -and $activeCount -lt 4) {
        if ($state.TransactionConsistency.IsConsistent) {
            $stage = $state.TransactionConsistency.RecognizedStage
            $state.Classification = 'RecoverableIntermediate'
            $state.NextStep = switch ($stage) {
                'DbDefaultWritten' { L '追加Windows UEFI CA 2023到db。' 'Append Windows UEFI CA 2023 to db.' }
                'Db2023Written' { L '恢复dbxDefault。' 'Restore dbxDefault.' }
                'DbxWritten' { L '恢复KEKDefault。' 'Restore KEKDefault.' }
                'KekWritten' { L '最后写入PKDefault。' 'Write PKDefault last.' }
                default { L '重新检测进度。' 'Detect progress again.' }
            }
            $state.WriteAllowed = $writeGate.Allowed
            if (-not $state.WriteAllowed) { $state.BlockReason = $writeGate.Reason }
        } else {
            $state.Classification = 'AdvancedRecoveryRequired'
            $state.NextStep = L '当前存在部分 Active Keys，但没有可验证的上次进度。请导入恢复文件，或选择四个 Default Keys 备份和官方证书进行中断恢复校验。' 'Partial Active Keys exist without verified saved progress. Import a recovery file, or select all four Default Keys backups and the official certificate for interrupted recovery.'
            $state.BlockReason = L '在中断恢复校验完成前，任何 UEFI 写入均被禁止。' 'All UEFI writes are blocked until interrupted recovery is fully checked.'
        }
    } elseif ($confirm -and $setupMode -eq 0 -and $servicing.UEFICA2023Error -and $servicing.UEFICA2023Error -ne '0x00000000') {
        $state.Classification = 'OfficialRotationError'
        $state.NextStep = L '官方轮换记录了错误，禁止继续写入。请导出日志检查。' 'The official rotation recorded an error. Further writes are blocked. Export diagnostics for checking.'
        $state.BlockReason = ('UEFICA2023Error={0}，ErrorEvent={1}' -f $servicing.UEFICA2023Error, $servicing.UEFICA2023ErrorEvent)
    } elseif ($confirm -and $setupMode -eq 0 -and $servicing.UEFICA2023Status -eq 'Updated' -and -not $rotationVerification.IsComplete) {
        $state.Classification = 'UpdatedButVerificationMismatch'
        $state.NextStep = L 'Windows报告Updated，但证书集合与本机适用性检测不一致。禁止手工补写，请导出日志。' 'Windows reports Updated, but the detected certificate set does not match device applicability. Do not add certificates manually. Export diagnostics.'
        $state.BlockReason = $rotationVerification.Message
    } elseif ($confirm -and $setupMode -eq 0 -and ($servicing.UEFICA2023Status -eq 'InProgress' -or ($servicing.AvailableUpdates -ne 0 -and $servicing.AvailableUpdates -ne $script:AvailableUpdatesComplete))) {
        $state.Classification = 'OfficialRotationNeedsReboot'
        $state.NextStep = L '重启并在登录后自动续检，然后重新运行官方任务。' 'Restart, let the assistant resume detection after sign-in, then run the official task again.'
    } elseif ($confirm -and $setupMode -eq 0 -and (-not $all2023 -or $servicing.UEFICA2023Status -ne 'Updated')) {
        $state.Classification = 'NeedsOfficialRotation'
        $state.NextStep = L '运行微软Secure-Boot-Update官方轮换任务。' 'Run the Microsoft Secure-Boot-Update official rotation task.'
        $state.WriteAllowed = $task.Exists -and $writeGate.Allowed
        if (-not $task.Exists) { $state.BlockReason = L '缺少微软Secure-Boot-Update计划任务。' 'The Microsoft Secure-Boot-Update scheduled task is missing.' }
        elseif (-not $writeGate.Allowed) { $state.BlockReason = $writeGate.Reason }
    } elseif ($setupMode -eq 0 -and -not $confirm -and $allKeys) {
        if ($activeNew -and (-not $state.BootChain.IsSafeToEnableSecureBoot)) {
            if ($state.BootChain.RepairAvailable) {
                $state.Classification = 'BootChainRepairRequired'
                $state.NextStep = L '当前 Active Keys 已包含 2023 证书，但 Secure Boot 未启用。先将 Windows Boot Manager 修复为首启动项，再启用 Secure Boot。' 'Active Keys already contain 2023 certificates, but Secure Boot is disabled. Repair Windows Boot Manager as the first boot entry before enabling Secure Boot.'
                $state.BootChainWarning = $state.BootChain.Message
            } else {
                $state.Classification = 'BootChainReviewRequired'
                $state.NextStep = L '当前 Active Keys 已包含 2023 证书，但启动链未通过。按「怎么处理」完成操作，重启后点「重新检测」。检测通过后再开启 Secure Boot。不要清 Keys。' 'Active Keys contain the 2023 certificates, but the boot-chain check failed. Follow How to fix, restart, and select Detect again. Enable Secure Boot after the check passes. Do not clear Keys.'
                $state.ActionBlockReason = $state.BootChain.Message
                $state.BootChainWarning = $state.BootChain.Message
            }
            $state.SecureBootEnableWarning = L '已检测到 2023 证书。启用 Secure Boot 前先检查启动链。Windows Boot Manager 不是首启动项或路径异常时，可能出现 Secure Boot Violation。' 'The 2023 certificates were detected. Check the boot chain before enabling Secure Boot. A non-first Windows Boot Manager entry or an abnormal path may cause Secure Boot Violation.'
        } else {
            $state.Classification = 'SecureBootDisabledWithKeys'
            $state.NextStep = L '启动链检查通过后，再查看启用Secure Boot说明。' 'After the boot-chain check passes, read the Secure Boot enable notice.'
            $state.SecureBootEnableWarning = L '当前Keys已存在，且Windows Boot Manager启动项检查未发现需要自动修复的问题。进入BIOS启用Secure Boot时不要清除Keys。' 'The current Keys are present and the Windows Boot Manager boot-entry check did not find an issue requiring automatic repair. Do not clear the Keys when enabling Secure Boot in BIOS.'
            $state.BootChainWarning = $state.BootChain.Message
        }
    } elseif ($setupMode -eq 1 -and -not $noKeys) {
        $state.Classification = 'InvalidSetupModeState'
        $state.NextStep = L '存在异常的Setup Mode/部分Keys组合，禁止自动修复。' 'An abnormal Setup Mode/partial-key combination exists. Automated repair is blocked.'
        $state.BlockReason = L 'SetupMode=1但活动密钥并非全部缺失。' 'SetupMode=1, but the Active Keys are not all absent.'
    } else {
        $state.Classification = 'NeedsFirmwareSetup'
        $state.NextStep = L '重启进入BIOS，按ASUS教程进入Setup Mode并清除活动Keys。' 'Restart into UEFI setup, follow the ASUS instructions to enter Setup Mode, and clear the Active Keys.'
        $state.BlockReason = L '尚未满足SetupMode=1且No Key。' 'The required SetupMode=1 and No Key state has not been reached.'
    }

    $bitLockerActionBlockReason = Get-BitLockerBlockReason -BitLocker $bitlocker
    $bitLockerBlockedActionStates = @('ReadyForRepair','RecoverableIntermediate','NeedsOfficialRotation','NeedsFirmwareSetup','SecureBootDisabledWithKeys','BootChainRepairRequired','BootChainReviewRequired','PkWrittenPendingReboot','OfficialRotationNeedsReboot')
    if (-not [string]::IsNullOrWhiteSpace($bitLockerActionBlockReason) -and $state.Classification -in $bitLockerBlockedActionStates) {
        $state.ActionBlockReason = $bitLockerActionBlockReason
        if ($state.Classification -in @('ReadyForRepair','RecoverableIntermediate','NeedsOfficialRotation')) {
            $state.WriteAllowed = $false
            $state.BlockReason = $bitLockerActionBlockReason
        } elseif ([string]::IsNullOrWhiteSpace([string]$state.BlockReason)) {
            $state.BlockReason = $bitLockerActionBlockReason
        }
    }

    $defaultMissing = (-not $certificateFlags.DefaultWindowsUEFICA2023) -or (-not $certificateFlags.DefaultMicrosoftUEFICA2023) -or (-not $certificateFlags.DefaultOptionROMUEFICA2023) -or (-not $certificateFlags.DefaultKEK2KCA2023)
    if (-not $defaultVariablesReadable) {
        $state.DefaultResetRiskLevel = 'Unknown'
        $state.DefaultResetRisk = L '无法完整读取主板BIOS固件预置的Default Keys。不要使用Clear Keys、Reset To Setup Mode或Restore Factory Keys。' 'The Default Keys stored in the motherboard BIOS firmware could not be read completely. Do not use Clear Keys, Reset To Setup Mode, or Restore Factory Keys.'
    } elseif ($activeNew -and $defaultMissing) {
        $state.DefaultResetRiskLevel = 'Warning'
        $state.DefaultResetRisk = L 'Active Keys 已有 2023 证书，但 BIOS 固件预置的 Default Keys 不包含完整 2023 证书。不要使用 Restore Factory Keys。' 'Active Keys already contain 2023 certificates, but BIOS factory Default Keys do not contain the full 2023 certificate set. Do not use Restore Factory Keys.'
    } elseif ($activeNew) {
        $state.DefaultResetRiskLevel = 'Low'
        $state.DefaultResetRisk = L '检测到主板BIOS固件预置的Default Keys中已经包含本次2023更新所需的证书条目。当前无需使用Restore Factory Keys，也不建议在没有明确需要时重置Keys。' 'The Default Keys stored in the motherboard BIOS firmware already contain the certificate entries required for the 2023 update. Restore Factory Keys is not needed, and Keys should not be reset without a specific reason.'
    } else {
        $state.DefaultResetRiskLevel = 'Pending'
        $state.DefaultResetRisk = L '2023轮换尚未完成，暂不能评估Restore Factory Keys对已更新证书的影响。' 'The 2023 rotation is not complete, so the effect of Restore Factory Keys on updated certificates cannot be assessed yet.'
    }
    $blockedClassifications = @('UnsupportedLegacy','ReadOnlyNonAsus','FirmwareVariableReadFailure','BlockedUnsafe','TransactionMismatch','MissingDefaultVariables','AdvancedRecoveryRequired','OfficialRotationError','UpdatedButVerificationMismatch','InvalidSetupModeState','BootChainReviewRequired')
    $hasSoftwareBlock = (-not [string]::IsNullOrWhiteSpace([string]$state.BlockReason)) -or (-not [string]::IsNullOrWhiteSpace([string]$state.ActionBlockReason)) -or ($state.Classification -in $blockedClassifications)
    $state.DeveloperOverrideAvailable = ($state.Classification -ne 'Completed' -and $hasSoftwareBlock)
    if ($script:DeveloperModeEnabled) {
        $state.DefaultResetRisk = ((L '开发者模式已开启。风险由你自行承担。 {0}' 'Developer mode is enabled. Forced operations are at your own risk. {0}') -f $state.DefaultResetRisk)
        $state.DefaultResetRiskLevel = 'Warning'
    }
    if ($script:PendingRebootOverride -and $pendingWindowsReboot) {
        $state.DefaultResetRisk = ((L '已强制忽略Windows待处理重启。该状态只在本次运行有效。 {0}' 'The Windows pending-restart block is overridden for this session. {0}') -f $state.DefaultResetRisk)
        $state.DefaultResetRiskLevel = 'Warning'
    }
    return $state
}

function Validate-CertificateFile {
    param([Parameter(Mandatory)][string]$Path)
    $result = [ordered]@{
        IsValid = $false
        Path = $Path
        FileName = [IO.Path]::GetFileName($Path)
        Size = 0
        SHA256 = ''
        MD5 = ''
        CertificateThumbprint = ''
        Subject = ''
        Issuer = ''
        NotBefore = $null
        NotAfter = $null
        Errors = @()
    }
    try {
        if (-not (Test-Path -LiteralPath $Path)) { throw '找不到证书文件。' }
        $item = Get-Item -LiteralPath $Path
        $result.Size = $item.Length
        $result.SHA256 = Get-FileHashHex -Path $Path -Algorithm SHA256
        $result.MD5 = Get-FileHashHex -Path $Path -Algorithm MD5
        $cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList $Path
        $result.CertificateThumbprint = $cert.Thumbprint.ToUpperInvariant()
        $result.Subject = $cert.Subject
        $result.Issuer = $cert.Issuer
        $result.NotBefore = $cert.NotBefore.ToString('o')
        $result.NotAfter = $cert.NotAfter.ToString('o')
        if ($result.Size -ne $script:OfficialCertificateSize) { $result.Errors += '文件大小不符。' }
        if ($result.SHA256 -ne $script:OfficialCertificateSha256) { $result.Errors += 'SHA-256不符。' }
        if ($result.CertificateThumbprint -ne $script:OfficialCertificateThumbprint) { $result.Errors += '证书SHA-1 Thumbprint不符。' }
        if ($result.Subject -ne $script:OfficialCertificateSubject) { $result.Errors += '证书Subject不符。' }
        if ($result.Issuer -ne $script:OfficialCertificateIssuer) { $result.Errors += '证书Issuer不符。' }
        if ($cert.NotBefore -gt (Get-Date)) { $result.Errors += '证书尚未生效。' }
        if ($cert.NotAfter -lt (Get-Date)) { $result.Errors += '证书已过期。' }
        $result.IsValid = ($result.Errors.Count -eq 0)
    } catch {
        $result.Errors += $_.Exception.Message
    }
    return [pscustomobject]$result
}

function Save-Settings {
    param(
        [string]$BackupRoot,
        [bool]$OobeAccepted,
        [ValidateSet('zh-CN','en-US')][string]$SelectedLanguage = $script:Language
    )
    $settings = [ordered]@{
        OobeVersion = if ($OobeAccepted) { $script:OobeVersion } else { '' }
        BackupRoot = $BackupRoot
        Language = $SelectedLanguage
        LastAcceptedAt = if ($OobeAccepted) { (Get-Date).ToString('o') } else { '' }
    }
    # Create protected state storage only after OOBE confirmation.
    Protect-AppDataDirectory -Path $script:AppDataRoot
    Write-JsonAtomic -Path $script:SettingsPath -Object $settings
}

function Get-Settings {
    $settings = Read-JsonSafe $script:SettingsPath
    if ($null -eq $settings) {
        return @{
            OobeVersion = ''
            BackupRoot = Get-DefaultBackupRoot
            Language = $script:Language
            LastAcceptedAt = ''
        }
    }
    $normalized = @{
        OobeVersion = [string](Get-OptionalPropertyValue -Object $settings -Name 'OobeVersion' -Default '')
        BackupRoot = [string](Get-OptionalPropertyValue -Object $settings -Name 'BackupRoot' -Default (Get-DefaultBackupRoot))
        Language = [string](Get-OptionalPropertyValue -Object $settings -Name 'Language' -Default $script:Language)
        LastAcceptedAt = [string](Get-OptionalPropertyValue -Object $settings -Name 'LastAcceptedAt' -Default '')
    }
    if ([string]::IsNullOrWhiteSpace($normalized.BackupRoot)) { $normalized.BackupRoot = Get-DefaultBackupRoot }
    if ($normalized.Language -notin @('zh-CN','en-US')) { $normalized.Language = $script:Language }
    return $normalized
}

function Get-OobeRiskText {
    if ($script:Language -eq 'en-US') {
        return @'
[Before you start]
Back up important files. Handle BitLocker / device encryption first and keep the recovery key. If the app asks for Setup Mode, enter BIOS and clear Secure Boot Keys. Do not use Restore Factory Keys unless you know why. Some BIOS factory Keys do not include the full 2023 certificate set.

[During use]
Follow the step shown on the main screen. Check every confirmation before continuing.
After returning to Windows from a restart, select Detect again first.

[Files]
Choose the log and backup folder.
Do not publish raw Default Keys backups, BitLocker recovery keys, personal files, or recovery files that contain device backups.
'@
    }
    return @'
【开始前】
先备份重要文件。处理 BitLocker / 设备加密，并保存恢复密钥。
软件提示需要 Setup Mode 时，再进 BIOS 清空 Secure Boot Keys。
不要随意使用 Restore Factory Keys。部分 BIOS 默认 Keys 不包含完整 2023 证书，恢复后可能回到旧证书。

【使用中】
按主界面显示的步骤操作。继续前先核对确认内容。
重启回到 Windows 后，先点「重新检测」。

【文件】
选择日志和备份保存位置。
不要公开上传 Default Keys 原始备份、BitLocker 恢复密钥、个人文件，或包含设备备份的恢复文件。
'@
}

function Get-FileCreationPlanText {
    param([string]$BackupPath)
    $displayPath = if ([string]::IsNullOrWhiteSpace($BackupPath)) { L '尚未选择' 'Not selected' } else { $BackupPath }
    if ($script:Language -eq 'en-US') {
        return @"
Save location: $displayPath
Logs\ - detection logs
Progress\ - created after a repair starts

App data: $script:AppDataRoot
Settings, restart state, and the validated certificate copy are stored here.

Automatic upload: none.
"@
    }
    return @"
保存位置：$displayPath
Logs\：检测日志
Progress\：开始修复后创建

程序数据：$script:AppDataRoot
用于保存设置、重启状态和已验证的证书副本。

自动上传：无。
"@
}

function Show-Oobe {
    param(
        [string]$DefaultBackupRoot,
        [ValidateSet('zh-CN','en-US')][string]$DefaultLanguage = $script:Language
    )
    Set-AppLanguage $DefaultLanguage

    $form = New-Object Windows.Forms.Form
    $form.ClientSize = New-Object Drawing.Size(1180, 900)
    $form.AutoScaleMode = 'Dpi'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'Sizable'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $true
    $form.MinimumSize = New-Object Drawing.Size(1040,900)
    $form.AutoScroll = $true
    $form.BackColor = [Drawing.Color]::White

    $title = New-Object Windows.Forms.Label
    $title.Font = New-Object Drawing.Font((Get-LocalizedFontName), 15, [Drawing.FontStyle]::Bold)
    $title.Location = New-Object Drawing.Point(28, 18)
    $title.Size = New-Object Drawing.Size(500, 58)
    $title.UseCompatibleTextRendering = $true
    $title.AutoEllipsis = $false
    $title.Anchor = 'Top, Left'
    $form.Controls.Add($title)

    $languageLabel = New-Object Windows.Forms.Label
    $languageLabel.Location = New-Object Drawing.Point(710, 24)
    $languageLabel.Size = New-Object Drawing.Size(140, 26)
    $languageLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $languageLabel.Anchor = 'Top, Right'
    $form.Controls.Add($languageLabel)

    $languageBox = New-Object Windows.Forms.ComboBox
    $languageBox.DropDownStyle = 'DropDownList'
    $languageBox.Items.Add('简体中文') | Out-Null
    $languageBox.Items.Add('English') | Out-Null
    $languageBox.Location = New-Object Drawing.Point(865, 20)
    $languageBox.Anchor = 'Top, Right'
    $languageBox.Size = New-Object Drawing.Size(170, 30)
    $languageBox.SelectedIndex = if ($script:Language -eq 'en-US') { 1 } else { 0 }
    $form.Controls.Add($languageBox)

    $subtitle = New-Object Windows.Forms.Label
    $subtitle.ForeColor = [Drawing.Color]::DarkRed
    $subtitle.Location = New-Object Drawing.Point(30, 82)
    $subtitle.Size = New-Object Drawing.Size(1140, 42)
    $subtitle.AutoEllipsis = $false
    $subtitle.UseCompatibleTextRendering = $true
    $subtitle.Anchor = 'Top, Left, Right'
    $form.Controls.Add($subtitle)

    $risk = New-Object Windows.Forms.RichTextBox
    $risk.ReadOnly = $true
    $risk.Location = New-Object Drawing.Point(30, 126)
    $risk.Size = New-Object Drawing.Size(1140, 340)
    $risk.BorderStyle = 'FixedSingle'
    $risk.BackColor = [Drawing.Color]::WhiteSmoke
    $risk.Anchor = 'Top, Left, Right'
    $form.Controls.Add($risk)

    $backupLabel = New-Object Windows.Forms.Label
    $backupLabel.Location = New-Object Drawing.Point(30, 466)
    $backupLabel.Size = New-Object Drawing.Size(1060, 28)
    $backupLabel.AutoEllipsis = $false
    $backupLabel.UseCompatibleTextRendering = $true
    $backupLabel.Anchor = 'Top, Left, Right'
    $form.Controls.Add($backupLabel)

    $backupText = New-Object Windows.Forms.Label
    $backupText.Text = $DefaultBackupRoot
    $backupText.Location = New-Object Drawing.Point(30, 502)
    $backupText.Size = New-Object Drawing.Size(870, 30)
    $backupText.BorderStyle = 'FixedSingle'
    $backupText.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $backupText.AutoEllipsis = $true
    $backupText.UseCompatibleTextRendering = $true
    $backupText.Anchor = 'Top, Left, Right'
    $form.Controls.Add($backupText)

    $backupPathToolTip = New-Object Windows.Forms.ToolTip
    $backupPathToolTip.SetToolTip($backupText, $backupText.Text)

    $browse = New-Object Windows.Forms.Button
    $browse.Location = New-Object Drawing.Point(920, 498)
    $browse.Size = New-Object Drawing.Size(190, 34)
    $browse.Anchor = 'Top, Right'
    $form.Controls.Add($browse)

    $filePlan = New-Object Windows.Forms.RichTextBox
    $filePlan.Location = New-Object Drawing.Point(30, 544)
    $filePlan.Size = New-Object Drawing.Size(1140, 108)
    $filePlan.ReadOnly = $true
    $filePlan.WordWrap = $true
    $filePlan.ScrollBars = 'Vertical'
    $filePlan.DetectUrls = $false
    $filePlan.BorderStyle = 'FixedSingle'
    $filePlan.BackColor = [Drawing.Color]::FromArgb(248,249,250)
    $filePlan.Anchor = 'Top, Left, Right'
    $form.Controls.Add($filePlan)

    $check1 = New-Object Windows.Forms.CheckBox
    $check1.Location = New-Object Drawing.Point(34, 666)
    $check1.Size = New-Object Drawing.Size(1120, 26)
    $check1.Anchor = 'Top, Left, Right'
    $check1.UseCompatibleTextRendering = $true
    $form.Controls.Add($check1)

    $check2 = New-Object Windows.Forms.CheckBox
    $check2.Location = New-Object Drawing.Point(34, 696)
    $check2.Size = New-Object Drawing.Size(1120, 26)
    $check2.Anchor = 'Top, Left, Right'
    $check2.UseCompatibleTextRendering = $true
    $form.Controls.Add($check2)

    $check3 = New-Object Windows.Forms.CheckBox
    $check3.Location = New-Object Drawing.Point(34, 726)
    $check3.Size = New-Object Drawing.Size(1120, 26)
    $check3.Anchor = 'Top, Left, Right'
    $check3.UseCompatibleTextRendering = $true
    $form.Controls.Add($check3)

    $check4 = New-Object Windows.Forms.CheckBox
    $check4.Location = New-Object Drawing.Point(34, 756)
    $check4.Size = New-Object Drawing.Size(1120, 26)
    $check4.Anchor = 'Top, Left, Right'
    $check4.UseCompatibleTextRendering = $true
    $form.Controls.Add($check4)

    $status = New-Object Windows.Forms.Label
    $status.ForeColor = [Drawing.Color]::DarkOrange
    $status.Location = New-Object Drawing.Point(30, 796)
    $status.Size = New-Object Drawing.Size(720, 52)
    $status.Anchor = 'Top, Left, Right'
    $form.Controls.Add($status)

    $exit = New-Object Windows.Forms.Button
    $exit.Location = New-Object Drawing.Point(830, 824)
    $exit.Size = New-Object Drawing.Size(125, 42)
    $exit.Anchor = 'Bottom, Right'
    $form.Controls.Add($exit)

    $continue = New-Object Windows.Forms.Button
    $continue.Location = New-Object Drawing.Point(970, 824)
    $continue.Size = New-Object Drawing.Size(150, 42)
    $continue.Enabled = $false
    $continue.Anchor = 'Bottom, Right'
    $form.Controls.Add($continue)

    $folderDialog = New-Object Windows.Forms.FolderBrowserDialog
    $folderDialog.SelectedPath = $DefaultBackupRoot
    $oobe = [ordered]@{ Countdown = 10; ScrolledBottom = $false; Accepted = $false }

    $applyLanguage = {
        Set-AppLanguage $(if ($languageBox.SelectedIndex -eq 1) { 'en-US' } else { 'zh-CN' })
        $form.Text = L "$script:AppName - 首次使用" "$script:AppName - First Run"
        $title.Text = L '首次使用设置' 'First-run setup'
        $languageLabel.Text = L '语言：' 'Language:'
        $subtitle.Text = L '请选择语言，阅读说明，并选择日志和备份保存位置。' 'Choose a language, read the notice, and choose where logs and backups are saved.'
        $risk.Text = Get-OobeRiskText
        $risk.SelectionStart = 0
        $risk.ScrollToCaret()
        $oobe.ScrolledBottom = $false
        $backupLabel.Text = L '文件保存位置：' 'Storage folder:'
        $browse.Text = L '选择文件夹…' 'Choose folder...'
        $filePlan.Text = Get-FileCreationPlanText -BackupPath $backupText.Text
        $backupPathToolTip.SetToolTip($backupText, $backupText.Text)
        $check1.Text = L '我已阅读每一步的确认内容。' 'I have read the confirmation shown before each step.'
        $check2.Text = L '重启回到 Windows 后，先重新检测。' 'After returning to Windows, run detection first.'
        $check3.Text = L '我已保存当前工作，并备份重要文件。' 'I saved my work and backed up important files.'
        $check4.Text = L '我确认以上文件保存在所选位置。' 'I confirm the listed files are saved in the selected location.'
        $exit.Text = L '退出软件' 'Exit'
        $folderDialog.Description = L '选择备份、恢复校验和日志目录' 'Select the backup, recovery check, and log folder'
        $form.Font = New-Object Drawing.Font((Get-LocalizedFontName), 9)
        $risk.Font = New-Object Drawing.Font((Get-LocalizedFontName), 9.5)
        $title.Font = New-Object Drawing.Font((Get-LocalizedFontName), 15, [Drawing.FontStyle]::Bold)
        $subtitle.Font = New-Object Drawing.Font((Get-LocalizedFontName), 9.5)
        $backupLabel.Font = New-Object Drawing.Font((Get-LocalizedFontName), 9.5, [Drawing.FontStyle]::Bold)
        $filePlan.Font = New-Object Drawing.Font((Get-LocalizedFontName), 8.5)
    }

    $update = {
        try {
            $lastPos = $risk.GetPositionFromCharIndex([math]::Max(0, $risk.TextLength - 2))
            if ($lastPos.Y -le ($risk.ClientSize.Height + 20)) { $oobe.ScrolledBottom = $true }
        } catch {}
        $filePlan.Text = Get-FileCreationPlanText -BackupPath $backupText.Text
        $backupPathToolTip.SetToolTip($backupText, $backupText.Text)
        $directory = Get-BackupDirectoryValidation -Path $backupText.Text
        $allChecked = $check1.Checked -and $check2.Checked -and $check3.Checked -and $check4.Checked
        $ready = ($oobe.Countdown -le 0) -and $oobe.ScrolledBottom -and $allChecked -and $directory.IsValid
        $continue.Enabled = $ready
        $status.ForeColor = [Drawing.Color]::DarkOrange
        if ($oobe.Countdown -gt 0) {
            $continue.Text = L "请等待 $($oobe.Countdown) 秒" "Wait $($oobe.Countdown) s"
            $status.Text = L '请完整阅读风险说明并滚动到底部。' 'Read the complete risk notice and scroll to the bottom.'
        } elseif (-not $oobe.ScrolledBottom) {
            $continue.Text = L '开始检测' 'Start detection'
            $status.Text = L '请将风险说明滚动到最底部。' 'Scroll the risk notice to the very bottom.'
        } elseif (-not $directory.IsValid) {
            $continue.Text = L '开始检测' 'Start detection'
            $status.Text = (L '所选目录不可用：' 'Selected folder unavailable: ') + $directory.Error
        } elseif (-not $allChecked) {
            $continue.Text = L '开始检测' 'Start detection'
            $status.Text = L '请确认全部四项，包括文件创建清单。' 'Confirm all four items, including the file-creation list.'
        } else {
            $continue.Text = L '开始检测' 'Start detection'
            $status.Text = L '前置确认已完成。点击后才会创建所列文件夹和日志。' 'Prerequisites confirmed. Listed folders and logs are created only after you click.'
            $status.ForeColor = [Drawing.Color]::DarkGreen
        }
    }

    $timer = New-Object Windows.Forms.Timer
    $timer.Interval = 1000
    $timer.Add_Tick({ if ($oobe.Countdown -gt 0) { $oobe.Countdown-- }; & $update })
    $timer.Start()
    $risk.Add_VScroll({ & $update })
    $risk.Add_MouseWheel({ & $update })
    $risk.Add_KeyUp({ & $update })
    foreach ($box in @($check1,$check2,$check3,$check4)) { $box.Add_CheckedChanged({ & $update }) }
    $backupText.Add_TextChanged({ & $update })
    $languageBox.Add_SelectedIndexChanged({ & $applyLanguage; & $update })
    $browse.Add_Click({ if ($folderDialog.ShowDialog() -eq 'OK') { $backupText.Text = $folderDialog.SelectedPath } })
    $exit.Add_Click({ $oobe.Accepted = $false; $form.Close() })
    $continue.Add_Click({
        $directory = Get-BackupDirectoryValidation -Path $backupText.Text -CreateIfMissing
        if (-not $directory.IsValid) {
            [Windows.Forms.MessageBox]::Show(((L '所选目录不可用：' 'Selected folder unavailable: ') + $directory.Error), $script:AppName, 'OK', 'Error') | Out-Null
            return
        }
        $oobe.Accepted = $true
        $form.Tag = [pscustomobject]@{ BackupRoot = $directory.ResolvedPath; Language = $script:Language }
        $form.Close()
    })
    $form.Add_Shown({ & $applyLanguage; $risk.Focus(); $risk.SelectionStart = 0; $risk.ScrollToCaret(); & $update })
    $form.ShowDialog() | Out-Null
    $timer.Stop()
    if (-not $oobe.Accepted) { return $null }
    return $form.Tag
}

function Get-RecoveryStageFromEvidence {
    param(
        [Parameter(Mandatory)][object]$State,
        [Parameter(Mandatory)][System.Collections.IDictionary]$ExpectedHashes,
        [Parameter(Mandatory)][byte[]]$CertificateBytes
    )
    $pk = $State.Variables.PK.Exists
    $kek = $State.Variables.KEK.Exists
    $db = $State.Variables.db.Exists
    $dbx = $State.Variables.dbx.Exists

    if (-not $pk -and -not $kek -and -not $db -and -not $dbx) {
        return [pscustomobject]@{ IsValid = $true; Stage = 'NoKeysReady'; Message = L '识别为无活动Keys的干净起点。' 'Recognized as a clean starting point with no Active Keys.' }
    }
    if ($db -and -not $dbx -and -not $kek -and -not $pk) {
        if ($State.Variables.db.Sha256 -eq [string]$ExpectedHashes.DbDefault) {
            return [pscustomobject]@{ IsValid = $true; Stage = 'DbDefaultWritten'; Message = L '活动db精确匹配备份的dbDefault。' 'The active db exactly matches the backed-up dbDefault.' }
        }
        if ($State.Variables.db.Sha256 -eq [string]$ExpectedHashes.DbWith2023) {
            $der = Test-ContainsByteSequence -Container ([byte[]]$State.Variables.db.Bytes) -Sequence $CertificateBytes
            $name = [Text.Encoding]::ASCII.GetString([byte[]]$State.Variables.db.Bytes) -match 'Windows UEFI CA 2023'
            if ($der -and $name) {
                return [pscustomobject]@{ IsValid = $true; Stage = 'Db2023Written'; Message = L '活动db精确匹配dbDefault加官方2023证书。' 'The active db exactly matches dbDefault plus the official 2023 certificate.' }
            }
        }
        return [pscustomobject]@{ IsValid = $false; Stage = ''; Message = L '仅db存在，但其哈希既不匹配dbDefault，也不匹配理论上的dbDefault+2023证书。' 'Only db exists, but its hash matches neither dbDefault nor the theoretical dbDefault + 2023 certificate.' }
    }
    if ($db -and $dbx -and -not $kek -and -not $pk) {
        $valid = $State.Variables.db.Sha256 -eq [string]$ExpectedHashes.DbWith2023 -and $State.Variables.dbx.Sha256 -eq [string]$ExpectedHashes.DbxDefault
        return [pscustomobject]@{ IsValid = $valid; Stage = if ($valid) { 'DbxWritten' } else { '' }; Message = if ($valid) { L '活动db和dbx精确匹配合法检查点。' 'The active db and dbx exactly match a valid checkpoint.' } else { L 'db 或 dbx 与恢复校验不一致。' 'The db or dbx does not match the recovery check.' } }
    }
    if ($db -and $dbx -and $kek -and -not $pk) {
        $valid = $State.Variables.db.Sha256 -eq [string]$ExpectedHashes.DbWith2023 -and $State.Variables.dbx.Sha256 -eq [string]$ExpectedHashes.DbxDefault -and $State.Variables.KEK.Sha256 -eq [string]$ExpectedHashes.KekDefault
        return [pscustomobject]@{ IsValid = $valid; Stage = if ($valid) { 'KekWritten' } else { '' }; Message = if ($valid) { L '活动db、dbx和KEK精确匹配合法检查点。' 'The active db, dbx, and KEK exactly match a valid checkpoint.' } else { L 'db、dbx 或 KEK 与恢复校验不一致。' 'The db, dbx, or KEK does not match the recovery check.' } }
    }
    if ($db -and $dbx -and $kek -and $pk) {
        $valid = $State.Variables.db.Sha256 -eq [string]$ExpectedHashes.DbWith2023 -and $State.Variables.dbx.Sha256 -eq [string]$ExpectedHashes.DbxDefault -and $State.Variables.KEK.Sha256 -eq [string]$ExpectedHashes.KekDefault -and $State.Variables.PK.Sha256 -eq [string]$ExpectedHashes.PkDefault
        return [pscustomobject]@{ IsValid = $valid; Stage = if ($valid) { 'PkWritten' } else { '' }; Message = if ($valid) { L '完整活动Keys精确匹配PK写入后的合法检查点。' 'All Active Keys exactly match the valid post-PK checkpoint.' } else { L '完整 Active Keys 与恢复校验不一致。' 'The complete Active Keys do not match the recovery check.' } }
    }
    return [pscustomobject]@{ IsValid = $false; Stage = ''; Message = L '当前 Active Key 组合不在可继续范围内。' 'The current active-key combination is not in a resumable state.' }
}

function Confirm-AdvancedRecoveryWarning {
    param([Parameter(Mandatory)][string]$Stage, [Parameter(Mandatory)][string]$Message)
    $warningZh = @"
识别检查点：$Stage
校验结果：$Message

确认后重建进度记录，不立即写入固件。后续步骤逐项确认。

当前记录无法证明之前的写入来源。请确认你使用的是本机保存的 Default Keys 备份和微软官方证书。

仍要重建进度吗？
"@
    $warningEn = @"
Detected checkpoint: $Stage
Check result: $Message

Continuing rebuilds the saved progress without writing firmware. Each later step requires confirmation.

The current records cannot prove the source of earlier writes. Confirm that you are using Default Keys backups from this device and the official Microsoft certificate.

Rebuild progress?
"@
    return (Show-ConfirmationWarning -Title (L '确认重建进度' 'Confirm progress rebuild') -Message (L $warningZh $warningEn))
}

function New-AdvancedRecoveryTransaction {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$BackupFiles,
        [Parameter(Mandatory)][string]$CertificatePath,
        [Parameter(Mandatory)][string]$Origin,
        [string]$SourceDescription = ''
    )
    $state = Get-SystemState
    if (-not $state.IsAsus -or -not $state.IsUEFI) { throw (L '高级恢复只允许在ASUS/ROG且当前以UEFI启动的设备上运行。' 'Interruption recovery is permitted only on ASUS/ROG devices currently booted in UEFI mode.') }
    if (-not $state.ActiveVariablesReadable -or -not $state.DefaultVariablesReadable -or -not $state.DefaultsAllReadable) { throw (L '活动Keys或BIOS默认Keys无法完整读取，禁止中断恢复。' 'Active Keys or BIOS factory Keys cannot be read completely. Interruption recovery is blocked.') }
    if ($state.SetupMode -ne 1 -and -not $state.AllKeys) { throw (L '当前不是可验证的Setup Mode中间态。' 'The current state is not a verifiable Setup Mode intermediate state.') }

    $nameMap = [ordered]@{ PKDefault='PkDefault'; KEKDefault='KekDefault'; dbDefault='DbDefault'; dbxDefault='DbxDefault' }
    $expected = [ordered]@{}
    $lengths = [ordered]@{}
    foreach ($name in $nameMap.Keys) {
        if (-not $BackupFiles.Contains($name)) { throw ((L '恢复校验缺少文件：{0}' 'Recovery check is missing file: {0}') -f $name) }
        $path = [string]$BackupFiles[$name]
        if (-not (Test-Path -LiteralPath $path)) { throw ((L '找不到恢复校验文件：{0}' 'Recovery check file not found: {0}') -f $path) }
        Assert-NoReparsePoint -Path $path
        $bytes = [IO.File]::ReadAllBytes($path)
        $hash = Get-ByteHashHex -Bytes $bytes -Algorithm SHA256
        $firmware = $state.Variables[$name]
        if ($bytes.Length -ne $firmware.Length -or $hash -ne $firmware.Sha256 -or -not (Test-ByteArrayEqual -A $bytes -B ([byte[]]$firmware.Bytes))) {
            throw ((L '{0}备份与当前BIOS默认Keys不完全一致。' 'The {0} backup does not exactly match the current BIOS factory Key.') -f $name)
        }
        $expected[$nameMap[$name]] = $hash
        $lengths[$nameMap[$name]] = $bytes.Length
    }

    $certValidation = Validate-CertificateFile $CertificatePath
    if (-not $certValidation.IsValid) { throw ((L '官方证书校验失败：' 'Official certificate validation failed: ') + ($certValidation.Errors -join ', ')) }
    $certBytesBefore = [IO.File]::ReadAllBytes($CertificatePath)
    $time = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $formatted = Format-SecureBootUEFI -Name db -SignatureOwner $script:OfficialCertificateSignatureOwner -CertificateFilePath $CertificatePath -FormatWithCert -AppendWrite -Time $time -ErrorAction Stop
    $certBytesAfter = [IO.File]::ReadAllBytes($CertificatePath)
    if (-not (Test-ByteArrayEqual -A $certBytesBefore -B $certBytesAfter)) { throw (L '证书文件在验证与格式化之间发生变化，禁止继续。' 'The certificate file changed between validation and formatting; continuing is blocked.') }
    $dbDefaultBytes = [IO.File]::ReadAllBytes([string]$BackupFiles.dbDefault)
    $defaultDerFound = Test-ContainsByteSequence -Container $dbDefaultBytes -Sequence $certBytesBefore
    $defaultNameFound = [Text.Encoding]::ASCII.GetString($dbDefaultBytes) -match 'Windows UEFI CA 2023'
    if ($defaultNameFound -and -not $defaultDerFound) { throw (L 'dbDefault出现2023证书名称但不包含官方证书完整DER，禁止中断恢复。' 'dbDefault contains the 2023 certificate name but not the exact official DER certificate; interruption recovery is blocked.') }
    if ($defaultDerFound) {
        $expectedDbBytes = $dbDefaultBytes
        $expected.DbWith2023 = [string]$expected.DbDefault
        $formattedLength = 0
    } else {
        $expectedDbBytes = Join-ByteArrays -First $dbDefaultBytes -Second ([byte[]]$formatted.Content)
        $expected.DbWith2023 = Get-ByteHashHex -Bytes $expectedDbBytes -Algorithm SHA256
        $formattedLength = $formatted.Content.Count
    }

    $checkpoint = Get-RecoveryStageFromEvidence -State $state -ExpectedHashes $expected -CertificateBytes $certBytesBefore
    if (-not $checkpoint.IsValid) { throw $checkpoint.Message }
    if (-not (Confirm-AdvancedRecoveryWarning -Stage $checkpoint.Stage -Message $checkpoint.Message)) { return $null }

    $transactionId = [Guid]::NewGuid().ToString('N')
    $transactionRoot = Join-Path $script:BackupRoot (Join-Path 'Transactions' $transactionId)
    $keyRoot = Join-Path $transactionRoot 'KeyBackups'
    $evidenceRoot = Join-Path $transactionRoot 'Evidence'
    New-Item -ItemType Directory -Path $keyRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null
    Assert-NoReparsePoint -Path $script:BackupRoot
    Assert-NoReparsePoint -Path $transactionRoot

    foreach ($name in $nameMap.Keys) {
        $target = Join-Path $keyRoot "$name.bin"
        Copy-Item -LiteralPath ([string]$BackupFiles[$name]) -Destination $target -Force
        $copied = [IO.File]::ReadAllBytes($target)
        if ((Get-ByteHashHex -Bytes $copied -Algorithm SHA256) -ne [string]$expected[$nameMap[$name]]) { throw "$name recovery copy hash mismatch." }
    }
    $certEvidence = Join-Path $evidenceRoot $script:OfficialCertificateFileName
    Copy-Item -LiteralPath $CertificatePath -Destination $certEvidence -Force
    if ((Get-FileHashHex -Path $certEvidence -Algorithm SHA256) -ne $script:OfficialCertificateSha256) { throw (L '证书文件复制后的 SHA-256 不一致。' 'The copied certificate file has an unexpected SHA-256.') }

    $completeByStage = @{
        NoKeysReady=@(); DbDefaultWritten=@('DbDefault'); Db2023Written=@('DbDefault','Db2023');
        DbxWritten=@('DbDefault','Db2023','DbxDefault'); KekWritten=@('DbDefault','Db2023','DbxDefault','KekDefault');
        PkWritten=@('DbDefault','Db2023','DbxDefault','KekDefault','PkDefault')
    }
    $steps = [ordered]@{ Backup='Complete'; DbDefault='NotStarted'; Db2023='NotStarted'; DbxDefault='NotStarted'; KekDefault='NotStarted'; PkDefault='NotStarted'; Reboot='NotStarted'; OfficialRotation='NotStarted' }
    foreach ($step in @($completeByStage[$checkpoint.Stage])) { $steps[$step] = 'Complete' }

    $transactionPath = Join-Path $transactionRoot 'transaction.json'
    $transaction = [ordered]@{
        SchemaVersion = 2; TransactionId = $transactionId; Status = 'Active'; CurrentStep = $checkpoint.Stage; PendingOperation = ''
        CreatedAt = (Get-Date).ToString('o'); UpdatedAt = (Get-Date).ToString('o'); BackupRoot = $script:BackupRoot
        TransactionRoot = $transactionRoot; TransactionPath = $transactionPath; KeyBackupRoot = $keyRoot; EvidenceRoot = $evidenceRoot
        Origin = $Origin; SourceDescription = $SourceDescription; AdvancedRecoveryAcknowledgedAt = (Get-Date).ToString('o')
        Device = [ordered]@{ Manufacturer=$state.Manufacturer; Model=$state.Model; BaseBoard=$state.BaseBoard; BaseBoardManufacturer=$state.BaseBoardManufacturer; BIOSVersion=$state.BIOSVersion }
        DefaultLengths = $lengths; ExpectedHashes = $expected
        Certificate = [ordered]@{ Validated=$true; EvidencePath=$certEvidence; SHA256=$certValidation.SHA256; MD5=$certValidation.MD5; Thumbprint=$certValidation.CertificateThumbprint; FormattedLength=$formattedLength }
        Steps = $steps; LastError=''; LastWriteIntent=$null; LastVerifiedAt=(Get-Date).ToString('o'); PkWrittenAt=''; BootTimeAtPk=''
    }
    Save-Transaction $transaction
    $script:SelectedCertificatePath = $certEvidence
    Write-UiLog ((L '中断恢复进度已建立。来源={0}，检查点={1}，目录={2}。本次未写入 UEFI。' 'Interrupted recovery progress created. Origin={0}, checkpoint={1}, folder={2}. No UEFI write occurred in this operation.') -f $Origin,$checkpoint.Stage,$transactionRoot) 'SUCCESS'
    [Windows.Forms.MessageBox]::Show(((L '已重建进度记录，但没有执行 UEFI 写入。文件位置：' 'Saved progress was rebuilt without any UEFI write. Folder: ') + [Environment]::NewLine + $transactionRoot), $script:AppName, 'OK', 'Information') | Out-Null
    return $transaction
}

function Write-RecoveryPackageManifest {
    param([System.Collections.IDictionary]$Transaction)
    if ($null -eq $Transaction -or -not (Test-Path -LiteralPath $Transaction.TransactionRoot)) { return }
    $files = [ordered]@{}
    foreach ($name in @('PKDefault','KEKDefault','dbDefault','dbxDefault')) {
        $path = Join-Path $Transaction.KeyBackupRoot "$name.bin"
        if (Test-Path -LiteralPath $path) {
            $files["KeyBackups/$name.bin"] = Get-FileHashHex -Path $path -Algorithm SHA256
        }
    }
    $cert = Join-Path $Transaction.EvidenceRoot $script:OfficialCertificateFileName
    if (Test-Path -LiteralPath $cert) { $files["Evidence/$script:OfficialCertificateFileName"] = Get-FileHashHex -Path $cert -Algorithm SHA256 }
    $manifest = [ordered]@{
        SchemaVersion = 1; PackageType = 'ASUSROG-SecureBoot-Recovery'; CreatedAt=(Get-Date).ToString('o')
        AppVersion=$script:AppVersion; TransactionId=$Transaction.TransactionId; Status=$Transaction.Status; CurrentStep=$Transaction.CurrentStep
        Device=$Transaction.Device; DefaultLengths=$Transaction.DefaultLengths; ExpectedHashes=$Transaction.ExpectedHashes
        Certificate=[ordered]@{ SHA256=$Transaction.Certificate.SHA256; Thumbprint=$Transaction.Certificate.Thumbprint; FormattedLength=$Transaction.Certificate.FormattedLength }
        Files=$files
    }
    Write-JsonAtomic -Path (Join-Path $Transaction.TransactionRoot 'recovery-package.json') -Object $manifest -Depth 10
}

function Export-RecoveryPackage {
    if ($null -eq $script:CurrentTransaction) { throw (L '当前没有可导出的修复进度。' 'There is no repair progress to export.') }
    $explanationZh = @'
恢复文件包含 Default Keys 备份和设备信息，用于确认未完成的修复进度。导入时不写入固件。

不要公开上传。继续选择保存位置吗？
'@
    $explanationEn = @'
The recovery file contains Default Keys backups and device information. Purpose: check unfinished repair progress. Firmware write: none.

Do not upload it publicly. Continue to choose a save location?
'@
    $explanation = L $explanationZh $explanationEn
    if (-not (Show-ConfirmationWarning -Title (L '保存恢复文件' 'Save recovery file') -Message $explanation)) { return }

    Write-RecoveryPackageManifest $script:CurrentTransaction
    $dialog = New-Object Windows.Forms.SaveFileDialog
    $dialog.Title = L '选择恢复文件的保存位置' 'Choose where to save the recovery file'
    $dialog.Filter = L '恢复文件 (*.zip)|*.zip' 'Recovery file (*.zip)|*.zip'
    $dialog.FileName = ('ASUSROG-SecureBoot-Recovery-{0}-{1}.zip' -f $script:CurrentTransaction.TransactionId.Substring(0,8),(Get-Date -Format 'yyyyMMdd-HHmmss'))
    if ($dialog.ShowDialog() -ne 'OK') { return }
    if (Test-Path -LiteralPath $dialog.FileName) { Remove-Item -LiteralPath $dialog.FileName -Force }
    $staging = Join-Path $script:AppDataRoot ('recovery-export-' + [Guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Path (Join-Path $staging 'KeyBackups') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $staging 'Evidence') -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:CurrentTransaction.TransactionRoot 'recovery-package.json') -Destination (Join-Path $staging 'recovery-package.json') -Force
        foreach ($name in @('PKDefault','KEKDefault','dbDefault','dbxDefault')) {
            Copy-Item -LiteralPath (Join-Path $script:CurrentTransaction.KeyBackupRoot "$name.bin") -Destination (Join-Path $staging (Join-Path 'KeyBackups' "$name.bin")) -Force
        }
        $cert = Join-Path $script:CurrentTransaction.EvidenceRoot $script:OfficialCertificateFileName
        if (Test-Path -LiteralPath $cert) { Copy-Item -LiteralPath $cert -Destination (Join-Path $staging (Join-Path 'Evidence' $script:OfficialCertificateFileName)) -Force }
        Protect-AppDataDirectory -Path $script:AppDataRoot
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::CreateFromDirectory($staging, $dialog.FileName, [IO.Compression.CompressionLevel]::Optimal, $false)
    } finally {
        Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-UiLog ((L '恢复文件已保存：{0}。它包含 Default Keys 备份，请勿上传公开平台。' 'Recovery file saved: {0}. It contains Default Keys backups; do not upload it publicly.') -f $dialog.FileName) 'SUCCESS'
    [Windows.Forms.MessageBox]::Show(((L '文件已生成在：' 'File created at: ') + $dialog.FileName), $script:AppName, 'OK', 'Information') | Out-Null
}

function Expand-RecoveryPackageSafe {
    param([Parameter(Mandatory)][string]$ZipPath)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $target = Join-Path $script:AppDataRoot ('recovery-import-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Protect-AppDataDirectory -Path $script:AppDataRoot
    $archive = [IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        if ($archive.Entries.Count -gt 64) { throw (L '恢复文件条目过多。' 'The recovery file contains too many entries.') }
        $totalLength = [int64]0
        $seenEntries = @{}
        foreach ($entry in $archive.Entries) {
            $entryKey = $entry.FullName.ToLowerInvariant()
            if ($seenEntries.ContainsKey($entryKey)) { throw (L '恢复文件包含重复条目。' 'The recovery file contains duplicate entries.') }
            $seenEntries[$entryKey] = $true
            if ($entry.Length -gt 10485760) { throw (L '恢复文件中的单个文件超过 10MB 限制。' 'A file in the recovery file exceeds the 10 MB limit.') }
            $totalLength += [int64]$entry.Length
            if ($totalLength -gt 26214400) { throw (L '恢复文件解压总大小超过 25MB 限制。' 'The total uncompressed recovery file size exceeds the 25 MB limit.') }
            if ([string]::IsNullOrWhiteSpace($entry.FullName)) { continue }
            if ($entry.FullName -match '(^|[\\/])\.\.([\\/]|$)' -or [IO.Path]::IsPathRooted($entry.FullName)) { throw (L '恢复文件包含越界路径。' 'The recovery file contains a path traversal entry.') }
            $destination = Join-Path $target $entry.FullName
            if (-not (Test-PathIsUnderRoot -Path $destination -Root $target)) { throw (L '恢复文件条目超出临时目录。' 'A recovery file entry escapes the temporary folder.') }
            if ($entry.FullName.EndsWith('/')) { New-Item -ItemType Directory -Path $destination -Force | Out-Null; continue }
            $extension = [IO.Path]::GetExtension($destination).ToLowerInvariant()
            if ($extension -notin @('.json','.bin','.cer','.crt')) { throw ((L '恢复文件包含不允许的文件类型：{0}' 'The recovery file contains a disallowed file type: {0}') -f $extension) }
            $parent = Split-Path -Parent $destination
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $true)
        }
    } finally { $archive.Dispose() }
    Protect-AppDataDirectory -Path $script:AppDataRoot
    return $target
}

function Import-RecoveryPackage {
    $dialog = New-Object Windows.Forms.OpenFileDialog
    $dialog.Title = L '选择恢复文件' 'Select a recovery file'
    $dialog.Filter = L '恢复文件 ZIP (*.zip)|*.zip' 'Recovery file ZIP (*.zip)|*.zip'
    if ($dialog.ShowDialog() -ne 'OK') { return }
    $root = Expand-RecoveryPackageSafe -ZipPath $dialog.FileName
    try {
        $manifestCandidates = @(Get-ChildItem -LiteralPath $root -Filter 'recovery-package.json' -Recurse -File)
        if ($manifestCandidates.Count -ne 1) { throw (L '恢复文件必须且只能包含一个 recovery-package.json。' 'The recovery file must contain exactly one recovery-package.json.') }
        $manifestPath = $manifestCandidates[0].FullName
        if (-not $manifestPath) { throw (L '恢复文件缺少 recovery-package.json。' 'The recovery file is missing recovery-package.json.') }
        $packageRoot = Split-Path -Parent $manifestPath
        $manifest = Read-JsonSafe $manifestPath
        if ($null -eq $manifest -or [int]$manifest.SchemaVersion -ne 1 -or [string]$manifest.PackageType -ne 'ASUSROG-SecureBoot-Recovery') { throw (L '恢复文件格式或版本无效。' 'The recovery file format or version is invalid.') }
        $state = Get-SystemState
        foreach ($field in @('Manufacturer','Model','BaseBoard','BaseBoardManufacturer','BIOSVersion')) {
            $actual = [string](Get-OptionalPropertyValue -Object $state -Name $field -Default '')
            $expectedDevice = [string](Get-OptionalPropertyValue -Object $manifest.Device -Name $field -Default '')
            if (-not [string]::Equals($actual,$expectedDevice,[StringComparison]::OrdinalIgnoreCase)) { throw ((L '恢复文件设备信息不匹配：{0}' 'Recovery file device information mismatch: {0}') -f $field) }
        }
        $filesTable = ConvertTo-Hashtable $manifest.Files
        if ($null -eq $filesTable -or $filesTable.Count -lt 4) { throw (L '恢复文件清单不完整。' 'The recovery file manifest is incomplete.') }
        foreach ($relative in $filesTable.Keys) {
            $path = Join-Path $packageRoot ([string]$relative).Replace('/',[IO.Path]::DirectorySeparatorChar)
            if (-not (Test-PathIsUnderRoot -Path $path -Root $packageRoot) -or -not (Test-Path -LiteralPath $path)) { throw ((L '恢复文件缺失或越界：{0}' 'Recovery file is missing or out of bounds: {0}') -f $relative) }
            if ((Get-FileHashHex -Path $path -Algorithm SHA256) -ne [string]$filesTable[$relative]) { throw ((L '恢复文件 SHA-256 不匹配：{0}' 'Recovery file SHA-256 mismatch: {0}') -f $relative) }
        }
        $backupFiles = [ordered]@{}
        foreach ($name in @('PKDefault','KEKDefault','dbDefault','dbxDefault')) {
            $path = Join-Path $packageRoot (Join-Path 'KeyBackups' "$name.bin")
            if (-not (Test-Path -LiteralPath $path)) { throw ((L '恢复文件缺少：{0}' 'Recovery file is missing: {0}') -f "$name.bin") }
            $backupFiles[$name] = $path
        }
        $certPath = Join-Path $packageRoot (Join-Path 'Evidence' $script:OfficialCertificateFileName)
        if (-not (Test-Path -LiteralPath $certPath)) {
            $certDialog = New-Object Windows.Forms.OpenFileDialog
            $certDialog.Title = L '恢复文件未包含证书，请选择微软官方 Windows UEFI CA 2023 证书' 'The recovery file does not include the certificate. Select the official Microsoft Windows UEFI CA 2023 certificate.'
            $certDialog.Filter = L '证书文件 (*.cer;*.crt)|*.cer;*.crt' 'Certificate files (*.cer;*.crt)|*.cer;*.crt'
            if ($certDialog.ShowDialog() -ne 'OK') { return }
            $certPath = $certDialog.FileName
        }
        $tx = New-AdvancedRecoveryTransaction -BackupFiles $backupFiles -CertificatePath $certPath -Origin 'ImportedRecoveryPackage' -SourceDescription ([IO.Path]::GetFileName($dialog.FileName))
        if ($null -ne $tx) { $script:CurrentTransaction = $tx }
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Rebuild-TransactionFromSelectedEvidence {
    $folder = New-Object Windows.Forms.FolderBrowserDialog
    $folder.Description = L '选择包含PKDefault.bin、KEKDefault.bin、dbDefault.bin、dbxDefault.bin的KeyBackups目录' 'Select the KeyBackups folder containing PKDefault.bin, KEKDefault.bin, dbDefault.bin, and dbxDefault.bin'
    if ($folder.ShowDialog() -ne 'OK') { return }
    $backupFiles = [ordered]@{}
    foreach ($name in @('PKDefault','KEKDefault','dbDefault','dbxDefault')) {
        $path = Join-Path $folder.SelectedPath "$name.bin"
        if (-not (Test-Path -LiteralPath $path)) { throw ((L '所选目录缺少：{0}.bin' 'The selected folder is missing: {0}.bin') -f $name) }
        $backupFiles[$name] = $path
    }
    $certDialog = New-Object Windows.Forms.OpenFileDialog
    $certDialog.Title = L '选择微软官方Windows UEFI CA 2023证书' 'Select the official Microsoft Windows UEFI CA 2023 certificate'
    $certDialog.Filter = L '证书文件 (*.cer;*.crt)|*.cer;*.crt' 'Certificate files (*.cer;*.crt)|*.cer;*.crt'
    if ($certDialog.ShowDialog() -ne 'OK') { return }
    $tx = New-AdvancedRecoveryTransaction -BackupFiles $backupFiles -CertificatePath $certDialog.FileName -Origin 'ManualEvidenceReconstruction' -SourceDescription 'UserSelectedKeyBackups'
    if ($null -ne $tx) { $script:CurrentTransaction = $tx }
}

function Show-AdvancedRecoveryDialog {
    $form = New-Object Windows.Forms.Form
    $form.Text = L '恢复未完成的修复流程' 'Recover an unfinished repair workflow'
    $form.ClientSize = New-Object Drawing.Size(700,380)
    $form.AutoScaleMode = 'Dpi'
    $form.StartPosition = 'CenterParent'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ShowInTaskbar = $false
    $form.AutoScroll = $true
    $form.Font = New-Object Drawing.Font((Get-LocalizedFontName),9)

    $title = New-Object Windows.Forms.Label
    $title.Text = L '继续未完成的修复' 'Continue an unfinished repair'
    $title.Font = New-Object Drawing.Font((Get-LocalizedFontName),12,[Drawing.FontStyle]::Bold)
    $title.Location = New-Object Drawing.Point(24,18)
    $title.Size = New-Object Drawing.Size(630,32)
    $title.Anchor = 'Top, Left, Right'
    $form.Controls.Add($title)

    $label = New-Object Windows.Forms.Label
    $label.Location = New-Object Drawing.Point(24,58)
    $label.Size = New-Object Drawing.Size(640,142)
    $advancedZh = @'
修复中断、记录丢失或只剩部分 Active Keys 时使用。

请选择恢复文件，或选择四个 Default Keys 备份和微软官方证书。验证通过后恢复进度，不写入固件。
'@
    $advancedEn = @'
Use this after an interrupted repair, missing records, or a partial Active Keys state.

Select a recovery file, or all four Default Keys backups and the official Microsoft certificate. A successful check restores progress without writing firmware.
'@
    $label.Text = L $advancedZh $advancedEn
    $label.Anchor = 'Top, Bottom, Left, Right'
    $form.Controls.Add($label)

    $import = New-Object Windows.Forms.Button
    $import.Text = L '导入以前保存的恢复文件…' 'Import a previously saved recovery file...'
    $import.Location = New-Object Drawing.Point(32,225)
    $import.Size = New-Object Drawing.Size(200,62)
    $import.Anchor = 'Bottom, Left'
    $form.Controls.Add($import)

    $manual = New-Object Windows.Forms.Button
    $manual.Text = L '用Default Keys备份验证当前进度…' 'Verify progress from Default Keys backups...'
    $manual.Location = New-Object Drawing.Point(248,225)
    $manual.Size = New-Object Drawing.Size(245,62)
    $manual.Anchor = 'Bottom, Left'
    $form.Controls.Add($manual)

    $cancel = New-Object Windows.Forms.Button
    $cancel.Text = L '取消' 'Cancel'
    $cancel.Location = New-Object Drawing.Point(510,225)
    $cancel.Size = New-Object Drawing.Size(140,62)
    $cancel.Anchor = 'Bottom, Right'
    $form.Controls.Add($cancel)

    $note = New-Object Windows.Forms.Label
    $note.Text = L '恢复进度后，写入步骤逐项确认。' 'After progress is restored, each write step requires confirmation.'
    $note.ForeColor = [Drawing.Color]::DarkRed
    $note.Location = New-Object Drawing.Point(28,310)
    $note.Size = New-Object Drawing.Size(630,44)
    $note.Anchor = 'Bottom, Left, Right'
    $form.Controls.Add($note)

    $import.Add_Click({ $form.Tag='Import'; $form.Close() })
    $manual.Add_Click({ $form.Tag='Manual'; $form.Close() })
    $cancel.Add_Click({ $form.Tag='Cancel'; $form.Close() })
    $form.ShowDialog($script:MainForm) | Out-Null
    switch ([string]$form.Tag) { 'Import' { Import-RecoveryPackage }; 'Manual' { Rebuild-TransactionFromSelectedEvidence } }
}

function Load-CurrentTransaction {
    $script:TransactionLoadError = ''
    $mirror = Read-JsonSafe $script:TransactionMirrorPath
    if ($null -eq $mirror) { return $null }

    $mirrorSchema = [int](Get-OptionalPropertyValue -Object $mirror -Name 'SchemaVersion' -Default 0)
    if ($mirrorSchema -ne 2) {
        $script:TransactionLoadError = "进度镜像 SchemaVersion=$mirrorSchema，不兼容当前版本。"
        return $null
    }
    $transactionId = [string](Get-OptionalPropertyValue -Object $mirror -Name 'TransactionId' -Default '')
    $transactionPath = [string](Get-OptionalPropertyValue -Object $mirror -Name 'TransactionPath' -Default '')
    $mirrorBackupRoot = [string](Get-OptionalPropertyValue -Object $mirror -Name 'BackupRoot' -Default '')
    $expectedFileHash = [string](Get-OptionalPropertyValue -Object $mirror -Name 'TransactionSha256' -Default '')
    if ($transactionId -notmatch '^[0-9a-fA-F]{32}$') {
        $script:TransactionLoadError = '进度镜像中的 TransactionId 格式无效。'
        return $null
    }
    if (-not (Test-PathsEqual -First $mirrorBackupRoot -Second $script:BackupRoot)) {
        $script:TransactionLoadError = '进度镜像绑定的备份根目录与当前设置不一致。'
        return $null
    }
    $expectedTransactionPath = Join-Path $script:BackupRoot (Join-Path 'Transactions' (Join-Path $transactionId 'transaction.json'))
    if (-not (Test-PathsEqual -First $transactionPath -Second $expectedTransactionPath)) {
        $script:TransactionLoadError = '进度记录路径不符合目录结构。'
        return $null
    }
    if (-not (Test-PathIsUnderRoot -Path $transactionPath -Root $script:BackupRoot) -or -not (Test-Path -LiteralPath $transactionPath)) {
        $script:TransactionLoadError = '进度文件不存在或不在当前备份根目录内。'
        return $null
    }
    try {
        Assert-NoReparsePoint -Path $script:BackupRoot
        Assert-NoReparsePoint -Path (Split-Path -Parent $transactionPath)
        Assert-NoReparsePoint -Path $transactionPath
    } catch {
        $script:TransactionLoadError = '进度目录或文件包含重解析点，禁止加载：' + $_.Exception.Message
        return $null
    }
    if ([string]::IsNullOrWhiteSpace($expectedFileHash) -or (Get-FileHashHex -Path $transactionPath -Algorithm SHA256) -ne $expectedFileHash) {
        $script:TransactionLoadError = '进度文件完整性校验失败，可能被修改或上次写入被意外中断。'
        return $null
    }

    $transaction = Read-JsonSafe $transactionPath
    if ($null -eq $transaction) {
        $script:TransactionLoadError = '进度文件无法解析。'
        return $null
    }
    $schema = Get-OptionalPropertyValue -Object $transaction -Name 'SchemaVersion' -Default 0
    if ([int]$schema -ne 2) {
        $script:TransactionLoadError = "进度 SchemaVersion=$schema，不兼容当前版本。为避免错误续写，已停止自动恢复。"
        return $null
    }
    foreach ($required in @('TransactionId','Status','TransactionPath','BackupRoot','TransactionRoot','KeyBackupRoot','EvidenceRoot','ExpectedHashes','Steps','Device')) {
        if ($null -eq (Get-OptionalPropertyValue -Object $transaction -Name $required)) {
            $script:TransactionLoadError = "进度记录缺少字段：$required。"
            return $null
        }
    }
    if (-not [string]::Equals([string]$transaction.TransactionId, $transactionId, [StringComparison]::OrdinalIgnoreCase)) {
        $script:TransactionLoadError = '进度 ID 与受保护镜像不一致。'
        return $null
    }
    $expectedRoot = Split-Path -Parent $expectedTransactionPath
    $expectedKeys = Join-Path $expectedRoot 'KeyBackups'
    $expectedEvidence = Join-Path $expectedRoot 'Evidence'
    $pathChecks = @(
        @([string]$transaction.BackupRoot, $script:BackupRoot, 'BackupRoot'),
        @([string]$transaction.TransactionRoot, $expectedRoot, 'TransactionRoot'),
        @([string]$transaction.TransactionPath, $expectedTransactionPath, 'TransactionPath'),
        @([string]$transaction.KeyBackupRoot, $expectedKeys, 'KeyBackupRoot'),
        @([string]$transaction.EvidenceRoot, $expectedEvidence, 'EvidenceRoot')
    )
    foreach ($check in $pathChecks) {
        if (-not (Test-PathsEqual -First ([string]$check[0]) -Second ([string]$check[1]))) {
            $script:TransactionLoadError = "进度路径字段不一致：$($check[2])。"
            return $null
        }
    }
    return $transaction
}

function Save-Transaction {
    param([System.Collections.IDictionary]$Transaction)
    if ($null -eq $Transaction -or -not $Transaction.TransactionPath) { throw '进度路径不存在。' }
    $transactionId = [string]$Transaction.TransactionId
    if ($transactionId -notmatch '^[0-9a-fA-F]{32}$') { throw '进度 ID 格式无效。' }
    $expectedRoot = Join-Path $script:BackupRoot (Join-Path 'Transactions' $transactionId)
    $expectedPath = Join-Path $expectedRoot 'transaction.json'
    if (-not (Test-PathsEqual -First ([string]$Transaction.BackupRoot) -Second $script:BackupRoot)) { throw '进度 BackupRoot 越界。' }
    if (-not (Test-PathsEqual -First ([string]$Transaction.TransactionRoot) -Second $expectedRoot)) { throw '进度 TransactionRoot 越界。' }
    if (-not (Test-PathsEqual -First ([string]$Transaction.TransactionPath) -Second $expectedPath)) { throw '进度 TransactionPath 越界。' }
    if (-not (Test-PathIsUnderRoot -Path ([string]$Transaction.KeyBackupRoot) -Root $expectedRoot) -or -not (Test-PathIsUnderRoot -Path ([string]$Transaction.EvidenceRoot) -Root $expectedRoot)) { throw '进度子目录越界。' }
    Assert-NoReparsePoint -Path $script:BackupRoot
    Assert-NoReparsePoint -Path $expectedRoot
    Assert-NoReparsePoint -Path ([string]$Transaction.KeyBackupRoot)
    Assert-NoReparsePoint -Path ([string]$Transaction.EvidenceRoot)

    $Transaction.UpdatedAt = (Get-Date).ToString('o')
    Write-JsonAtomic -Path $Transaction.TransactionPath -Object $Transaction -Depth 12
    $transactionHash = Get-FileHashHex -Path $Transaction.TransactionPath -Algorithm SHA256
    $mirror = [ordered]@{
        SchemaVersion = 2
        TransactionId = $Transaction.TransactionId
        TransactionPath = $Transaction.TransactionPath
        BackupRoot = $Transaction.BackupRoot
        Status = $Transaction.Status
        UpdatedAt = $Transaction.UpdatedAt
        TransactionSha256 = $transactionHash
    }
    Write-JsonAtomic -Path $script:TransactionMirrorPath -Object $mirror
    Write-RecoveryPackageManifest $Transaction
    $script:CurrentTransaction = $Transaction
}

function Complete-Transaction {
    if ($null -eq $script:CurrentTransaction) { return }
    $script:CurrentTransaction.Status = 'Complete'
    $script:CurrentTransaction.CurrentStep = 'Complete'
    Save-Transaction $script:CurrentTransaction
    if (Test-Path $script:TransactionMirrorPath) { Remove-Item $script:TransactionMirrorPath -Force }
}

function New-RepairTransaction {
    param([object]$State)
    $normalStart = ($State.IsAsus -and $State.IsUEFI -and $State.SetupMode -eq 1 -and $State.NoKeys -and $State.DefaultsAllReadable)
    if (-not $normalStart -and -not $script:DeveloperForceActive) {
        throw '当前状态不满足创建修复进度的条件。'
    }
    if (-not $State.DefaultsAllReadable) {
        throw (L '无法读取四个 Default Keys，固件没有提供可用于写入的源数据。' 'All four Default Keys could not be read. The firmware did not provide source data for the write.')
    }
    $transactionId = [Guid]::NewGuid().ToString('N')
    $transactionRoot = Join-Path $script:BackupRoot (Join-Path 'Transactions' $transactionId)
    $keyRoot = Join-Path $transactionRoot 'KeyBackups'
    $evidenceRoot = Join-Path $transactionRoot 'Evidence'
    New-Item -ItemType Directory -Path $keyRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null
    Assert-NoReparsePoint -Path $script:BackupRoot
    Assert-NoReparsePoint -Path $transactionRoot
    Assert-NoReparsePoint -Path $keyRoot
    Assert-NoReparsePoint -Path $evidenceRoot

    $expected = [ordered]@{}
    foreach ($name in @('PKDefault','KEKDefault','dbDefault','dbxDefault')) {
        $variable = $State.Variables[$name]
        $path = Join-Path $keyRoot "$name.bin"
        [IO.File]::WriteAllBytes($path, [byte[]]$variable.Bytes)
        $backupBytes = [IO.File]::ReadAllBytes($path)
        if (-not (Test-ByteArrayEqual -A ([byte[]]$variable.Bytes) -B $backupBytes)) { throw "$name 备份文件逐字节回读失败。" }
        if ((Get-ByteHashHex -Bytes $backupBytes -Algorithm SHA256) -ne $variable.Sha256) { throw "$name 备份SHA-256与固件回读不一致。" }
        $expectedName = switch ($name) {
            'PKDefault' { 'PkDefault' }
            'KEKDefault' { 'KekDefault' }
            'dbDefault' { 'DbDefault' }
            'dbxDefault' { 'DbxDefault' }
        }
        $expected[$expectedName] = Get-FileHashHex -Path $path -Algorithm SHA256
    }
    $expected.DbWith2023 = ''
    $transactionPath = Join-Path $transactionRoot 'transaction.json'
    $transaction = [ordered]@{
        SchemaVersion = 2
        TransactionId = $transactionId
        Status = 'Active'
        CurrentStep = 'BackupsCreated'
        PendingOperation = ''
        CreatedAt = (Get-Date).ToString('o')
        UpdatedAt = (Get-Date).ToString('o')
        BackupRoot = $script:BackupRoot
        TransactionRoot = $transactionRoot
        TransactionPath = $transactionPath
        KeyBackupRoot = $keyRoot
        EvidenceRoot = $evidenceRoot
        Device = [ordered]@{
            Manufacturer = $State.Manufacturer
            Model = $State.Model
            BaseBoard = $State.BaseBoard
            BaseBoardManufacturer = $State.BaseBoardManufacturer
            BIOSVersion = $State.BIOSVersion
        }
        DefaultLengths = [ordered]@{
            PkDefault = $State.Variables.PKDefault.Length
            KekDefault = $State.Variables.KEKDefault.Length
            DbDefault = $State.Variables.dbDefault.Length
            DbxDefault = $State.Variables.dbxDefault.Length
        }
        ExpectedHashes = $expected
        Certificate = [ordered]@{
            Validated = $false
            EvidencePath = ''
            SHA256 = ''
            MD5 = ''
            Thumbprint = ''
            FormattedLength = 0
        }
        Steps = [ordered]@{
            Backup = 'Complete'
            DbDefault = 'NotStarted'
            Db2023 = 'NotStarted'
            DbxDefault = 'NotStarted'
            KekDefault = 'NotStarted'
            PkDefault = 'NotStarted'
            Reboot = 'NotStarted'
            OfficialRotation = 'NotStarted'
        }
        LastError = ''
        LastWriteIntent = $null
        LastVerifiedAt = ''
        PkWrittenAt = ''
        BootTimeAtPk = ''
        Origin = if ($script:DeveloperForceActive) { 'DeveloperOverride' } else { 'NormalRepair' }
        SourceDescription = ''
        AdvancedRecoveryAcknowledgedAt = ''
        DeveloperOverrideAcknowledgedAt = if ($script:DeveloperForceActive) { (Get-Date).ToString('o') } else { '' }
    }
    Save-Transaction $transaction
    Write-UiLog ((L '已创建进度记录 {0}，并备份四个 BIOS 默认 Keys。目录：{1}' 'Progress record {0} was created and all four BIOS factory Keys were backed up. Folder: {1}') -f $transactionId,$transactionRoot) 'SUCCESS'
    [Windows.Forms.MessageBox]::Show(((L '已创建修复进度和四个 Default Keys 备份。保存位置：' 'The repair progress and four Default Keys backups were created at: ') + [Environment]::NewLine + $transactionRoot), $script:AppName, 'OK', 'Information') | Out-Null
    return $transaction
}

function Set-TransactionPending {
    param([string]$Step)
    $state = Get-SystemState
    $script:CurrentTransaction.PendingOperation = $Step
    $script:CurrentTransaction.CurrentStep = $Step
    $script:CurrentTransaction.Steps[$Step] = 'Pending'
    $script:CurrentTransaction.LastWriteIntent = [ordered]@{
        Step = $Step
        CreatedAt = (Get-Date).ToString('o')
        SetupMode = $state.SetupMode
        SecureBoot = $state.ConfirmSecureBoot
        PK = $state.Variables.PK.Sha256
        KEK = $state.Variables.KEK.Sha256
        db = $state.Variables.db.Sha256
        dbx = $state.Variables.dbx.Sha256
    }
    Save-Transaction $script:CurrentTransaction
}

function Set-TransactionStepComplete {
    param([string]$Step)
    $script:CurrentTransaction.PendingOperation = ''
    $script:CurrentTransaction.CurrentStep = $Step
    $script:CurrentTransaction.Steps[$Step] = 'Complete'
    $script:CurrentTransaction.LastVerifiedAt = (Get-Date).ToString('o')
    if ($Step -eq 'PkDefault') {
        $script:CurrentTransaction.PkWrittenAt = (Get-Date).ToString('o')
        $bootTime = Get-SystemBootTime
        $script:CurrentTransaction.BootTimeAtPk = if ($null -ne $bootTime) { $bootTime.ToString('o') } else { '' }
    }
    Save-Transaction $script:CurrentTransaction
}

function Set-TransactionFailure {
    param([string]$Step, [string]$Message)
    if ($null -ne $script:CurrentTransaction) {
        $script:CurrentTransaction.Status = 'Locked'
        $script:CurrentTransaction.PendingOperation = ''
        $script:CurrentTransaction.CurrentStep = $Step
        $script:CurrentTransaction.Steps[$Step] = 'Failed'
        $script:CurrentTransaction.LastError = $Message
        Save-Transaction $script:CurrentTransaction
    }
}

function Confirm-DangerousAction {
    param([string]$Title, [string]$Message)
    return (Show-ConfirmationWarning -Title $Title -Message $Message)
}

function Assert-WritePreconditions {
    param([object]$State, [string]$Operation)
    if ($script:DeveloperForceActive) {
        Write-UiLog ((L '开发者强制模式：跳过 {0} 的流程限制。' 'Developer force mode: flow restrictions for {0} are bypassed.') -f $Operation) 'WARN'
        return
    }
    if (-not $State.IsAsus) { throw "$Operation：非ASUS/ROG设备，禁止写入。" }
    if (-not $State.IsUEFI) { throw "$Operation：当前不是UEFI启动，禁止写入。" }
    if (-not $State.ActiveVariablesReadable -or -not $State.DefaultVariablesReadable -or -not $State.Variables.SetupMode.ReadSucceeded -or -not $State.Variables.SecureBoot.ReadSucceeded) { throw "$Operation：固件变量读取不完整，禁止写入。" }
    if (-not $State.Power.IsSafeForWrite) { throw "$Operation：交流电源/电池条件不安全。" }
    if ((-not $State.BitLocker.IsKnown -or -not $State.BitLocker.IsFullyDecrypted)) { throw "$Operation：未检测到系统盘已完全解密。" }
    if ((Test-PendingWindowsReboot) -and -not $script:PendingRebootOverride) { throw "$Operation：Windows存在待处理重启。请先重启，或在主界面确认强制继续。" }
}

function Invoke-WriteDbDefault {
    $state = Get-SystemState
    Assert-WritePreconditions -State $state -Operation 'dbDefault写入'
    if (-not $script:DeveloperForceActive -and ($state.SetupMode -ne 1 -or -not $state.NoKeys -or -not $state.DefaultsAllReadable)) { throw 'dbDefault写入前状态不符合要求。' }
    if ($null -eq $script:CurrentTransaction) { $script:CurrentTransaction = New-RepairTransaction $state }
    if (-not (Confirm-DangerousAction (L '写入活动db' 'Write active db') (L '即将把固件dbDefault写入活动db。该操作会修改UEFI NVRAM。确认继续吗？' 'The firmware dbDefault will be written to the active db. This modifies UEFI NVRAM. Continue?'))) { return }
    Set-TransactionPending 'DbDefault'
    try {
        $default = Get-SecureBootUEFI -Name dbDefault -ErrorAction Stop
        $defaultHash = Get-ByteHashHex -Bytes ([byte[]]$default.Bytes) -Algorithm SHA256
        if ($defaultHash -ne $script:CurrentTransaction.ExpectedHashes.DbDefault) { throw '当前 dbDefault 与上次备份哈希不一致，禁止写入。' }
        $time = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        Set-SecureBootUEFI -Name db -Content ([byte[]]$default.Bytes) -Time $time -ErrorAction Stop | Out-Null
        $active = Get-UefiVariableInfo db
        if (-not $active.Exists -or $active.Sha256 -ne $script:CurrentTransaction.ExpectedHashes.DbDefault -or $active.Length -ne $script:CurrentTransaction.DefaultLengths.DbDefault) {
            throw 'db回读长度或SHA-256与dbDefault不一致。'
        }
        Set-TransactionStepComplete 'DbDefault'
        Write-UiLog (L 'dbDefault → db完成，长度与SHA-256回读一致。' 'dbDefault -> db completed. Read-back length and SHA-256 match.') 'SUCCESS'
    } catch {
        Set-TransactionFailure 'DbDefault' $_.Exception.Message
        throw
    }
}

function Invoke-ValidateAndStoreCertificate {
    param([string]$Path)
    $validation = Validate-CertificateFile $Path
    if (-not $validation.IsValid) { throw ('证书校验失败：' + ($validation.Errors -join '，')) }
    $script:SelectedCertificatePath = $Path
    if ($null -ne $script:CurrentTransaction) {
        $evidence = Join-Path $script:CurrentTransaction.EvidenceRoot $script:OfficialCertificateFileName
        Copy-Item -LiteralPath $Path -Destination $evidence -Force
        $script:CurrentTransaction.Certificate.Validated = $true
        $script:CurrentTransaction.Certificate.EvidencePath = $evidence
        $script:CurrentTransaction.Certificate.SHA256 = $validation.SHA256
        $script:CurrentTransaction.Certificate.MD5 = $validation.MD5
        $script:CurrentTransaction.Certificate.Thumbprint = $validation.CertificateThumbprint
        Save-Transaction $script:CurrentTransaction
    }
    Write-UiLog ((L '证书校验通过。SHA-256={0}。MD5={1}（现场计算，仅供识别）' 'Certificate validation passed. SHA-256={0}. MD5={1} (calculated at runtime for identification only)') -f $validation.SHA256, $validation.MD5) 'SUCCESS'
    return $validation
}

function Get-ValidatedCertificatePath {
    if ($script:SelectedCertificatePath -and (Test-Path $script:SelectedCertificatePath)) {
        $result = Validate-CertificateFile $script:SelectedCertificatePath
        if ($result.IsValid) { return $script:SelectedCertificatePath }
    }
    if ($null -ne $script:CurrentTransaction -and $script:CurrentTransaction.Certificate.EvidencePath -and (Test-Path $script:CurrentTransaction.Certificate.EvidencePath)) {
        $result = Validate-CertificateFile $script:CurrentTransaction.Certificate.EvidencePath
        if ($result.IsValid) { return $script:CurrentTransaction.Certificate.EvidencePath }
    }
    return $null
}

function Invoke-Append2023Certificate {
    $state = Get-SystemState
    if ($null -eq $script:CurrentTransaction) { throw '缺少修复进度。' }
    Assert-WritePreconditions -State $state -Operation '追加2023证书'
    if (-not $state.Variables.db.Exists) { throw '活动db不存在，无法追加证书。' }
    if (-not $script:DeveloperForceActive -and ($state.SetupMode -ne 1 -or $state.Variables.dbx.Exists -or $state.Variables.KEK.Exists -or $state.Variables.PK.Exists)) { throw '追加证书前的活动变量组合不正确。' }
    if ($state.Variables.db.Sha256 -ne $script:CurrentTransaction.ExpectedHashes.DbDefault) {
        if ($script:CurrentTransaction.ExpectedHashes.DbWith2023 -and $state.Variables.db.Sha256 -eq $script:CurrentTransaction.ExpectedHashes.DbWith2023) {
            throw '2023证书已经追加，禁止重复追加。'
        }
        throw '当前db不是已验证的dbDefault。'
    }
    $certPath = Get-ValidatedCertificatePath
    if (-not $certPath) { throw '尚未选择并校验微软官方Windows UEFI CA 2023证书。' }
    Invoke-ValidateAndStoreCertificate -Path $certPath | Out-Null
    $certPath = Get-ValidatedCertificatePath

    # Eliminate the validation-to-use race: copy the certificate bytes into the
    # Administrators/SYSTEM-only ProgramData directory, then validate that protected
    # copy again and pass only the protected path to Format-SecureBootUEFI.
    if (-not (Test-Path -LiteralPath $script:ProtectedEvidenceRoot)) {
        New-Item -ItemType Directory -Path $script:ProtectedEvidenceRoot -Force -ErrorAction Stop | Out-Null
    }
    Protect-AppDataDirectory -Path $script:AppDataRoot
    Assert-NoReparsePoint -Path $script:ProtectedEvidenceRoot
    $protectedCertPath = Join-Path $script:ProtectedEvidenceRoot ($script:CurrentTransaction.TransactionId + '-WindowsUEFICA2023.cer')
    $sourceCertBytes = [IO.File]::ReadAllBytes($certPath)
    [IO.File]::WriteAllBytes($protectedCertPath, $sourceCertBytes)
    Protect-AppDataDirectory -Path $script:AppDataRoot
    $protectedValidation = Validate-CertificateFile $protectedCertPath
    if (-not $protectedValidation.IsValid) {
        Remove-Item -LiteralPath $protectedCertPath -Force -ErrorAction SilentlyContinue
        throw ('证书副本校验失败：' + ($protectedValidation.Errors -join '，'))
    }
    $certPath = $protectedCertPath
    $certBytesBefore = [IO.File]::ReadAllBytes($certPath)
    $currentDbBytes = [byte[]]$state.Variables.db.Bytes
    $currentNameFound = [Text.Encoding]::ASCII.GetString($currentDbBytes) -match 'Windows UEFI CA 2023'
    $currentDerFound = Test-ContainsByteSequence -Container $currentDbBytes -Sequence $certBytesBefore
    if ($currentDerFound) {
        $script:CurrentTransaction.ExpectedHashes.DbWith2023 = $state.Variables.db.Sha256
        $script:CurrentTransaction.Certificate.FormattedLength = 0
        Save-Transaction $script:CurrentTransaction
        Set-TransactionStepComplete 'Db2023'
        Write-UiLog (L 'dbDefault已经包含经完整DER确认的Windows UEFI CA 2023，已跳过重复追加。' 'dbDefault already contains the exact Windows UEFI CA 2023 DER certificate. Duplicate append was skipped.') 'SUCCESS'
        return
    }
    if ($currentNameFound -and -not $currentDerFound) {
        throw '当前db出现Windows UEFI CA 2023名称，但未找到官方证书完整DER字节。为避免误判，禁止追加。'
    }
    if (-not (Confirm-DangerousAction (L '追加2023证书' 'Append the 2023 certificate') (L '即将把Windows UEFI CA 2023以EFI Signature List格式追加到活动db。确认继续吗？' 'Windows UEFI CA 2023 will be appended to the active db as an EFI Signature List. Continue?'))) { return }
    Set-TransactionPending 'Db2023'
    try {
        $time = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        $formatted = Format-SecureBootUEFI -Name db -SignatureOwner $script:OfficialCertificateSignatureOwner -CertificateFilePath $certPath -FormatWithCert -AppendWrite -Time $time -ErrorAction Stop
        $backupDbPath = Join-Path $script:CurrentTransaction.KeyBackupRoot 'dbDefault.bin'
        $backupDbBytes = [IO.File]::ReadAllBytes($backupDbPath)
        $backupDbHash = Get-ByteHashHex -Bytes $backupDbBytes -Algorithm SHA256
        if ($backupDbHash -ne $script:CurrentTransaction.ExpectedHashes.DbDefault) { throw (L 'dbDefault备份文件哈希已变化，禁止继续。' 'The dbDefault backup hash has changed. The operation is blocked.') }
        if (-not (Test-ByteArrayEqual -A $backupDbBytes -B $currentDbBytes)) { throw (L 'dbDefault备份与当前已验证活动db不一致，禁止继续。' 'The dbDefault backup does not match the currently verified active db. The operation is blocked.') }
        $appendBytes = [byte[]]$formatted.Content
        $expectedBytes = Join-ByteArrays $currentDbBytes $appendBytes
        $expectedHash = Get-ByteHashHex -Bytes $expectedBytes -Algorithm SHA256
        $script:CurrentTransaction.ExpectedHashes.DbWith2023 = $expectedHash
        $script:CurrentTransaction.Certificate.FormattedLength = $appendBytes.Length
        Save-Transaction $script:CurrentTransaction
        $formatted | Set-SecureBootUEFI -ErrorAction Stop | Out-Null
        $active = Get-UefiVariableInfo db
        $certBytes = [IO.File]::ReadAllBytes($certPath)
        $nameFound = [Text.Encoding]::ASCII.GetString($active.Bytes) -match 'Windows UEFI CA 2023'
        if ($active.Length -ne $expectedBytes.Length) { throw '追加后db字节数与理论值不一致。' }
        if ($active.Sha256 -ne $expectedHash) { throw '追加后db SHA-256与理论值不一致。' }
        if (-not (Test-ByteArrayEqual $active.Bytes $expectedBytes)) { throw '追加后db逐字节比较失败。' }
        if (-not (Test-ContainsByteSequence $active.Bytes $certBytes)) { throw '活动db中未找到完整证书DER字节。' }
        if (-not $nameFound) { throw '活动db中未找到Windows UEFI CA 2023名称。' }
        Set-TransactionStepComplete 'Db2023'
        Write-UiLog (L 'Windows UEFI CA 2023已追加，长度、SHA-256、逐字节、DER内容和名称五项验证通过。' 'Windows UEFI CA 2023 was appended. Length, SHA-256, byte-for-byte, DER-content, and name checks all passed.') 'SUCCESS'
    } catch {
        Set-TransactionFailure 'Db2023' $_.Exception.Message
        throw
    }
}

function Invoke-RestoreDefaultVariable {
    param(
        [ValidateSet('dbx','KEK','PK')][string]$TargetName,
        [ValidateSet('dbxDefault','KEKDefault','PKDefault')][string]$DefaultName,
        [ValidateSet('DbxDefault','KekDefault','PkDefault')][string]$StepName,
        [ValidateSet('DbxDefault','KekDefault','PkDefault')][string]$ExpectedHashName
    )
    if ($null -eq $script:CurrentTransaction) { throw '缺少修复进度。' }
    $state = Get-SystemState
    Assert-WritePreconditions -State $state -Operation "$TargetName 写入"
    if (-not $script:DeveloperForceActive -and $state.SetupMode -ne 1) { throw "$TargetName 写入前SetupMode不为1。" }
    if ($TargetName -eq 'dbx') {
        if (-not $state.Variables.db.Exists -or $state.Variables.db.Sha256 -ne $script:CurrentTransaction.ExpectedHashes.DbWith2023) { throw 'dbx写入前db状态不正确。' }
        if (-not $script:DeveloperForceActive -and ($state.Variables.dbx.Exists -or $state.Variables.KEK.Exists -or $state.Variables.PK.Exists)) { throw 'dbx写入前状态不正确。' }
    }
    if ($TargetName -eq 'KEK') {
        if (-not $state.Variables.db.Exists -or -not $state.Variables.dbx.Exists) { throw 'KEK写入前缺少db或dbx。' }
        if (-not $script:DeveloperForceActive -and ($state.Variables.KEK.Exists -or $state.Variables.PK.Exists)) { throw 'KEK写入前状态不正确。' }
        if ($state.Variables.db.Sha256 -ne $script:CurrentTransaction.ExpectedHashes.DbWith2023 -or $state.Variables.dbx.Sha256 -ne $script:CurrentTransaction.ExpectedHashes.DbxDefault) { throw 'db或dbx哈希不正确。' }
    }
    if ($TargetName -eq 'PK') {
        if (-not $state.Variables.db.Exists -or -not $state.Variables.dbx.Exists -or -not $state.Variables.KEK.Exists) { throw 'PK写入前缺少db、dbx或KEK。' }
        if (-not $script:DeveloperForceActive -and $state.Variables.PK.Exists) { throw 'PK写入前状态不正确。' }
        if ($state.Variables.db.Sha256 -ne $script:CurrentTransaction.ExpectedHashes.DbWith2023 -or $state.Variables.dbx.Sha256 -ne $script:CurrentTransaction.ExpectedHashes.DbxDefault -or $state.Variables.KEK.Sha256 -ne $script:CurrentTransaction.ExpectedHashes.KekDefault) { throw 'PK写入前的db/dbx/KEK哈希不正确。' }
    }
    if (-not (Confirm-DangerousAction ((L '写入{0}' 'Write {0}') -f $TargetName) ((L '即将把{0}写入活动{1}。该操作会修改UEFI NVRAM。确认继续吗？' '{0} will be written to active {1}. This modifies UEFI NVRAM. Continue?') -f $DefaultName, $TargetName))) { return }
    Set-TransactionPending $StepName
    try {
        $default = Get-SecureBootUEFI -Name $DefaultName -ErrorAction Stop
        $expectedHash = $script:CurrentTransaction.ExpectedHashes[$ExpectedHashName]
        $defaultHash = Get-ByteHashHex -Bytes ([byte[]]$default.Bytes) -Algorithm SHA256
        if ($defaultHash -ne $expectedHash) { throw "当前$DefaultName与上次备份哈希不一致，禁止写入。" }
        $time = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        Set-SecureBootUEFI -Name $TargetName -Content ([byte[]]$default.Bytes) -Time $time -ErrorAction Stop | Out-Null
        $active = Get-UefiVariableInfo $TargetName
        if (-not $active.Exists -or $active.Sha256 -ne $expectedHash -or $active.Length -ne ([byte[]]$default.Bytes).Length) { throw "$TargetName 回读长度或SHA-256不一致。" }
        $dbAfter = Get-UefiVariableInfo db
        if ($dbAfter.Sha256 -ne $script:CurrentTransaction.ExpectedHashes.DbWith2023) { throw "$TargetName 写入后db发生变化。" }
        if ($TargetName -in @('KEK','PK')) {
            $dbxAfter = Get-UefiVariableInfo dbx
            if ($dbxAfter.Sha256 -ne $script:CurrentTransaction.ExpectedHashes.DbxDefault) { throw "$TargetName 写入后dbx发生变化。" }
        }
        if ($TargetName -eq 'PK') {
            $kekAfter = Get-UefiVariableInfo KEK
            if ($kekAfter.Sha256 -ne $script:CurrentTransaction.ExpectedHashes.KekDefault) { throw 'PK写入后KEK发生变化。' }
            $setupAfter = Get-UefiVariableInfo SetupMode
            if (-not $setupAfter.Exists -or $setupAfter.Bytes[0] -ne 0) { throw 'PK写入后SetupMode未变为0。' }
        }
        Set-TransactionStepComplete $StepName
        Write-UiLog ((L '{0} → {1} 完成，回读长度与SHA-256一致，前序变量未变化。' '{0} -> {1} completed. Read-back length and SHA-256 match, and earlier variables are unchanged.') -f $DefaultName, $TargetName) 'SUCCESS'
    } catch {
        Set-TransactionFailure $StepName $_.Exception.Message
        throw
    }
}

function Assert-OfficialRotationPreconditions {
    param([object]$State)
    if ($script:DeveloperForceActive) {
        Write-UiLog (L '开发者强制模式：跳过官方轮换入口限制。' 'Developer force mode: the official-rotation entry restriction is bypassed.') 'WARN'
        return
    }
    if (-not $State.IsAsus) { throw '本版本仅允许在ASUS/ROG设备上运行官方轮换入口。' }
    if (-not $State.IsUEFI -or -not $State.ConfirmSecureBoot -or $State.SetupMode -ne 0) { throw '运行官方轮换前必须处于UEFI、Secure Boot=True且SetupMode=0。' }
    if (-not $State.ScheduledTask.Exists) { throw '缺少微软Secure-Boot-Update计划任务。' }
    if (-not $State.Power.IsSafeForWrite) { throw '运行官方轮换前必须连接交流电源，且笔记本电量至少30%。' }
    $bitLockerReason = Get-BitLockerBlockReason -BitLocker $State.BitLocker
    if (-not [string]::IsNullOrWhiteSpace($bitLockerReason)) { throw $bitLockerReason }
    if ((Test-PendingWindowsReboot) -and -not $script:PendingRebootOverride) { throw 'Windows存在待处理重启。请先重启，或在主界面确认强制继续。' }
}

function Invoke-OfficialRotation {
    $state = Get-SystemState
    Assert-OfficialRotationPreconditions -State $state
    if ($state.Servicing.UEFICA2023Status -eq 'Updated' -and $state.RotationVerification.IsComplete) {
        Write-UiLog (L '微软官方轮换已经完成，无需重复运行。' 'The Microsoft official rotation is complete. No action is needed.') 'SUCCESS'
        return
    }
    if (-not (Confirm-DangerousAction (L '运行微软官方轮换' 'Run Microsoft official rotation') (L '即将运行 Windows 官方 Secure Boot 更新任务。过程中可能需要重启。确定继续？' 'Run the official Windows Secure Boot update task. A restart may be required. Continue?'))) { return }
    $start = Get-Date
    if ($null -ne $script:CurrentTransaction) { Set-TransactionPending 'OfficialRotation' }
    try {
        $root = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
        $currentAvailable = [uint32]$state.Servicing.AvailableUpdates
        $status = [string]$state.Servicing.UEFICA2023Status
        if ($status -in @('NotSet','NotStarted','') -and ($currentAvailable -eq 0 -or $currentAvailable -eq $script:AvailableUpdatesComplete)) {
            New-ItemProperty -Path $root -Name AvailableUpdates -PropertyType DWord -Value $script:AvailableUpdatesAll -Force | Out-Null
            Write-UiLog (L 'AvailableUpdates已设置为0x5944。' 'AvailableUpdates was set to 0x5944.') 'INFO'
        } else {
            Write-UiLog ((L '检测到官方轮换已存在进度：Status={0}，AvailableUpdates={1}。未覆盖现有位。' 'Existing official rotation progress detected: Status={0}, AvailableUpdates={1}. Existing bits were not overwritten.') -f $status, $state.Servicing.AvailableUpdatesHex) 'INFO'
        }
        Start-ScheduledTask -TaskPath '\Microsoft\Windows\PI\' -TaskName 'Secure-Boot-Update'
        Write-UiLog (L '微软Secure-Boot-Update任务已启动，等待任务结束并回读状态。' 'The Microsoft Secure-Boot-Update task was started. Waiting for completion and state read-back.') 'INFO'
        $deadline = (Get-Date).AddSeconds(75)
        do {
            Start-Sleep -Seconds 2
            $taskState = Get-ScheduledTaskState
        } while ($taskState.State -eq 'Running' -and (Get-Date) -lt $deadline)

        $after = Get-SystemState
        $newEvents = Get-RecentSecureBootEvents -StartTime $start
        if ($script:SessionLogRoot) { Write-JsonAtomic -Path (Join-Path $script:SessionLogRoot 'official-rotation-events.json') -Object $newEvents -Depth 8 }
        $errorEvent = @($newEvents | Where-Object { $_.Id -in @(1795,1796,1802,1803) } | Select-Object -First 1)
        if ($errorEvent.Count -gt 0) { throw ("官方轮换出现事件{0}：{1}" -f $errorEvent[0].Id, $errorEvent[0].Message) }
        if ($after.Servicing.UEFICA2023Error -and $after.Servicing.UEFICA2023Error -ne '0x00000000') {
            throw ("官方轮换注册表错误：{0}，事件={1}" -f $after.Servicing.UEFICA2023Error, $after.Servicing.UEFICA2023ErrorEvent)
        }
        if ($after.Servicing.UEFICA2023Status -eq 'Updated' -and $after.RotationVerification.IsComplete) {
            if ($null -ne $script:CurrentTransaction) { Set-TransactionStepComplete 'OfficialRotation'; Complete-Transaction }
            Write-UiLog ((L '微软官方轮换完成：UEFICA2023Status=Updated，适用于本机的2023证书/KEK均已确认，AvailableUpdates={0}。' 'Microsoft official rotation completed: UEFICA2023Status=Updated, all applicable 2023 certificates/KEK entries were confirmed, AvailableUpdates={0}.') -f $after.Servicing.AvailableUpdatesHex) 'SUCCESS'
        } else {
            if ($null -ne $script:CurrentTransaction) {
                $script:CurrentTransaction.PendingOperation = ''
                $script:CurrentTransaction.Steps.OfficialRotation = 'NeedsRebootOrRetry'
                $script:CurrentTransaction.CurrentStep = 'OfficialRotation'
                Save-Transaction $script:CurrentTransaction
            }
            Write-UiLog ((L '官方轮换尚未完成：Status={0}，AvailableUpdates={1}，验证={2}。按界面提示重启或重试。' 'Official rotation is not complete: Status={0}, AvailableUpdates={1}, verification={2}. Follow the interface to restart or retry.') -f $after.Servicing.UEFICA2023Status, $after.Servicing.AvailableUpdatesHex, $after.RotationVerification.Message) 'WARN'
        }
    } catch {
        if ($null -ne $script:CurrentTransaction) { Set-TransactionFailure 'OfficialRotation' $_.Exception.Message }
        throw
    }
}

function Register-ResumeTask {
    param([string]$Reason)
    $ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $resumeUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $interactiveComputer = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $interactiveUser = [string](Get-OptionalPropertyValue -Object $interactiveComputer -Name 'UserName' -Default '')
    if (-not [string]::IsNullOrWhiteSpace($interactiveUser) -and -not [string]::Equals($interactiveUser, $resumeUser, [StringComparison]::OrdinalIgnoreCase)) {
        throw (L "当前交互用户($interactiveUser)与UAC管理员身份($resumeUser)不同，无法保证登录后自动续检。请使用管理员账户登录Windows后重新运行。" "The interactive user ($interactiveUser) differs from the elevated identity ($resumeUser). Automatic resume cannot be bound safely. Sign in with an administrator account and run the assistant again.")
    }

    # Never register a highest-privilege task that launches a mutable script from Downloads,
    # Desktop, or another user-writable package folder. Copy this exact runtime into the
    # Administrators/SYSTEM-only ProgramData state directory and verify it byte-for-byte.
    if (-not (Test-Path -LiteralPath $script:ProgramPath)) { throw (L '找不到当前程序文件，无法创建安全续跑任务。' 'The current program file cannot be found; a secure resume task cannot be created.') }
    if (-not (Test-Path -LiteralPath $script:ProtectedRuntimeRoot)) {
        New-Item -ItemType Directory -Path $script:ProtectedRuntimeRoot -Force -ErrorAction Stop | Out-Null
    }
    Protect-AppDataDirectory -Path $script:AppDataRoot
    Assert-NoReparsePoint -Path $script:ProtectedRuntimeRoot

    $sourceHashBefore = Get-FileHashHex -Path $script:ProgramPath -Algorithm SHA256
    Copy-Item -LiteralPath $script:ProgramPath -Destination $script:ProtectedRuntimePath -Force -ErrorAction Stop
    Protect-AppDataDirectory -Path $script:AppDataRoot
    $sourceHashAfter = Get-FileHashHex -Path $script:ProgramPath -Algorithm SHA256
    $runtimeHash = Get-FileHashHex -Path $script:ProtectedRuntimePath -Algorithm SHA256
    if ($sourceHashBefore -ne $sourceHashAfter -or $sourceHashAfter -ne $runtimeHash) {
        Remove-Item -LiteralPath $script:ProtectedRuntimePath -Force -ErrorAction SilentlyContinue
        throw (L '创建受保护续跑副本时程序文件发生变化或校验失败。续跑任务未创建。' 'The program changed or failed integrity verification while the protected resume copy was being created. No resume task was registered.')
    }

    $literalTask = $script:ResumeTaskName.Replace("'", "''")
    $literalProgram = $script:ProtectedRuntimePath.Replace("'", "''")
    $literalReason = $Reason.Replace("'", "''")
    $literalLanguage = $script:Language.Replace("'", "''")
    if ($script:IsCompiledExe) {
        $resumeLaunch = "Start-Process -FilePath '$literalProgram' -ArgumentList @('-end','-Resume','-ResumeReason','$literalReason','-Language','$literalLanguage')"
    } else {
        $literalPowerShell = $ps.Replace("'", "''")
        $resumeLaunch = "Start-Process -FilePath '$literalPowerShell' -ArgumentList @('-NoProfile','-STA','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File','$literalProgram','-Resume','-ResumeReason','$literalReason','-Language','$literalLanguage')"
    }
    $wrapper = @"
`$ErrorActionPreference = 'SilentlyContinue'
Unregister-ScheduledTask -TaskName '$literalTask' -Confirm:`$false -ErrorAction SilentlyContinue
`$ErrorActionPreference = 'Stop'
$resumeLaunch
"@
    [IO.File]::WriteAllText($script:ResumeLauncherPath, $wrapper, (New-Object Text.UTF8Encoding($true)))
    Protect-AppDataDirectory -Path $script:AppDataRoot

    $arguments = "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script:ResumeLauncherPath`""
    $action = New-ScheduledTaskAction -Execute $ps -Argument $arguments
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $resumeUser
    $principal = New-ScheduledTaskPrincipal -UserId $resumeUser -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
    Register-ScheduledTask -TaskName $script:ResumeTaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    $resumeState = [ordered]@{
        Reason = $Reason
        CreatedAt = (Get-Date).ToString('o')
        TransactionId = if ($script:CurrentTransaction) { $script:CurrentTransaction.TransactionId } else { '' }
        Language = $script:Language
        ProtectedRuntimePath = $script:ProtectedRuntimePath
        ProtectedRuntimeSha256 = $runtimeHash
        ExpectedBehavior = L '登录后启动一次，先删除续跑任务，再重新检测。' 'One-time launch after sign-in. Remove the resume task first, then run detection.'
    }
    Write-JsonAtomic -Path (Join-Path $script:AppDataRoot 'resume-state.json') -Object $resumeState
    Protect-AppDataDirectory -Path $script:AppDataRoot
}
function Remove-ResumeTaskSafe {
    try { Unregister-ScheduledTask -TaskName $script:ResumeTaskName -Confirm:$false -ErrorAction SilentlyContinue } catch {}
    $path = Join-Path $script:AppDataRoot 'resume-state.json'
    if (Test-Path $path) { Remove-Item $path -Force -ErrorAction SilentlyContinue }
    if (Test-Path $script:ResumeLauncherPath) { Remove-Item $script:ResumeLauncherPath -Force -ErrorAction SilentlyContinue }
}

function Invoke-RebootWithResume {
    param([ValidateSet('Windows','Firmware')][string]$Destination = 'Windows', [string]$Reason = 'StateCheck')
    if ($Destination -eq 'Firmware' -and -not $script:DeveloperForceActive) {
        $preState = Get-SystemState
        if (-not $preState.Power.IsSafeForWrite) { throw (L '进入BIOS前必须连接交流电源，且笔记本电量至少30%。' 'AC power must be connected and a laptop battery must be at least 30% before entering UEFI setup.') }
        $bitLockerReason = Get-BitLockerBlockReason -BitLocker $preState.BitLocker
        if (-not [string]::IsNullOrWhiteSpace($bitLockerReason)) { throw $bitLockerReason }
        if ((Test-PendingWindowsReboot) -and -not $script:PendingRebootOverride) { throw (L 'Windows存在待处理重启。请先重启，或在主界面确认强制继续。' 'Windows has a pending restart. Restart first, or explicitly enable Force continue in the main window.') }
    }
    if (-not (Confirm-DangerousAction (L '准备重启' 'Prepare to restart') (L '将创建一次性登录任务。重新登录 Windows 后自动打开并重新检测。确定立即重启？' 'Create a one-time sign-in task. After sign-in, reopen and run detection. Restart now?'))) { return }

    Register-ResumeTask -Reason $Reason
    if ($null -ne $script:CurrentTransaction) {
        $script:CurrentTransaction.Steps.Reboot = 'Scheduled'
        $script:CurrentTransaction.CurrentStep = 'Reboot'
        $script:CurrentTransaction.LastError = ''
        Save-Transaction $script:CurrentTransaction
    }
    Export-DiagnosticSnapshot -State (Get-SystemState) -Reason "BeforeReboot-$Destination"
    if ($Destination -eq 'Firmware') {
        & "$env:SystemRoot\System32\shutdown.exe" /r /fw /t 5 /c "ASUS/ROG Secure Boot Assistant: restart into UEFI. Resume detection after Windows sign-in."
    } else {
        & "$env:SystemRoot\System32\shutdown.exe" /r /t 5 /c "ASUS/ROG Secure Boot Assistant: resume detection after restart."
    }
    $shutdownExitCode = $LASTEXITCODE
    if ($shutdownExitCode -ne 0) {
        Remove-ResumeTaskSafe
        if ($null -ne $script:CurrentTransaction) {
            $script:CurrentTransaction.Steps.Reboot = 'Pending'
            $script:CurrentTransaction.CurrentStep = 'Reboot'
            $script:CurrentTransaction.LastError = "shutdown.exe exit code: $shutdownExitCode"
            Save-Transaction $script:CurrentTransaction
        }
        throw ((L 'Windows拒绝了重启请求，已撤销一次性续跑任务。shutdown.exe返回：{0}' 'Windows rejected the restart request. The one-time resume task was removed. shutdown.exe returned: {0}') -f $shutdownExitCode)
    }
}
function Show-BitLockerHandlingInfo {
    $state = Get-SystemState
    $message = L ("当前检测结果：`r`nBitLocker状态可判定：{0}`r`n系统盘已完全解密：{1}`r`n保护状态：{2}`r`n卷状态：{3}`r`n`r`n请先关闭 BitLocker / 设备加密并等待解密完成。`r`n`r`n{4}" -f $state.BitLocker.IsKnown,$state.BitLocker.IsFullyDecrypted,$state.BitLocker.ProtectionStatus,$state.BitLocker.VolumeStatus,(Get-DeveloperModeHint)) ("Current detection:`r`nBitLocker state known: {0}`r`nSystem drive fully decrypted: {1}`r`nProtection status: {2}`r`nVolume status: {3}`r`n`r`nTurn off BitLocker / device encryption and wait for decryption to finish.`r`n`r`n{4}" -f $state.BitLocker.IsKnown,$state.BitLocker.IsFullyDecrypted,$state.BitLocker.ProtectionStatus,$state.BitLocker.VolumeStatus,(Get-DeveloperModeHint))
    [Windows.Forms.MessageBox]::Show($message, (L 'BitLocker/设备加密处理' 'BitLocker/device encryption handling'), 'OK', 'Warning') | Out-Null
    Write-UiLog (L '已显示BitLocker/设备加密处理说明。未执行暂停或解密操作。' 'Displayed BitLocker/device encryption guidance. No suspend or decrypt operation was performed.') 'WARN'
}
function Invoke-SafeUiAction {
    param([scriptblock]$Action, [string]$Name)
    try {
        & $Action
        Refresh-MainUi -Reason $Name
    } catch {
        $errorId = 'ERR-' + (Get-Date -Format 'yyyyMMddHHmmss') + '-' + ([Guid]::NewGuid().ToString('N').Substring(0,6).ToUpperInvariant())
        $message = $_.Exception.Message
        $userMessage = if ($script:Language -eq 'en-US') {
            "The operation was stopped by a safety or integrity check. No further write was attempted. Export the diagnostic package and reference error ID $errorId."
        } else {
            $message
        }
        Write-UiLog ((L '{0}失败 [{1}]：{2}' '{0} failed [{1}]: {2}') -f $Name, $errorId, $userMessage) 'ERROR'
        try {
            if ($script:SessionLogRoot) {
                $detail = [ordered]@{
                    ErrorId = $errorId
                    Time = (Get-Date).ToString('o')
                    Operation = $Name
                    ExceptionType = $_.Exception.GetType().FullName
                    Message = $message
                    FullyQualifiedErrorId = $_.FullyQualifiedErrorId
                    Category = [string]$_.CategoryInfo
                    ScriptStackTrace = $_.ScriptStackTrace
                    Invocation = [string]$_.InvocationInfo.PositionMessage
                }
                $line = $detail | ConvertTo-Json -Depth 6 -Compress
                Add-Content -LiteralPath (Join-Path $script:SessionLogRoot 'errors.jsonl') -Value $line -Encoding UTF8
            }
            $state = Get-SystemState
            Export-DiagnosticSnapshot -State $state -Reason "Failure-$Name-$errorId"
        } catch {}
        $developerHint = if ($script:DeveloperModeEnabled) {
            L '强制操作失败。请导出诊断报告并附上错误编号。' 'The forced operation failed. Export the diagnostic report and include the error ID.'
        } else {
            Get-DeveloperModeHint -Enabled:$false
        }
        $dialogText = if ($script:Language -eq 'en-US') {
            "The operation stopped.`r`n`r`nError ID: $errorId`r`n$message`r`n`r`n$developerHint"
        } else {
            "操作已停止。`r`n`r`n错误编号：$errorId`r`n$message`r`n`r`n$developerHint"
        }
        [Windows.Forms.MessageBox]::Show($dialogText, $script:AppName, 'OK', 'Error') | Out-Null
    }
}

function Get-NextRepairOperation {
    param([object]$State)
    if ($State.Classification -eq 'ReadyForRepair') { return 'DbDefault' }
    if ($State.Classification -eq 'RecoverableIntermediate') {
        $operation = switch ($State.TransactionConsistency.RecognizedStage) {
            'DbDefaultWritten' { 'Db2023' }
            'Db2023Written' { 'DbxDefault' }
            'DbxWritten' { 'KekDefault' }
            'KekWritten' { 'PkDefault' }
            default { '' }
        }
        return $operation
    }
    return ''
}

function Show-SecureBootEnableGuidance {
    param([object]$State)
    $message = if ([string]::IsNullOrWhiteSpace([string]$State.SecureBootEnableWarning)) {
        L '当前Keys已存在但Secure Boot未启用。进入BIOS启用Secure Boot时不要清除Keys。' 'The current Keys are present but Secure Boot is disabled. Do not clear the Keys when enabling Secure Boot in BIOS.'
    } else {
        [string]$State.SecureBootEnableWarning
    }
    $message = $message + [Environment]::NewLine + [Environment]::NewLine + (L '确认后将重启进入 BIOS/UEFI 设置。继续吗？' 'The PC will restart into BIOS/UEFI settings. Continue?')
    if (Show-ConfirmationWarning -Title (L '启用 Secure Boot' 'Enable Secure Boot') -Message $message) {
        Invoke-RebootWithResume -Destination Firmware -Reason 'EnableSecureBootInBIOS'
    }
}


function Show-BootChainRepairDialog {
    param([object]$State)
    $suspicious = if ([string]::IsNullOrWhiteSpace([string]$State.BootChain.SuspiciousFirmwareEntries)) { L '无' 'None' } else { [string]$State.BootChain.SuspiciousFirmwareEntries }
    $messageZh = @'
检测结果：{0}

Windows Boot Manager 首启动：{1}
路径：{2}
可疑启动项：{3}

修复内容：Windows Boot Manager 启动顺序和标准路径。Secure Boot Keys 不变，Secure Boot 不启用。

修复后请重新检测。继续吗？
'@
    $messageEn = @'
Result: {0}

Windows Boot Manager first: {1}
Path: {2}
Suspicious boot entries: {3}

Repair scope: Windows Boot Manager order and standard path. Secure Boot Keys remain unchanged and Secure Boot is not enabled.

Detect again after the repair. Continue?
'@
    $message = (L $messageZh $messageEn) -f $State.BootChain.Message,$State.BootChain.WindowsBootManagerFirst,$State.BootChain.WindowsBootManagerPath,$suspicious
    if (-not (Show-ConfirmationWarning -Title (L '修复 Windows Boot Manager' 'Repair Windows Boot Manager') -Message $message)) { return }
    Repair-WindowsBootManagerOrder
    Write-UiLog (L 'Windows Boot Manager 已修复。请重新检测后再启用 Secure Boot。' 'Windows Boot Manager was repaired. Detect again before enabling Secure Boot.') 'SUCCESS'
}

function Show-BootChainManualReviewDialog {
    param([object]$State)
    $messageZh = @'
启动链检查未通过：
{0}

请这样处理：
{1}

处理完成后重启，回到 Windows 点「重新检测」。检测通过后再启用 Secure Boot。不要清 Keys，也不要使用 Restore Factory Keys。

{2}
'@
    $messageEn = @'
The boot-chain check did not pass:
{0}

How to fix:
{1}

Restart after fixing the issue, return to Windows, and select Detect again. Enable Secure Boot after the check passes. Do not clear Keys or use Restore Factory Keys.

{2}
'@
    $message = (L $messageZh $messageEn) -f $State.BootChain.Message,$State.BootChain.ManualActionMessage,(Get-DeveloperModeHint)
    [Windows.Forms.MessageBox]::Show($message, (L '启动链需要处理' 'Boot chain needs attention'), 'OK', 'Warning') | Out-Null
}

function New-DeveloperRepairTransaction {
    param([Parameter(Mandatory)][object]$State)
    $script:CurrentTransaction = New-RepairTransaction -State $State
    $script:CurrentTransaction.Origin = 'DeveloperOverride'
    $script:CurrentTransaction.SourceDescription = 'Developer force workflow'
    $script:CurrentTransaction.DeveloperOverrideAcknowledgedAt = (Get-Date).ToString('o')
    Save-Transaction $script:CurrentTransaction
    return $script:CurrentTransaction
}

function Get-DeveloperForceRepairOperation {
    if ($null -eq $script:CurrentTransaction) { return 'DbDefault' }
    $steps = $script:CurrentTransaction.Steps
    if ([string]$steps.DbDefault -ne 'Complete') { return 'DbDefault' }
    if ([string]$steps.Db2023 -ne 'Complete') { return 'Db2023' }
    if ([string]$steps.DbxDefault -ne 'Complete') { return 'DbxDefault' }
    if ([string]$steps.KekDefault -ne 'Complete') { return 'KekDefault' }
    if ([string]$steps.PkDefault -ne 'Complete') { return 'PkDefault' }
    return 'PostWrite'
}

function Confirm-DeveloperForceAction {
    param([Parameter(Mandatory)][object]$State)
    $reason = if (-not [string]::IsNullOrWhiteSpace([string]$State.ActionBlockReason)) { [string]$State.ActionBlockReason } elseif (-not [string]::IsNullOrWhiteSpace([string]$State.BlockReason)) { [string]$State.BlockReason } else { [string]$State.NextStep }
    $reason = (($reason -replace '\s+', ' ').Trim())
    if ($reason.Length -gt 220) { $reason = $reason.Substring(0,220) + '…' }
    $messageZh = @"
当前限制：$reason

强制继续将直接执行当前步骤。请先备份重要文件，并准备好 BitLocker 恢复密钥。

风险：Windows 可能无法启动，现有 Keys 可能被覆盖，也可能进入 BitLocker 恢复或需要手动恢复 BIOS。

风险由你自行承担。因本次强制操作造成的数据丢失、无法启动或设备故障，我们不承担责任。

确定继续？
"@
    $messageEn = @"
Current block: $reason

Force continue runs the current step. Back up important files and keep the BitLocker recovery key ready.

Risk: Windows may become unbootable, existing Keys may be replaced, BitLocker recovery may start, or manual BIOS recovery may be required.

Do at your own risk. We are not responsible for data loss, boot failure, or device damage caused by this forced operation.

Continue?
"@
    return (Show-ConfirmationWarning -Title (L '开发者强制继续' 'Developer force continue') -Message (L $messageZh $messageEn))
}

function Invoke-DeveloperForceAction {
    if (-not $script:DeveloperModeEnabled) {
        [Windows.Forms.MessageBox]::Show((Get-DeveloperModeHint -Enabled:$false), $script:AppName, 'OK', 'Warning') | Out-Null
        return
    }
    $state = Get-SystemState
    if (-not (Confirm-DeveloperForceAction -State $state)) { return }

    $script:DeveloperForceActive = $true
    try {
        if ($state.PendingReboot.IsPending) {
            $script:PendingRebootOverride = $true
            $script:PendingRebootOverrideAcknowledgedAt = Get-Date
        }

        if ($state.Classification -in @('PkWrittenPendingReboot','OfficialRotationNeedsReboot')) {
            Invoke-RebootWithResume -Destination Windows -Reason 'DeveloperForceRestart'
            return
        }
        if ($state.AllKeys -and $state.SetupMode -eq 0 -and -not $state.ConfirmSecureBoot) {
            Show-SecureBootEnableGuidance -State $state
            return
        }
        if ($state.AllKeys -and $state.ConfirmSecureBoot -and ($state.Servicing.UEFICA2023Status -ne 'Updated' -or -not $state.RotationVerification.IsComplete)) {
            Invoke-OfficialRotation
            return
        }
        if ($state.Classification -eq 'Completed') {
            [Windows.Forms.MessageBox]::Show((L '当前状态已经完成，无需强制写入。' 'The current state is already complete. No forced write is needed.'), $script:AppName, 'OK', 'Information') | Out-Null
            return
        }

        $developerTransactionMatches = $false
        if ($null -ne $script:CurrentTransaction -and [string]$script:CurrentTransaction.Status -eq 'Active' -and [string](Get-OptionalPropertyValue -Object $script:CurrentTransaction -Name 'Origin' -Default '') -eq 'DeveloperOverride') {
            $developerTransactionMatches = [bool](Test-TransactionIntermediateState -State $state -Transaction $script:CurrentTransaction).IsConsistent
        }
        $needsNewTransaction = (-not $developerTransactionMatches)
        if ($needsNewTransaction) {
            if (-not $state.DefaultsAllReadable) {
                throw (L '无法读取四个 Default Keys。开发者模式不能生成缺失的写入数据。' 'All four Default Keys could not be read. Developer mode cannot create missing write data.')
            }
            New-DeveloperRepairTransaction -State $state | Out-Null
        }

        $operation = Get-DeveloperForceRepairOperation
        switch ($operation) {
            'DbDefault' { Invoke-WriteDbDefault }
            'Db2023' {
                if (-not (Get-ValidatedCertificatePath)) {
                    Show-CertificateInfo
                    if (-not (Get-ValidatedCertificatePath)) { return }
                }
                Invoke-Append2023Certificate
            }
            'DbxDefault' { Invoke-RestoreDefaultVariable -TargetName dbx -DefaultName dbxDefault -StepName DbxDefault -ExpectedHashName DbxDefault }
            'KekDefault' { Invoke-RestoreDefaultVariable -TargetName KEK -DefaultName KEKDefault -StepName KekDefault -ExpectedHashName KekDefault }
            'PkDefault' { Invoke-RestoreDefaultVariable -TargetName PK -DefaultName PKDefault -StepName PkDefault -ExpectedHashName PkDefault }
            'PostWrite' { Invoke-RebootWithResume -Destination Windows -Reason 'DeveloperForcePostWriteCheck' }
            default { throw (L '无法确定开发者强制写入步骤。' 'The developer force write step could not be determined.') }
        }
    } finally {
        $script:DeveloperForceActive = $false
    }
}

function Invoke-PrimaryAction {
    $state = $script:CurrentState
    switch ($state.Classification) {
        'ReadyForRepair' {
            if (-not $state.WriteAllowed) { throw $state.BlockReason }
            if ($null -eq $script:CurrentTransaction) { $script:CurrentTransaction = New-RepairTransaction $state }
            Invoke-WriteDbDefault
        }
        'RecoverableIntermediate' {
            if (-not $state.WriteAllowed) { throw $state.BlockReason }
            $operation = Get-NextRepairOperation $state
            switch ($operation) {
                'Db2023' {
                    if (-not (Get-ValidatedCertificatePath)) {
                        Show-CertificateInfo
                        if (-not (Get-ValidatedCertificatePath)) { return }
                    }
                    Invoke-Append2023Certificate
                }
                'DbxDefault' { Invoke-RestoreDefaultVariable -TargetName dbx -DefaultName dbxDefault -StepName DbxDefault -ExpectedHashName DbxDefault }
                'KekDefault' { Invoke-RestoreDefaultVariable -TargetName KEK -DefaultName KEKDefault -StepName KekDefault -ExpectedHashName KekDefault }
                'PkDefault' { Invoke-RestoreDefaultVariable -TargetName PK -DefaultName PKDefault -StepName PkDefault -ExpectedHashName PkDefault }
                default { throw '无法确定下一修复步骤。' }
            }
        }
        'PkWrittenPendingReboot' { Invoke-RebootWithResume -Destination Windows -Reason 'ValidateAfterPK' }
        'NeedsOfficialRotation' { Invoke-OfficialRotation }
        'OfficialRotationNeedsReboot' { Invoke-RebootWithResume -Destination Windows -Reason 'ContinueOfficialRotation' }
        'SecureBootDisabledWithKeys' { Show-SecureBootEnableGuidance -State $state }
        'BootChainRepairRequired' { Show-BootChainRepairDialog -State $state }
        'BootChainReviewRequired' { Show-BootChainManualReviewDialog -State $state }
        'NeedsFirmwareSetup' { Invoke-RebootWithResume -Destination Firmware -Reason 'EnterSetupModeAndClearKeys' }
        'AdvancedRecoveryRequired' { Show-AdvancedRecoveryDialog }
        'BlockedUnsafe' { Show-AdvancedRecoveryDialog }
        'Completed' { [Windows.Forms.MessageBox]::Show('当前设备已经完成2023证书轮换。', $script:AppName, 'OK', 'Information') | Out-Null }
        default { throw ($state.BlockReason + ' ' + $state.NextStep) }
    }
}

function Update-StepsList {
    param([object]$State)
    $script:StepsList.Items.Clear()
    $steps = @(
        @('1',(L '环境与Setup Mode检测' 'Environment and Setup Mode detection')),
        @('2',(L '备份四个Default Keys' 'Back up all four Default Keys')),
        @('3',(L 'dbDefault → 活动db' 'dbDefault -> active db')),
        @('4',(L '追加Windows UEFI CA 2023' 'Append Windows UEFI CA 2023')),
        @('5',(L 'dbxDefault → 活动dbx' 'dbxDefault -> active dbx')),
        @('6',(L 'KEKDefault → 活动KEK' 'KEKDefault -> active KEK')),
        @('7',(L 'PKDefault → 活动PK' 'PKDefault -> active PK')),
        @('8',(L '重启并重新检测' 'Restart and re-detect')),
        @('9',(L '微软官方完整轮换' 'Microsoft official full rotation')),
        @('10',(L '最终验证与Factory Keys风险提醒' 'Final verification / Factory Keys warning'))
    )
    foreach ($step in $steps) {
        $item = New-Object Windows.Forms.ListViewItem($step[0])
        $item.SubItems.Add($step[1]) | Out-Null
        $rawStatus = '待处理'
        if ($step[0] -eq '1') { $rawStatus = if ($State.IsAsus -and $State.IsUEFI) {'通过'} else {'阻止'} }
        if ($null -ne $script:CurrentTransaction) {
            $map = @{ '2'='Backup'; '3'='DbDefault'; '4'='Db2023'; '5'='DbxDefault'; '6'='KekDefault'; '7'='PkDefault'; '8'='Reboot'; '9'='OfficialRotation' }
            if ($map.ContainsKey($step[0])) { $rawStatus = [string]$script:CurrentTransaction.Steps[$map[$step[0]]] }
        }
        if ($step[0] -eq '10' -and $State.Classification -eq 'Completed') { $rawStatus = '通过' }
        $item.SubItems.Add((Get-StepStatusDisplay $rawStatus)) | Out-Null
        if ($rawStatus -in @('Complete','通过')) { $item.ForeColor = [Drawing.Color]::DarkGreen }
        elseif ($rawStatus -in @('Failed','阻止')) { $item.ForeColor = [Drawing.Color]::DarkRed }
        elseif ($rawStatus -match 'Pending|Scheduled|Needs|待处理') { $item.ForeColor = [Drawing.Color]::DarkOrange }
        $script:StepsList.Items.Add($item) | Out-Null
    }
}

function Update-StateGrid {
    param([object]$State)
    $script:Grid.Rows.Clear()
    $rows = @(
        @((L '设备厂商' 'Manufacturer'),$State.Manufacturer),
        @((L '型号' 'Model'),$State.Model),
        @((L '主板厂商' 'Baseboard manufacturer'),$State.BaseBoardManufacturer),
        @((L '主板' 'Baseboard'),$State.BaseBoard),
        @('BIOS',$State.BIOSVersion),
        @((L 'UEFI启动' 'UEFI boot'),$State.IsUEFI),
        @((L 'ASUS/ROG硬件匹配' 'ASUS/ROG hardware match'),$State.HardwareIsAsus),
        @((L '开发者模式' 'Developer mode'),$State.DeveloperMode),
        @((L '开发者强制操作中' 'Developer force active'),$State.DeveloperForceActive),
        @((L '可用开发者强制突破' 'Developer override available'),$State.DeveloperOverrideAvailable),
        @((L '待处理重启' 'Pending restart'),$State.PendingReboot.IsPending),
        @((L '待处理重启来源' 'Pending restart sources'),$(if ($State.PendingReboot.Summary) { $State.PendingReboot.Summary } else { '-' })),
        @((L '待处理重启强制继续' 'Pending restart override'),$State.PendingRebootOverride),
        @('SetupMode',$State.SetupMode),
        @((L 'SecureBoot变量' 'SecureBoot variable'),$State.SecureBootVariable),
        @((L 'Secure Boot实际启用' 'Secure Boot enabled'),$State.ConfirmSecureBoot),
        @((L 'Secure Boot确认可读' 'Secure Boot confirmation readable'),$State.ConfirmSecureBootReadable),
        @((L '活动变量读取完整' 'Active variables readable'),$State.ActiveVariablesReadable),
        @((L 'BIOS默认Keys读取完整' 'BIOS factory Keys readable'),$State.DefaultVariablesReadable),
        @('PK',("{0} / {1} bytes" -f $State.Variables.PK.Exists,$State.Variables.PK.Length)),
        @('KEK',("{0} / {1} bytes" -f $State.Variables.KEK.Exists,$State.Variables.KEK.Length)),
        @('db',("{0} / {1} bytes" -f $State.Variables.db.Exists,$State.Variables.db.Length)),
        @('dbx',("{0} / {1} bytes" -f $State.Variables.dbx.Exists,$State.Variables.dbx.Length)),
        @('PKDefault',$State.Variables.PKDefault.Length),
        @('KEKDefault',$State.Variables.KEKDefault.Length),
        @('dbDefault',$State.Variables.dbDefault.Length),
        @('dbxDefault',$State.Variables.dbxDefault.Length),
        @('Windows UEFI CA 2023',$State.CertificateFlags.WindowsUEFICA2023),
        @('Microsoft UEFI CA 2023',$State.CertificateFlags.MicrosoftUEFICA2023),
        @('Option ROM UEFI CA 2023',$State.CertificateFlags.OptionROMUEFICA2023),
        @('KEK 2K CA 2023',$State.CertificateFlags.KEK2KCA2023),
        @((L '需要第三方2023 CA' 'Third-party 2023 CAs required'),$State.RotationVerification.RequiresThirdParty2023),
        @((L '2023轮换内容验证' '2023 rotation content verification'),$State.RotationVerification.Message),
        @('UEFICA2023Status',$State.Servicing.UEFICA2023Status),
        @('AvailableUpdates',$State.Servicing.AvailableUpdatesHex),
        @((L '官方任务' 'Official task'),$State.ScheduledTask.State),
        @((L '交流电源' 'AC power'),$State.Power.PowerLineStatus),
        @((L '电池电量' 'Battery'),$(if ($null -eq $State.Power.BatteryPercent) {'N/A'} else {"$($State.Power.BatteryPercent)%"})),
        @((L 'BitLocker状态可判定' 'BitLocker state known'),$State.BitLocker.IsKnown),
        @((L '系统盘已完全解密' 'System drive fully decrypted'),$State.BitLocker.IsFullyDecrypted),
        @((L 'BitLocker保护' 'BitLocker protection'),$State.BitLocker.IsProtected),
        @((L 'BitLocker保护状态' 'BitLocker protection status'),$State.BitLocker.ProtectionStatus),
        @((L 'BitLocker卷状态' 'BitLocker volume status'),$State.BitLocker.VolumeStatus),
        @((L '允许写入' 'Write allowed'),$State.WriteAllowed),
        @((L '写入阻止原因' 'Write block reason'),$(if ([string]::IsNullOrWhiteSpace([string]$State.BlockReason)) { '-' } else { $State.BlockReason })),
        @((L '操作按钮阻止原因' 'Action button block reason'),$(if ([string]::IsNullOrWhiteSpace([string]$State.ActionBlockReason)) { '-' } else { $State.ActionBlockReason })),
        @((L '状态分类' 'State classification'),("{0} ({1})" -f (Get-ClassificationDisplay $State.Classification),$State.Classification))
    )

    $showFullBootChainDetails = ($State.Classification -in @('SecureBootDisabledWithKeys','BootChainRepairRequired','BootChainReviewRequired'))
    if ($showFullBootChainDetails) {
        $bootRows = @(
            @((L '启动链检查' 'Boot-chain check'),$State.BootChain.Message),
            @((L 'Windows Boot Manager首启动' 'Windows Boot Manager first'),$State.BootChain.WindowsBootManagerFirst),
            @((L 'Windows Boot Manager路径' 'Windows Boot Manager path'),$State.BootChain.WindowsBootManagerPath),
            @((L '可疑固件启动项' 'Suspicious firmware boot entries'),$(if ([string]::IsNullOrWhiteSpace([string]$State.BootChain.SuspiciousFirmwareEntries)) { '-' } else { $State.BootChain.SuspiciousFirmwareEntries })),
            @((L '第三方EFI线索' 'Third-party EFI indicators'),$(if ([string]::IsNullOrWhiteSpace([string]$State.BootChain.ThirdPartyEfiIndicators)) { '-' } else { $State.BootChain.ThirdPartyEfiIndicators })),
            @((L '外接/可移动启动线索' 'External/removable boot indicators'),$(if ([string]::IsNullOrWhiteSpace([string]$State.BootChain.ExternalBootIndicators)) { '-' } else { $State.BootChain.ExternalBootIndicators })),
            @((L 'bootmgfw.efi签名检查' 'bootmgfw.efi signature check'),$State.BootChain.BootmgfwSignatureStatus),
            @((L 'bootmgfw.efi签名说明' 'bootmgfw.efi signature note'),$State.BootChain.BootmgfwSignatureMessage),
            @((L 'EFI分区扫描' 'EFI partition scan'),$State.BootChain.EfiPartitionScanStatus),
            @((L 'CSM/Option ROM检查' 'CSM/Option ROM check'),$State.BootChain.CsmOptionRomStatus),
            @((L '官方轮换事件关联' 'Official rotation event correlation'),$State.BootChain.OfficialRotationEventSummary),
            @((L '启动链结果' 'Boot-chain result'),$State.BootChain.RiskDisposition),
            @((L '怎么处理' 'How to fix'),$State.BootChain.ManualActionMessage),
            @((L '完成后' 'After fixing'),$State.BootChain.ManualReviewWorkflow),
            @((L '启动链深度诊断' 'Boot-chain deep diagnostics'),$State.BootChain.DeepDiagnosticsMessage)
        )
        foreach ($bootRow in $bootRows) { $rows += ,$bootRow }
    } elseif ($State.ConfirmSecureBoot) {
        $rows += ,@((L '启动链检查' 'Boot-chain check'),(L 'Secure Boot 已启用。启动链检查只在启用前作为拦截条件，当前无需处理。' 'Secure Boot is already enabled. Boot-chain checks are used only before enabling it. No action is needed now.'))
    }

    foreach ($row in $rows) { $script:Grid.Rows.Add($row[0], [string]$row[1]) | Out-Null }
}

function Update-OverviewGrid {
    param([object]$State)
    if ($null -eq $script:OverviewGrid) { return }
    $script:OverviewGrid.Rows.Clear()

    $rows = New-Object System.Collections.ArrayList
    [void]$rows.Add(@((L '设备' 'Device'),("{0} / {1}" -f $State.Manufacturer,$State.Model)))
    [void]$rows.Add(@((L '固件状态' 'Firmware state'),("UEFI={0}, SetupMode={1}, SecureBoot={2}" -f $State.IsUEFI,$State.SetupMode,$State.ConfirmSecureBoot)))
    [void]$rows.Add(@((L 'Active Keys' 'Active Keys'),("PK={0}, KEK={1}, db={2}, dbx={3}" -f $State.Variables.PK.Exists,$State.Variables.KEK.Exists,$State.Variables.db.Exists,$State.Variables.dbx.Exists)))
    [void]$rows.Add(@((L '2023证书/KEK' '2023 certificates/KEK'),("Windows={0}, Microsoft={1}, OptionROM={2}, KEK={3}" -f $State.CertificateFlags.WindowsUEFICA2023,$State.CertificateFlags.MicrosoftUEFICA2023,$State.CertificateFlags.OptionROMUEFICA2023,$State.CertificateFlags.KEK2KCA2023)))
    [void]$rows.Add(@((L 'Windows轮换状态' 'Windows rotation status'),("{0}, AvailableUpdates={1}" -f $State.Servicing.UEFICA2023Status,$State.Servicing.AvailableUpdatesHex)))
    [void]$rows.Add(@((L 'BitLocker / 电源' 'BitLocker / power'),("Known={0}, Decrypted={1}, Protected={2}, AC={3}, Battery={4}" -f $State.BitLocker.IsKnown,$State.BitLocker.IsFullyDecrypted,$State.BitLocker.IsProtected,$State.Power.PowerLineStatus,$(if ($null -eq $State.Power.BatteryPercent) {'N/A'} else {"$($State.Power.BatteryPercent)%"}))))

    $showBootChain = ($State.Classification -in @('SecureBootDisabledWithKeys','BootChainRepairRequired','BootChainReviewRequired'))
    if ($showBootChain) {
        [void]$rows.Add(@((L '启动链检查' 'Boot-chain check'),$State.BootChain.Message))
        [void]$rows.Add(@((L '启动链结果' 'Boot-chain result'),$State.BootChain.RiskDisposition))
        [void]$rows.Add(@((L '怎么处理' 'How to fix'),$State.BootChain.ManualActionMessage))
        [void]$rows.Add(@((L '下一步' 'Next step'),$State.BootChain.ManualReviewWorkflow))
    }

    [void]$rows.Add(@((L '允许写入' 'Write allowed'),$State.WriteAllowed))
    $actionReason = if ([string]::IsNullOrWhiteSpace([string]$State.ActionBlockReason)) { $(if ([string]::IsNullOrWhiteSpace([string]$State.BlockReason)) { '-' } else { $State.BlockReason }) } else { $State.ActionBlockReason }
    if ($actionReason -ne '-') { [void]$rows.Add(@((L '按钮不可用原因' 'Disabled action reason'),$actionReason)) }
    if (-not [string]::IsNullOrWhiteSpace([string]$State.SecureBootEnableWarning)) { [void]$rows.Add(@((L '启用Secure Boot提醒' 'Enable Secure Boot notice'),$State.SecureBootEnableWarning)) }
    [void]$rows.Add(@((L '风险等级' 'Risk level'),(Get-DefaultResetRiskLevelDisplay $State.DefaultResetRiskLevel)))
    [void]$rows.Add(@((L 'BIOS默认Keys说明' 'BIOS Default Keys details'),$State.DefaultResetRisk))

    foreach ($row in $rows) { $script:OverviewGrid.Rows.Add($row[0],[string]$row[1]) | Out-Null }
}

function Show-FileCreationInfo {
    $transactionRoot = if ($null -ne $script:CurrentTransaction) { [string]$script:CurrentTransaction.TransactionRoot } else { L '尚未创建（仅在开始修复时创建）' 'Not created yet (created only when a repair starts)' }
    $logRoot = if ($script:SessionLogRoot) { $script:SessionLogRoot } else { L '尚未创建' 'Not created yet' }
    $backupExists = if ($script:BackupRoot -and (Test-Path -LiteralPath $script:BackupRoot)) { L '已存在' 'Exists' } else { L '不存在' 'Does not exist' }
    $appDataExists = if (Test-Path -LiteralPath $script:AppDataRoot) { L '已存在' 'Exists' } else { L '不存在' 'Does not exist' }
    $text = if ($script:Language -eq 'en-US') {
@"
File locations:

Selected backup root ($backupExists):
$script:BackupRoot

Current session log folder:
$logRoot

Current progress folder:
$transactionRoot

Protected settings/resume/certificate folder ($appDataExists):
$script:AppDataRoot

Contents may include settings, one-time resume state, protected certificate files, and temporary import/export files. Temporary files are removed after use.

Logs are created after you confirm OOBE and start detection. Progress folders are created only when a repair begins. Export ZIP files are created only after you choose a destination. Automatic upload: none.
"@
    } else {
@"
文件保存位置：

用户选择的备份根目录（$backupExists）：
$script:BackupRoot

本次会话日志目录：
$logRoot

当前修复进度目录：
$transactionRoot

受保护的设置/续跑/证书目录（$appDataExists）：
$script:AppDataRoot

内容可能包括设置、一次性续跑状态、证书文件和临时导入/导出文件。临时文件使用后删除。

日志在完成首次设置并开始检测后创建。进度目录在开始修复后创建。导出 ZIP 只在选择保存位置后创建。自动上传：无。
"@
    }
    [Windows.Forms.MessageBox]::Show($text, (L '文件与目录' 'File locations'), 'OK', 'Information') | Out-Null
}

function Set-ContextButtonVisibility {
    param([object]$State)
    $op = Get-NextRepairOperation $State
    $needsCertificate = ($State.Classification -eq 'RecoverableIntermediate' -and $op -eq 'Db2023')
    if ($null -ne $script:CertificateSourceButton) { $script:CertificateSourceButton.Visible = $needsCertificate }
    if ($null -ne $script:CertificateButton) { $script:CertificateButton.Visible = $needsCertificate }
    if ($null -ne $script:BitLockerButton) {
        $script:BitLockerButton.Visible = ((-not $State.BitLocker.IsKnown) -or (-not $State.BitLocker.IsFullyDecrypted) -or $State.Classification -in @('NeedsFirmwareSetup','SecureBootDisabledWithKeys','BootChainRepairRequired','BootChainReviewRequired','PkWrittenPendingReboot','OfficialRotationNeedsReboot'))
    }
    if ($null -ne $script:PendingOverrideButton) {
        $hasPending = ($null -ne $State.PendingReboot -and $State.PendingReboot.IsPending)
        $script:PendingOverrideButton.Visible = ($hasPending -and $script:DeveloperModeEnabled -and -not $script:PendingRebootOverride)
    }
    if ($null -ne $script:DeveloperForceButton) {
        $script:DeveloperForceButton.Visible = ($script:DeveloperModeEnabled -and $State.DeveloperOverrideAvailable)
    }
    if ($null -ne $script:RecoveryImportButton) {
        $script:RecoveryImportButton.Visible = ($State.Classification -in @('AdvancedRecoveryRequired','BlockedUnsafe'))
    }
    if ($null -ne $script:RecoveryExportButton) {
        $script:RecoveryExportButton.Visible = ($null -ne $script:CurrentTransaction -and [string]$script:CurrentTransaction.Status -ne 'Complete')
    }
    if ($null -ne $script:ContextActionsPanel) {
        $script:ContextActionsPanel.Visible = @($script:ContextActionsPanel.Controls | Where-Object { $_.Visible }).Count -gt 0
    }
    if ($null -ne $script:OpenLogsButton) { $script:OpenLogsButton.Enabled = ($script:SessionLogRoot -and (Test-Path -LiteralPath $script:SessionLogRoot)) }
    if ($null -ne $script:OpenBackupButton) { $script:OpenBackupButton.Enabled = ($script:BackupRoot -and (Test-Path -LiteralPath $script:BackupRoot)) }
    if ($null -ne $script:ExportDiagnosticsButton) { $script:ExportDiagnosticsButton.Enabled = ($script:SessionLogRoot -and (Test-Path -LiteralPath $script:SessionLogRoot)) }
}

function Refresh-MainUi {
    param([string]$Reason = 'ManualRefresh')
    $script:CurrentTransaction = Load-CurrentTransaction
    $script:CurrentState = Get-SystemState
    if (Sync-TransactionProgressFromState -State $script:CurrentState -Transaction $script:CurrentTransaction) {
        $script:CurrentState = Get-SystemState
    }
    try { Append-StateHistory -State $script:CurrentState -Reason $Reason } catch { try { Write-UiLog ((L '状态历史写入失败，不影响当前检测结果：{0}' 'State history write failed. Current detection continues: {0}') -f $_.Exception.Message) 'WARN' } catch {} }
    try { Export-DiagnosticSnapshot -State $script:CurrentState -Reason $Reason } catch { try { Write-UiLog ((L '诊断报告写入失败，不影响当前检测结果：{0}' 'Diagnostic snapshot write failed. Current detection continues: {0}') -f $_.Exception.Message) 'WARN' } catch {} }
    Update-StateGrid $script:CurrentState
    Update-StepsList $script:CurrentState
    Update-OverviewGrid $script:CurrentState

    $display = Get-ClassificationDisplay $script:CurrentState.Classification
    $script:StatusLabel.Text = ((L '当前状态：{0}' 'Current state: {0}') -f $display)
    $riskLevelDisplay = Get-DefaultResetRiskLevelDisplay $script:CurrentState.DefaultResetRiskLevel
    $script:RiskTitleLabel.Text = ((L '风险等级：{0}' 'Risk level: {0}') -f $riskLevelDisplay)
    $script:WarningBox.Text = $script:CurrentState.DefaultResetRisk
    switch ($script:CurrentState.DefaultResetRiskLevel) {
        'Low' {
            $script:RiskPanel.BackColor = [Drawing.Color]::FromArgb(232,245,233)
            $script:RiskTitleLabel.ForeColor = [Drawing.Color]::DarkGreen
            $script:WarningBox.ForeColor = [Drawing.Color]::FromArgb(30,80,40)
            $script:WarningBox.Font = New-Object Drawing.Font((Get-LocalizedFontName), 9, [Drawing.FontStyle]::Regular)
        }
        'High' {
            $script:RiskPanel.BackColor = [Drawing.Color]::FromArgb(255,235,238)
            $script:RiskTitleLabel.ForeColor = [Drawing.Color]::DarkRed
            $script:WarningBox.ForeColor = [Drawing.Color]::DarkRed
            $script:WarningBox.Font = New-Object Drawing.Font((Get-LocalizedFontName), 9, [Drawing.FontStyle]::Regular)
        }
        'Warning' {
            $script:RiskPanel.BackColor = [Drawing.Color]::FromArgb(255,248,225)
            $script:RiskTitleLabel.ForeColor = [Drawing.Color]::DarkOrange
            $script:WarningBox.ForeColor = [Drawing.Color]::DarkRed
            $script:WarningBox.Font = New-Object Drawing.Font((Get-LocalizedFontName), 9, [Drawing.FontStyle]::Bold)
        }
        default {
            $script:RiskPanel.BackColor = [Drawing.Color]::FromArgb(255,248,225)
            $script:RiskTitleLabel.ForeColor = [Drawing.Color]::DarkOrange
            $script:WarningBox.ForeColor = [Drawing.Color]::FromArgb(120,78,0)
            $script:WarningBox.Font = New-Object Drawing.Font((Get-LocalizedFontName), 9, [Drawing.FontStyle]::Regular)
        }
    }

    $script:PrimaryButton.Enabled = $false
    $script:PrimaryButton.Visible = $false
    $script:PrimaryButton.Text = ''
    $script:NextActionLabel.Text = ((L '下一步：{0}' 'Next step: {0}') -f $script:CurrentState.NextStep)
    switch ($script:CurrentState.Classification) {
        'ReadyForRepair' {
            $script:PrimaryButton.Text = L '开始修复：备份并写入 dbDefault' 'Start repair: back up and write dbDefault'
            $script:PrimaryButton.Enabled = $script:CurrentState.WriteAllowed
            $script:PrimaryButton.Visible = $true
        }
        'RecoverableIntermediate' {
            $op = Get-NextRepairOperation $script:CurrentState
            $script:PrimaryButton.Text = switch ($op) {
                'Db2023' { L '下一步：选择证书后追加Windows UEFI CA 2023' 'Next: select and append Windows UEFI CA 2023' }
                'DbxDefault' { L '下一步：恢复dbxDefault' 'Next: restore dbxDefault' }
                'KekDefault' { L '下一步：恢复KEKDefault' 'Next: restore KEKDefault' }
                'PkDefault' { L '下一步：最后写入PKDefault' 'Next: write PKDefault last' }
                default { L '无法确定下一步' 'Unable to determine the next step' }
            }
            $script:PrimaryButton.Enabled = $script:CurrentState.WriteAllowed
            $script:PrimaryButton.Visible = $true
        }
        'PkWrittenPendingReboot' {
            $script:PrimaryButton.Text = L '立即重启并自动续检' 'Restart and detect again'
            $script:PrimaryButton.Enabled = ([string]::IsNullOrWhiteSpace([string]$script:CurrentState.ActionBlockReason))
            $script:PrimaryButton.Visible = $true
        }
        'NeedsOfficialRotation' {
            $script:PrimaryButton.Text = L '运行微软官方2023轮换' 'Run Microsoft official 2023 rotation'
            $script:PrimaryButton.Enabled = $script:CurrentState.WriteAllowed
            $script:PrimaryButton.Visible = $true
        }
        'OfficialRotationNeedsReboot' {
            $script:PrimaryButton.Text = L '重启并继续官方轮换' 'Restart and continue official rotation'
            $script:PrimaryButton.Enabled = ([string]::IsNullOrWhiteSpace([string]$script:CurrentState.ActionBlockReason))
            $script:PrimaryButton.Visible = $true
        }
        'SecureBootDisabledWithKeys' {
            $script:PrimaryButton.Text = L '查看启用Secure Boot说明…' 'Read Secure Boot enable notice...'
            $script:PrimaryButton.Enabled = ([string]::IsNullOrWhiteSpace([string]$script:CurrentState.ActionBlockReason))
            $script:PrimaryButton.Visible = $true
        }
        'BootChainRepairRequired' {
            $script:PrimaryButton.Text = L '修复Windows Boot Manager启动项…' 'Repair Windows Boot Manager boot entry...'
            $script:PrimaryButton.Enabled = ([string]::IsNullOrWhiteSpace([string]$script:CurrentState.ActionBlockReason))
            $script:PrimaryButton.Visible = $true
        }
        'BootChainReviewRequired' {
            $script:PrimaryButton.Text = L '查看启动链排查说明…' 'Review manual boot-chain guidance...'
            $script:PrimaryButton.Enabled = $true
            $script:PrimaryButton.Visible = $true
        }
        'NeedsFirmwareSetup' {
            $script:PrimaryButton.Text = L '重启进入BIOS设置Setup Mode' 'Restart into UEFI to enter Setup Mode'
            $script:PrimaryButton.Enabled = ([string]::IsNullOrWhiteSpace([string]$script:CurrentState.ActionBlockReason))
            $script:PrimaryButton.Visible = $true
        }
        'AdvancedRecoveryRequired' {
            $script:PrimaryButton.Text = L '恢复未完成的修复流程…' 'Recover an unfinished repair workflow...'
            $script:PrimaryButton.Enabled = $true
            $script:PrimaryButton.Visible = $true
        }
        'BlockedUnsafe' {
            $script:PrimaryButton.Text = L '查看受限恢复选项…' 'Review restricted recovery options...'
            $script:PrimaryButton.Enabled = $true
            $script:PrimaryButton.Visible = $true
        }
        'Completed' {
            $script:NextActionLabel.Text = if ($script:CurrentState.DefaultResetRiskLevel -eq 'Warning') { L '已完成：无需继续操作。不要使用 Restore Factory Keys。' 'Completed: no action is needed. Do not use Restore Factory Keys.' } else { L '已完成：无需继续操作。不要使用 Restore Factory Keys。' 'Completed: no action is needed. Do not use Restore Factory Keys.' }
        }
    }

    if ($null -ne $script:ActionBlockReasonLabel) {
        $actionBlockReason = if (-not [string]::IsNullOrWhiteSpace([string]$script:CurrentState.ActionBlockReason)) { [string]$script:CurrentState.ActionBlockReason } elseif (-not [string]::IsNullOrWhiteSpace([string]$script:CurrentState.BlockReason)) { [string]$script:CurrentState.BlockReason } else { [string]$script:CurrentState.NextStep }
        $showBlockedNotice = [bool]$script:CurrentState.DeveloperOverrideAvailable
        $script:ActionBlockReasonLabel.Visible = $showBlockedNotice
        if ($showBlockedNotice) {
            $hint = Get-DeveloperModeHint
            $panelWidth = $script:ActionBlockReasonLabel.Parent.ClientSize.Width
            $noticeRight = if ($script:PrimaryButton.Visible) { $script:PrimaryButton.Left - 18 } else { $panelWidth - 14 }
            $noticeWidth = [Math]::Max(320, $noticeRight - $script:ActionBlockReasonLabel.Left)
            $script:ActionBlockReasonLabel.Size = New-Object Drawing.Size($noticeWidth, 62)
            $script:ActionBlockReasonLabel.Text = ((L '当前限制：{0}{1}{2}' 'Current block: {0}{1}{2}') -f $actionBlockReason, [Environment]::NewLine, $hint)
            if ($null -ne $script:MainToolTip) { $script:MainToolTip.SetToolTip($script:ActionBlockReasonLabel, ($actionBlockReason + [Environment]::NewLine + $hint)) }
        } else {
            $script:ActionBlockReasonLabel.Text = ''
            $script:ActionBlockReasonLabel.Size = New-Object Drawing.Size(900, 62)
            if ($null -ne $script:MainToolTip) { $script:MainToolTip.SetToolTip($script:ActionBlockReasonLabel, '') }
        }
    }

    if ($script:PrimaryButton.Visible -and $script:PrimaryButton.Enabled) {
        $script:PrimaryButton.UseVisualStyleBackColor = $false
        $script:PrimaryButton.BackColor = [Drawing.Color]::FromArgb(255,235,153)
        $script:PrimaryButton.ForeColor = [Drawing.Color]::Black
    } else {
        $script:PrimaryButton.UseVisualStyleBackColor = $true
    }

    Set-ContextButtonVisibility $script:CurrentState
    Write-UiLog ((L '状态刷新完成：{0}, WriteAllowed={1}, BlockReason={2}, ActionBlockReason={3}' 'State refresh completed: {0}, WriteAllowed={1}, BlockReason={2}, ActionBlockReason={3}') -f $script:CurrentState.Classification, $script:CurrentState.WriteAllowed, $script:CurrentState.BlockReason, $script:CurrentState.ActionBlockReason) 'INFO'
    if ($script:CurrentState.PostPkActiveStateVerified -and $null -ne $script:CurrentTransaction -and [string]$script:CurrentTransaction.Status -eq 'Locked') {
        Write-UiLog (L '当前活动Secure Boot状态已通过重新检测，继续按真实固件状态判断。' 'Post-PK transaction anomaly recognized from the current active firmware state; continuing from the real firmware state.') 'WARN'
    }
}


function Show-CertificateInfo {
    $dialog = New-Object Windows.Forms.OpenFileDialog
    $dialog.Title = L '选择从微软官方网址下载的Windows UEFI CA 2023证书' 'Select the Windows UEFI CA 2023 certificate downloaded from the official Microsoft URL'
    $dialog.Filter = L '证书文件 (*.cer;*.crt)|*.cer;*.crt|所有文件 (*.*)|*.*' 'Certificate files (*.cer;*.crt)|*.cer;*.crt|All files (*.*)|*.*'
    if ($dialog.ShowDialog() -ne 'OK') { return }
    $validation = Invoke-ValidateAndStoreCertificate $dialog.FileName
    if ($script:Language -eq 'en-US') {
        $text = @"
Certificate validation passed

File: $($validation.FileName)
Size: $($validation.Size) bytes
SHA-256: $($validation.SHA256)
MD5: $($validation.MD5) (calculated at runtime for identification only, not used for trust)
SHA-1 Thumbprint: $($validation.CertificateThumbprint)
Subject: $($validation.Subject)
Issuer: $($validation.Issuer)
Validity: $($validation.NotBefore) to $($validation.NotAfter)
"@
    } else {
        $text = @"
证书校验通过

文件：$($validation.FileName)
大小：$($validation.Size) 字节
SHA-256：$($validation.SHA256)
MD5：$($validation.MD5)（现场计算，仅供文件识别，安全判定不依赖MD5）
SHA-1 Thumbprint：$($validation.CertificateThumbprint)
Subject：$($validation.Subject)
Issuer：$($validation.Issuer)
有效期：$($validation.NotBefore) 至 $($validation.NotAfter)
"@
    }
    [Windows.Forms.MessageBox]::Show($text, (L '证书完整性校验' 'Certificate integrity validation'), 'OK', 'Information') | Out-Null
}

function Export-DiagnosticPackage {
    if (-not $script:SessionLogRoot -or -not (Test-Path $script:SessionLogRoot)) { throw (L '当前没有可导出的日志。' 'There are no logs available to export.') }
    $explanation = L @'
报告内容：本次检测日志、脱敏后的系统状态、相关事件和错误编号。

不包含：Default Keys 原始备份、BitLocker 恢复密钥和个人文件。

选择保存位置后生成 ZIP 文件。
'@ @'
Report contents: current session logs, sanitized system state, relevant events, and error IDs.

Not included: raw Default Keys backups, BitLocker recovery keys, or personal files.

The ZIP is created after a destination is selected in the Save dialog.
'@
    if ([Windows.Forms.MessageBox]::Show($explanation, (L '导出诊断报告' 'Export diagnostic report'), 'OKCancel', 'Information') -ne [Windows.Forms.DialogResult]::OK) { return }
    $dialog = New-Object Windows.Forms.SaveFileDialog
    $dialog.Title = L '选择诊断报告保存位置' 'Choose where to save the diagnostic report'
    $dialog.Filter = L 'ZIP压缩包 (*.zip)|*.zip' 'ZIP archive (*.zip)|*.zip'
    $dialog.FileName = ('ASUSROG-SecureBoot-Diagnostic-{0}.zip' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    if ($dialog.ShowDialog() -ne 'OK') { return }
    if (Test-Path $dialog.FileName) { Remove-Item -LiteralPath $dialog.FileName -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($script:SessionLogRoot, $dialog.FileName, [IO.Compression.CompressionLevel]::Optimal, $false)
    Write-UiLog ((L '诊断报告已导出：{0}' 'Diagnostic report exported: {0}') -f $dialog.FileName) 'SUCCESS'
    [Windows.Forms.MessageBox]::Show(((L '诊断报告已生成在：' 'Diagnostic report created at: ') + [Environment]::NewLine + $dialog.FileName), $script:AppName, 'OK', 'Information') | Out-Null
}

function Resolve-DetectedPostPkReboot {
    if ($null -eq $script:CurrentTransaction) { return }
    if ([string]$script:CurrentTransaction.Status -ne 'Active') { return }
    if ([string]$script:CurrentTransaction.Steps.Reboot -eq 'Complete') { return }

    $pkStep = [string]$script:CurrentTransaction.Steps.PkDefault
    $lastIntent = Get-OptionalPropertyValue -Object $script:CurrentTransaction -Name 'LastWriteIntent'
    $intentStep = if ($null -ne $lastIntent) { [string](Get-OptionalPropertyValue -Object $lastIntent -Name 'Step' -Default '') } else { '' }
    if ($pkStep -notin @('Pending','Complete') -and $intentStep -ne 'PkDefault') { return }

    $markerRaw = [string](Get-OptionalPropertyValue -Object $script:CurrentTransaction -Name 'PkWrittenAt' -Default '')
    if ([string]::IsNullOrWhiteSpace($markerRaw) -and $null -ne $lastIntent) {
        $markerRaw = [string](Get-OptionalPropertyValue -Object $lastIntent -Name 'CreatedAt' -Default '')
    }
    if ([string]::IsNullOrWhiteSpace($markerRaw)) { return }

    try { $marker = [datetime]::Parse($markerRaw, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind) } catch { return }
    $bootTime = Get-SystemBootTime
    if ($null -eq $bootTime -or $bootTime -le $marker.AddSeconds(1)) { return }

    $state = Get-SystemState
    $valid = $state.IsAsus -and $state.IsUEFI -and $state.SetupMode -eq 0 -and $state.AllKeys -and $state.ConfirmSecureBoot -and $state.TransactionConsistency.IsConsistent -and $state.TransactionConsistency.RecognizedStage -eq 'PkWritten'
    if ($valid) {
        $script:CurrentTransaction.Steps.PkDefault = 'Complete'
        $script:CurrentTransaction.Steps.Reboot = 'Complete'
        $script:CurrentTransaction.CurrentStep = 'PostPkRebootVerified'
        $script:CurrentTransaction.PendingOperation = ''
        $script:CurrentTransaction.LastVerifiedAt = (Get-Date).ToString('o')
        Save-Transaction $script:CurrentTransaction
        Write-UiLog (L '检测到 PK 写入后已经发生 Windows 重启。真实 UEFI 状态和上次哈希验证通过，已恢复到下一阶段。' 'A Windows restart after the PK write was detected. Real UEFI state and saved hashes passed verification. The next stage is unlocked.') 'SUCCESS'
    } else {
        $script:CurrentTransaction.Steps.Reboot = 'Failed'
        $script:CurrentTransaction.Status = 'Locked'
        $script:CurrentTransaction.LastError = '检测到PK写入后发生过重启，但重启后的真实状态验证未通过。'
        Save-Transaction $script:CurrentTransaction
        Write-UiLog (L '检测到PK写入后已经重启，但状态验证未通过。已锁定后续写入并生成日志。' 'A restart after the PK write was detected, but state verification failed. Further writes are locked and diagnostics were generated.') 'ERROR'
    }
}

function Resolve-ResumeCheckpoint {
    if (-not $script:ResumeDetected -or $null -eq $script:CurrentTransaction) { return }
    $state = Get-SystemState
    if ($ResumeReason -in @('ValidateAfterPK','ContinueOfficialRotation','ManualStateCheck')) {
        if ($ResumeReason -eq 'ValidateAfterPK') {
            $valid = $state.IsAsus -and $state.IsUEFI -and $state.SetupMode -eq 0 -and $state.AllKeys -and $state.ConfirmSecureBoot -and $state.TransactionConsistency.IsConsistent -and $state.TransactionConsistency.RecognizedStage -eq 'PkWritten'
            if ($valid) {
                $script:CurrentTransaction.Steps.Reboot = 'Complete'
                $script:CurrentTransaction.CurrentStep = 'PostPkRebootVerified'
                $script:CurrentTransaction.PendingOperation = ''
                $script:CurrentTransaction.LastVerifiedAt = (Get-Date).ToString('o')
                Save-Transaction $script:CurrentTransaction
                Write-UiLog (L '重启后检查通过：Secure Boot 已启用，完整 Keys 与上次哈希一致。' 'Post-restart verification passed: Secure Boot is enabled and all key hashes match the saved record.') 'SUCCESS'
            } else {
                $script:CurrentTransaction.Steps.Reboot = 'Failed'
                $script:CurrentTransaction.Status = 'Locked'
                $script:CurrentTransaction.LastError = 'PK写入后的重启验证未通过。'
                Save-Transaction $script:CurrentTransaction
                Write-UiLog (L '重启后检查未通过：未满足 SecureBoot=True、SetupMode=0、完整 Keys 及上次哈希一致。已停止后续写入。' 'Post-restart verification failed: SecureBoot=True, SetupMode=0, complete keys, and matching saved hashes were not all satisfied. Further writes are stopped.') 'ERROR'
            }
        } elseif ([string]$script:CurrentTransaction.Steps.Reboot -eq 'Scheduled') {
            $script:CurrentTransaction.Steps.Reboot = 'Complete'
            $script:CurrentTransaction.PendingOperation = ''
            $script:CurrentTransaction.LastVerifiedAt = (Get-Date).ToString('o')
            Save-Transaction $script:CurrentTransaction
            Write-UiLog (L '已记录本次Windows重启并重新读取真实状态。' 'This Windows restart was recorded and the real state was read again.') 'SUCCESS'
        }
    }
}


function New-AboutIconBitmap {
    param([ValidateSet('Repository','Bilibili')][string]$Kind)
    $bitmap = New-Object Drawing.Bitmap 52, 52
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.Clear([Drawing.Color]::Transparent)
        if ($Kind -eq 'Repository') {
            $brush = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(36,41,47))
            $graphics.FillEllipse($brush, 2, 2, 48, 48)
            $brush.Dispose()
            $font = New-Object Drawing.Font('Segoe UI', 13, [Drawing.FontStyle]::Bold)
            $textBrush = New-Object Drawing.SolidBrush([Drawing.Color]::White)
            $format = New-Object Drawing.StringFormat
            $format.Alignment = [Drawing.StringAlignment]::Center
            $format.LineAlignment = [Drawing.StringAlignment]::Center
            $graphics.DrawString('GH', $font, $textBrush, (New-Object Drawing.RectangleF(2,2,48,48)), $format)
            $format.Dispose(); $textBrush.Dispose(); $font.Dispose()
        } else {
            $brush = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(251,114,153))
            $graphics.FillEllipse($brush, 2, 2, 48, 48)
            $brush.Dispose()
            $pen = New-Object Drawing.Pen([Drawing.Color]::White, 2.4)
            $graphics.DrawRectangle($pen, 13, 16, 26, 20)
            $graphics.DrawLine($pen, 19, 16, 15, 11)
            $graphics.DrawLine($pen, 33, 16, 37, 11)
            $graphics.DrawLine($pen, 20, 23, 20, 29)
            $graphics.DrawLine($pen, 32, 23, 32, 29)
            $pen.Dispose()
        }
    } finally {
        $graphics.Dispose()
    }
    return $bitmap
}

function Set-LockedDataGridViewLayout {
    param([Parameter(Mandatory)][System.Windows.Forms.DataGridView]$Grid)
    $Grid.AllowUserToAddRows = $false
    $Grid.AllowUserToDeleteRows = $false
    $Grid.AllowUserToOrderColumns = $false
    $Grid.AllowUserToResizeColumns = $false
    $Grid.AllowUserToResizeRows = $false
    $Grid.ReadOnly = $true
    $Grid.RowHeadersVisible = $false
    $Grid.MultiSelect = $false
    $Grid.SelectionMode = 'FullRowSelect'
    $Grid.ColumnHeadersHeightSizeMode = 'DisableResizing'
    $Grid.DefaultCellStyle.WrapMode = [System.Windows.Forms.DataGridViewTriState]::True
    $Grid.AutoSizeRowsMode = [System.Windows.Forms.DataGridViewAutoSizeRowsMode]::AllCellsExceptHeaders
    foreach ($column in $Grid.Columns) {
        $column.Resizable = [System.Windows.Forms.DataGridViewTriState]::False
        $column.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable
    }
}

function Lock-ListViewColumnWidths {
    param([Parameter(Mandatory)][System.Windows.Forms.ListView]$ListView)
    $ListView.AllowColumnReorder = $false
    $ListView.HeaderStyle = 'Nonclickable'
    $ListView.Add_ColumnWidthChanging({
        param($sender,$eventArgs)
        $eventArgs.Cancel = $true
        $eventArgs.NewWidth = $sender.Columns[$eventArgs.ColumnIndex].Width
    })
}


function Show-ConfirmationWarning {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Message
    )
    $owner = [Windows.Forms.Form]::ActiveForm
    if ($null -eq $owner) { $owner = $script:MainForm }
    $result = [Windows.Forms.MessageBox]::Show(
        $owner,
        $Message,
        $Title,
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Warning,
        [Windows.Forms.MessageBoxDefaultButton]::Button2
    )
    return ($result -eq [Windows.Forms.DialogResult]::Yes)
}

function Get-DeveloperModeHint {
    param([bool]$Enabled = $script:DeveloperModeEnabled)
    if ($Enabled) {
        return (L '可点击「开发者强制继续」跳过当前限制。' 'Select Developer force continue to bypass the current block.')
    }
    return (L '要强制继续：打开「关于」→「开启开发者模式」，再点击「开发者强制继续」。' 'To force continue, open About, enable Developer mode, and select Developer force continue.')
}

function Enable-DeveloperMode {
    if ($script:DeveloperModeEnabled) { return }
    $messageZh = @'
开发者模式可跳过设备和流程限制，直接执行受限步骤。

风险：现有 Keys 可能被覆盖，Windows 可能无法启动，也可能进入 BitLocker 恢复或需要手动恢复 BIOS。

风险由你自行承担。因使用开发者模式造成的数据丢失、无法启动或设备故障，我们不承担责任。

仅本次运行有效。确定开启？
'@
    $messageEn = @'
Developer mode can bypass device and flow restrictions and run a blocked step.

Risk: existing Keys may be replaced, Windows may become unbootable, BitLocker recovery may start, or manual BIOS recovery may be required.

Do at your own risk. We are not responsible for data loss, boot failure, or device damage caused by Developer mode.

Enabled for this session only. Continue?
'@
    if (Show-ConfirmationWarning -Title (L '开启开发者模式' 'Enable Developer mode') -Message (L $messageZh $messageEn)) {
        $script:DeveloperModeEnabled = $true
        $script:DeveloperModeAcknowledgedAt = Get-Date
        Write-UiLog (L '开发者模式已开启。' 'Developer mode enabled.') 'WARN'
        Refresh-MainUi -Reason 'DeveloperModeEnabled'
    }
}

function Enable-PendingRebootOverride {
    if (-not $script:DeveloperModeEnabled) {
        [Windows.Forms.MessageBox]::Show((Get-DeveloperModeHint -Enabled:$false), $script:AppName, 'OK', 'Warning') | Out-Null
        return
    }
    $pending = Get-PendingWindowsRebootState
    if (-not $pending.IsPending) { return }
    $details = if ($pending.Summary) { [string]$pending.Summary } else { L '来源未知' 'Unknown source' }
    $details = (($details -replace '\s+', ' ').Trim())
    if ($details.Length -gt 220) { $details = $details.Substring(0,220) + '…' }
    $messageZh = @'
Windows 待处理重启：
{0}

继续后跳过这项检查。未完成的更新可能引发系统异常、无法启动或 BitLocker 恢复。

风险由你自行承担。因本次操作造成的数据丢失、无法启动或设备故障，我们不承担责任。

确定继续？
'@
    $messageEn = @'
Windows pending restart:
{0}

Continuing skips this check for the current session. Incomplete updates may cause system errors, boot failure, or BitLocker recovery.

Do at your own risk. We are not responsible for data loss, boot failure, or device damage caused by this action.

Continue?
'@
    $message = (L $messageZh $messageEn) -f $details
    if (Show-ConfirmationWarning -Title (L '忽略待处理重启' 'Ignore pending restart') -Message $message) {
        $script:PendingRebootOverride = $true
        $script:PendingRebootOverrideAcknowledgedAt = Get-Date
        Write-UiLog (((L '已忽略待处理重启。来源：{0}' 'Pending restart ignored. Sources: {0}') -f $details)) 'WARN'
        Refresh-MainUi -Reason 'PendingRebootOverrideEnabled'
    }
}

function Show-AboutDialog {
    $about = New-Object Windows.Forms.Form
    $about.Text = L '关于' 'About'
    $about.ClientSize = New-Object Drawing.Size(640,410)
    $about.AutoScaleMode = 'Dpi'
    $about.StartPosition = 'CenterParent'
    $about.FormBorderStyle = 'FixedDialog'
    $about.MaximizeBox = $false
    $about.MinimizeBox = $false
    $about.ShowInTaskbar = $false
    $about.AutoScroll = $true
    $about.Font = New-Object Drawing.Font((Get-LocalizedFontName), 9)

    $title = New-Object Windows.Forms.Label
    $title.Text = $script:AppName
    $title.Font = New-Object Drawing.Font((Get-LocalizedFontName), 12.5, [Drawing.FontStyle]::Bold)
    $title.Location = New-Object Drawing.Point(24, 18)
    $title.Size = New-Object Drawing.Size(580, 52)
    $title.AutoEllipsis = $true
    $title.Anchor = 'Top, Left, Right'
    $about.Controls.Add($title)

    $meta = New-Object Windows.Forms.Label
    $meta.AutoSize = $false
    $versionLine = ((L '版本：{0}' 'Version: {0}') -f $script:AppVersion)
    $licenseLine = ((L '许可：{0}' 'License: {0}') -f $script:LicenseName)
    $authorLine = ((L '作者：{0} {1}' 'Author: {0} {1}') -f $script:AuthorName,$script:AuthorPlatform)
    $meta.Text = [string]::Join([Environment]::NewLine, [string[]]@($versionLine,$licenseLine,$authorLine))
    $meta.Location = New-Object Drawing.Point(27, 78)
    $meta.Size = New-Object Drawing.Size(560, 78)
    $meta.Anchor = 'Top, Left, Right'
    $about.Controls.Add($meta)

    $description = New-Object Windows.Forms.Label
    $description.Text = L 'Secure Boot 2023 证书检测与修复助手' 'Secure Boot 2023 certificate check and repair assistant'
    $description.Location = New-Object Drawing.Point(27, 164)
    $description.Size = New-Object Drawing.Size(560, 48)
    $description.Anchor = 'Top, Left, Right'
    $about.Controls.Add($description)

    $repo = New-Object Windows.Forms.Button
    $repo.Text = L '项目仓库' 'Project repository'
    $repo.Image = New-AboutIconBitmap -Kind Repository
    $repo.ImageAlign = [Drawing.ContentAlignment]::TopCenter
    $repo.TextAlign = [Drawing.ContentAlignment]::BottomCenter
    $repo.Location = New-Object Drawing.Point(96, 226)
    $repo.Size = New-Object Drawing.Size(180, 102)
    $repo.Anchor = 'Top, Left'
    $about.Controls.Add($repo)

    $bilibili = New-Object Windows.Forms.Button
    $bilibili.Text = L '哔哩哔哩主页' 'Bilibili profile'
    $bilibili.Image = New-AboutIconBitmap -Kind Bilibili
    $bilibili.ImageAlign = [Drawing.ContentAlignment]::TopCenter
    $bilibili.TextAlign = [Drawing.ContentAlignment]::BottomCenter
    $bilibili.Location = New-Object Drawing.Point(346, 226)
    $bilibili.Size = New-Object Drawing.Size(180, 102)
    $bilibili.Anchor = 'Top, Right'
    $about.Controls.Add($bilibili)

    $toolTip = New-Object Windows.Forms.ToolTip
    $toolTip.SetToolTip($repo, $script:RepositoryUrl)
    $toolTip.SetToolTip($bilibili, $script:AuthorUrl)
    $repo.Add_Click({ Open-TrustedUrl $script:RepositoryUrl })
    $bilibili.Add_Click({ Open-TrustedUrl $script:AuthorUrl })

    $developer = New-Object Windows.Forms.Button
    $developer.Text = if ($script:DeveloperModeEnabled) { L '开发者模式：已启用' 'Developer mode: ON' } else { L '开启开发者模式…' 'Enable Developer mode...' }
    $developer.Location = New-Object Drawing.Point(27, 350)
    $developer.Size = New-Object Drawing.Size(210, 34)
    $developer.Enabled = (-not $script:DeveloperModeEnabled)
    $developer.Add_Click({
        Enable-DeveloperMode
        if ($script:DeveloperModeEnabled) { $about.Close() }
    })
    $about.Controls.Add($developer)

    $close = New-Object Windows.Forms.Button
    $close.Text = L '关闭' 'Close'
    $close.DialogResult = [Windows.Forms.DialogResult]::OK
    $close.Location = New-Object Drawing.Point(490, 350)
    $close.Size = New-Object Drawing.Size(105, 34)
    $close.Anchor = 'Bottom, Right'
    $about.Controls.Add($close)
    $about.AcceptButton = $close
    $about.CancelButton = $close
    $about.ShowDialog($script:MainForm) | Out-Null
}

function Show-MainForm {
    $form = New-Object Windows.Forms.Form
    $script:MainForm = $form
    $form.Text = "$script:AppName  $script:AppVersion"
    $form.ClientSize = New-Object Drawing.Size(1320,880)
    $form.AutoScaleMode = 'Dpi'
    $form.StartPosition = 'CenterScreen'
    $form.MinimumSize = New-Object Drawing.Size(1180,880)
    $form.AutoScroll = $true
    $form.Font = New-Object Drawing.Font((Get-LocalizedFontName), 9)

    $header = New-Object Windows.Forms.Label
    $header.Text = $script:AppName
    $header.Font = New-Object Drawing.Font((Get-LocalizedFontName), 13.5, [Drawing.FontStyle]::Bold)
    $header.Location = New-Object Drawing.Point(18, 10)
    $header.Size = New-Object Drawing.Size(700, 36)
    $header.AutoEllipsis = $true
    $header.Anchor = 'Top, Left'
    $form.Controls.Add($header)

    $languageLabel = New-Object Windows.Forms.Label
    $languageLabel.Text = L '语言：' 'Language:'
    $languageLabel.Location = New-Object Drawing.Point(810, 17)
    $languageLabel.Size = New-Object Drawing.Size(140, 26)
    $languageLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $languageLabel.Anchor = 'Top, Right'
    $form.Controls.Add($languageLabel)

    $script:LanguageBox = New-Object Windows.Forms.ComboBox
    $script:LanguageBox.DropDownStyle = 'DropDownList'
    $script:LanguageBox.Items.Add('简体中文') | Out-Null
    $script:LanguageBox.Items.Add('English') | Out-Null
    $script:LanguageBox.Location = New-Object Drawing.Point(960, 13)
    $script:LanguageBox.Anchor = 'Top, Right'
    $script:LanguageBox.Size = New-Object Drawing.Size(170, 30)
    $script:LanguageBox.SelectedIndex = if ($script:Language -eq 'en-US') { 1 } else { 0 }
    $form.Controls.Add($script:LanguageBox)

    $aboutButton = New-Object Windows.Forms.Button
    $aboutButton.Text = L '关于' 'About'
    $aboutButton.Location = New-Object Drawing.Point(1165, 12)
    $aboutButton.Size = New-Object Drawing.Size(92, 32)
    $aboutButton.Anchor = 'Top, Right'
    $aboutButton.Add_Click({ Show-AboutDialog })
    $form.Controls.Add($aboutButton)

    $script:StatusLabel = New-Object Windows.Forms.Label
    $script:StatusLabel.Location = New-Object Drawing.Point(20, 50)
    $script:StatusLabel.Size = New-Object Drawing.Size(1300, 34)
    $script:StatusLabel.Font = New-Object Drawing.Font((Get-LocalizedFontName), 10, [Drawing.FontStyle]::Bold)
    $script:StatusLabel.AutoEllipsis = $true
    $script:StatusLabel.Anchor = 'Top, Left, Right'
    $form.Controls.Add($script:StatusLabel)

    $script:RiskPanel = New-Object Windows.Forms.Panel
    $script:RiskPanel.Location = New-Object Drawing.Point(20, 88)
    $script:RiskPanel.Size = New-Object Drawing.Size(1300, 132)
    $script:RiskPanel.BorderStyle = 'FixedSingle'
    $script:RiskPanel.Anchor = 'Top, Left, Right'
    $form.Controls.Add($script:RiskPanel)

    $script:RiskTitleLabel = New-Object Windows.Forms.Label
    $script:RiskTitleLabel.Location = New-Object Drawing.Point(8, 5)
    $script:RiskTitleLabel.Size = New-Object Drawing.Size(1282, 24)
    $script:RiskTitleLabel.Font = New-Object Drawing.Font((Get-LocalizedFontName), 9.5, [Drawing.FontStyle]::Bold)
    $script:RiskTitleLabel.BackColor = [Drawing.Color]::Transparent
    $script:RiskTitleLabel.Anchor = 'Top, Left, Right'
    $script:RiskPanel.Controls.Add($script:RiskTitleLabel)

    $script:WarningBox = New-Object Windows.Forms.Label
    $script:WarningBox.Location = New-Object Drawing.Point(8, 31)
    $script:WarningBox.Size = New-Object Drawing.Size(1282, 92)
    $script:WarningBox.BackColor = [Drawing.Color]::Transparent
    $script:WarningBox.AutoEllipsis = $false
    $script:WarningBox.AutoSize = $false
    $script:WarningBox.TextAlign = [Drawing.ContentAlignment]::TopLeft
    $script:WarningBox.UseCompatibleTextRendering = $true
    $script:WarningBox.Anchor = 'Top, Bottom, Left, Right'
    $script:RiskPanel.Controls.Add($script:WarningBox)

    $nextPanel = New-Object Windows.Forms.Panel
    $nextPanel.Location = New-Object Drawing.Point(20, 232)
    $nextPanel.Size = New-Object Drawing.Size(1300, 152)
    $nextPanel.BorderStyle = 'FixedSingle'
    $nextPanel.BackColor = [Drawing.Color]::FromArgb(248,249,250)
    $nextPanel.Anchor = 'Top, Left, Right'
    $form.Controls.Add($nextPanel)

    $script:NextActionLabel = New-Object Windows.Forms.Label
    $script:NextActionLabel.Location = New-Object Drawing.Point(14, 10)
    $script:NextActionLabel.Size = New-Object Drawing.Size(880, 66)
    $script:NextActionLabel.Font = New-Object Drawing.Font((Get-LocalizedFontName), 10, [Drawing.FontStyle]::Bold)
    $script:NextActionLabel.AutoEllipsis = $false
    $script:NextActionLabel.UseCompatibleTextRendering = $true
    $script:NextActionLabel.Anchor = 'Top, Left, Right'
    $nextPanel.Controls.Add($script:NextActionLabel)

    $script:ActionBlockReasonLabel = New-Object Windows.Forms.Label
    $script:ActionBlockReasonLabel.Location = New-Object Drawing.Point(14, 80)
    $script:ActionBlockReasonLabel.Size = New-Object Drawing.Size(900, 62)
    $script:ActionBlockReasonLabel.Font = New-Object Drawing.Font((Get-LocalizedFontName), 9, [Drawing.FontStyle]::Bold)
    $script:ActionBlockReasonLabel.ForeColor = [Drawing.Color]::DarkRed
    $script:ActionBlockReasonLabel.AutoEllipsis = $false
    $script:ActionBlockReasonLabel.AutoSize = $false
    $script:ActionBlockReasonLabel.TextAlign = [Drawing.ContentAlignment]::TopLeft
    $script:ActionBlockReasonLabel.UseCompatibleTextRendering = $true
    $script:ActionBlockReasonLabel.Anchor = 'Top, Left, Right'
    $script:ActionBlockReasonLabel.Visible = $false
    $nextPanel.Controls.Add($script:ActionBlockReasonLabel)

    $script:PrimaryButton = New-Object Windows.Forms.Button
    $script:PrimaryButton.Location = New-Object Drawing.Point(955, 20)
    $script:PrimaryButton.Size = New-Object Drawing.Size(310, 54)
    $script:PrimaryButton.Font = New-Object Drawing.Font((Get-LocalizedFontName), 9.5, [Drawing.FontStyle]::Bold)
    $script:PrimaryButton.Anchor = 'Top, Right'
    $nextPanel.Controls.Add($script:PrimaryButton)

    $tabs = New-Object Windows.Forms.TabControl
    $tabs.Location = New-Object Drawing.Point(20, 408)
    $tabs.Size = New-Object Drawing.Size(1300, 408)
    $tabs.Anchor = 'Top, Bottom, Left, Right'
    $form.Controls.Add($tabs)

    $overviewTab = New-Object Windows.Forms.TabPage
    $overviewTab.Text = L '概览与当前操作' 'Overview and current action'
    $tabs.TabPages.Add($overviewTab) | Out-Null

    $detailsTab = New-Object Windows.Forms.TabPage
    $detailsTab.Text = L '详细检测' 'Detailed diagnostics'
    $tabs.TabPages.Add($detailsTab) | Out-Null

    $filesTab = New-Object Windows.Forms.TabPage
    $filesTab.Text = L '日志与文件' 'Logs and files'
    $tabs.TabPages.Add($filesTab) | Out-Null

    $script:OverviewGrid = New-Object Windows.Forms.DataGridView
    $script:OverviewGrid.Location = New-Object Drawing.Point(12, 12)
    $script:OverviewGrid.Size = New-Object Drawing.Size(1258, 246)
    $script:OverviewGrid.AllowUserToAddRows = $false
    $script:OverviewGrid.AllowUserToDeleteRows = $false
    $script:OverviewGrid.ReadOnly = $true
    $script:OverviewGrid.RowHeadersVisible = $false
    $script:OverviewGrid.AutoSizeColumnsMode = 'Fill'
    $script:OverviewGrid.Columns.Add('OverviewItem',(L '关键项目' 'Key item')) | Out-Null
    $script:OverviewGrid.Columns.Add('OverviewValue',(L '当前结果' 'Current result')) | Out-Null
    $script:OverviewGrid.Columns[0].FillWeight = 13
    $script:OverviewGrid.Columns[1].FillWeight = 87
    Set-LockedDataGridViewLayout -Grid $script:OverviewGrid
    $script:OverviewGrid.Anchor = 'Top, Bottom, Left, Right'
    $overviewTab.Controls.Add($script:OverviewGrid)

    $contextTitle = New-Object Windows.Forms.Label
    $contextTitle.Text = L '可用操作' 'Available actions'
    $contextTitle.Location = New-Object Drawing.Point(14, 266)
    $contextTitle.Size = New-Object Drawing.Size(720, 24)
    $contextTitle.Anchor = 'Bottom, Left, Right'
    $overviewTab.Controls.Add($contextTitle)

    $script:ContextActionsPanel = New-Object Windows.Forms.FlowLayoutPanel
    $script:ContextActionsPanel.Location = New-Object Drawing.Point(12, 292)
    $script:ContextActionsPanel.Size = New-Object Drawing.Size(1258, 74)
    $script:ContextActionsPanel.FlowDirection = 'LeftToRight'
    $script:ContextActionsPanel.WrapContents = $false
    $script:ContextActionsPanel.AutoScroll = $true
    $script:ContextActionsPanel.Anchor = 'Bottom, Left, Right'
    $overviewTab.Controls.Add($script:ContextActionsPanel)

    $script:CertificateSourceButton = New-Object Windows.Forms.Button
    $script:CertificateSourceButton.Text = L '在浏览器打开微软证书下载页' 'Open Microsoft certificate download page in browser'
    $script:CertificateSourceButton.Size = New-Object Drawing.Size(250, 46)
    $script:CertificateSourceButton.AutoSize = $true
    $script:CertificateSourceButton.AutoSizeMode = 'GrowAndShrink'
    $script:CertificateSourceButton.MinimumSize = New-Object Drawing.Size(170,46)
    $script:CertificateSourceButton.Padding = New-Object Windows.Forms.Padding(8,0,8,0)
    $script:ContextActionsPanel.Controls.Add($script:CertificateSourceButton)

    $script:CertificateButton = New-Object Windows.Forms.Button
    $script:CertificateButton.Text = L '选择并验证已下载证书' 'Select and validate downloaded certificate'
    $script:CertificateButton.Size = New-Object Drawing.Size(232, 46)
    $script:CertificateButton.AutoSize = $true
    $script:CertificateButton.AutoSizeMode = 'GrowAndShrink'
    $script:CertificateButton.MinimumSize = New-Object Drawing.Size(170,46)
    $script:CertificateButton.Padding = New-Object Windows.Forms.Padding(8,0,8,0)
    $script:ContextActionsPanel.Controls.Add($script:CertificateButton)

    $script:BitLockerButton = New-Object Windows.Forms.Button
    $script:BitLockerButton.Text = L '查看BitLocker/设备加密处理方法' 'Review BitLocker/device encryption'
    $script:BitLockerButton.Size = New-Object Drawing.Size(170, 46)
    $script:BitLockerButton.AutoSize = $true
    $script:BitLockerButton.AutoSizeMode = 'GrowAndShrink'
    $script:BitLockerButton.MinimumSize = New-Object Drawing.Size(170,46)
    $script:BitLockerButton.Padding = New-Object Windows.Forms.Padding(8,0,8,0)
    $script:ContextActionsPanel.Controls.Add($script:BitLockerButton)

    $script:PendingOverrideButton = New-Object Windows.Forms.Button
    $script:PendingOverrideButton.Text = L '忽略待处理重启…' 'Ignore pending restart...'
    $script:PendingOverrideButton.Size = New-Object Drawing.Size(250, 46)
    $script:PendingOverrideButton.AutoSize = $false
    $script:PendingOverrideButton.Padding = New-Object Windows.Forms.Padding(8,0,8,0)
    $script:ContextActionsPanel.Controls.Add($script:PendingOverrideButton)


    $script:DeveloperForceButton = New-Object Windows.Forms.Button
    $script:DeveloperForceButton.Text = L '开发者强制继续…' 'Developer force continue...'
    $script:DeveloperForceButton.Size = New-Object Drawing.Size(250, 46)
    $script:DeveloperForceButton.AutoSize = $false
    $script:DeveloperForceButton.Padding = New-Object Windows.Forms.Padding(8,0,8,0)
    $script:DeveloperForceButton.BackColor = [Drawing.Color]::MistyRose
    $script:DeveloperForceButton.UseVisualStyleBackColor = $false
    $script:ContextActionsPanel.Controls.Add($script:DeveloperForceButton)

    $script:RecoveryImportButton = New-Object Windows.Forms.Button
    $script:RecoveryImportButton.Text = L '恢复未完成的修复流程…' 'Recover an unfinished repair workflow...'
    $script:RecoveryImportButton.Size = New-Object Drawing.Size(252, 46)
    $script:RecoveryImportButton.AutoSize = $true
    $script:RecoveryImportButton.AutoSizeMode = 'GrowAndShrink'
    $script:RecoveryImportButton.MinimumSize = New-Object Drawing.Size(170,46)
    $script:RecoveryImportButton.Padding = New-Object Windows.Forms.Padding(8,0,8,0)
    $script:ContextActionsPanel.Controls.Add($script:RecoveryImportButton)

    $script:RecoveryExportButton = New-Object Windows.Forms.Button
    $script:RecoveryExportButton.Text = L '保存恢复文件…' 'Save recovery file...'
    $script:RecoveryExportButton.Size = New-Object Drawing.Size(225, 46)
    $script:RecoveryExportButton.AutoSize = $true
    $script:RecoveryExportButton.AutoSizeMode = 'GrowAndShrink'
    $script:RecoveryExportButton.MinimumSize = New-Object Drawing.Size(170,46)
    $script:RecoveryExportButton.Padding = New-Object Windows.Forms.Padding(8,0,8,0)
    $script:ContextActionsPanel.Controls.Add($script:RecoveryExportButton)

    $detailsLayout = New-Object Windows.Forms.TableLayoutPanel
    $detailsLayout.Dock = 'Fill'
    $detailsLayout.Padding = New-Object Windows.Forms.Padding(8)
    $detailsLayout.ColumnCount = 2
    $detailsLayout.RowCount = 1
    $detailsLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 41))) | Out-Null
    $detailsLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 59))) | Out-Null
    $detailsLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $detailsTab.Controls.Add($detailsLayout)

    $script:StepsList = New-Object Windows.Forms.ListView
    $script:StepsList.Dock = 'Fill'
    $script:StepsList.Margin = New-Object Windows.Forms.Padding(4)
    $script:StepsList.View = 'Details'
    $script:StepsList.FullRowSelect = $true
    $script:StepsList.GridLines = $true
    $script:StepsList.Columns.Add((L '序号' 'No.'), 42) | Out-Null
    $script:StepsList.Columns.Add((L '环节' 'Step'), 305) | Out-Null
    $script:StepsList.Columns.Add((L '状态' 'Status'), 88) | Out-Null
    Lock-ListViewColumnWidths -ListView $script:StepsList
    $detailsLayout.Controls.Add($script:StepsList, 0, 0)

    $script:Grid = New-Object Windows.Forms.DataGridView
    $script:Grid.Dock = 'Fill'
    $script:Grid.Margin = New-Object Windows.Forms.Padding(4)
    $script:Grid.AllowUserToAddRows = $false
    $script:Grid.AllowUserToDeleteRows = $false
    $script:Grid.ReadOnly = $true
    $script:Grid.RowHeadersVisible = $false
    $script:Grid.AutoSizeColumnsMode = 'Fill'
    $script:Grid.Columns.Add('Item',(L '检测项' 'Check')) | Out-Null
    $script:Grid.Columns.Add('Value',(L '结果' 'Result')) | Out-Null
    $script:Grid.Columns[0].FillWeight = 24
    $script:Grid.Columns[1].FillWeight = 76
    $script:Grid.Columns[0].MinimumWidth = 160
    $script:Grid.Columns[1].MinimumWidth = 360
    Set-LockedDataGridViewLayout -Grid $script:Grid
    $detailsLayout.Controls.Add($script:Grid, 1, 0)

    $script:LogBox = New-Object Windows.Forms.RichTextBox
    $script:LogBox.Location = New-Object Drawing.Point(12, 12)
    $script:LogBox.Size = New-Object Drawing.Size(880, 430)
    $script:LogBox.ReadOnly = $true
    $script:LogBox.Font = New-Object Drawing.Font('Consolas', 9)
    $script:LogBox.BackColor = [Drawing.Color]::WhiteSmoke
    $script:LogBox.Anchor = 'Top, Bottom, Left, Right'
    $filesTab.Controls.Add($script:LogBox)

    $fileInfo = New-Object Windows.Forms.Label
    $fileInfo.Text = L '查看日志、备份位置以及可导出的诊断文件。自动上传：无。' 'Review logs, backup locations, and diagnostic reports.'
    $fileInfo.Location = New-Object Drawing.Point(930, 18)
    $fileInfo.Size = New-Object Drawing.Size(300, 76)
    $fileInfo.Anchor = 'Top, Right'
    $filesTab.Controls.Add($fileInfo)

    $script:CreatedFilesButton = New-Object Windows.Forms.Button
    $script:CreatedFilesButton.Text = L '查看文件与目录' 'View file locations'
    $script:CreatedFilesButton.Location = New-Object Drawing.Point(930, 102)
    $script:CreatedFilesButton.Size = New-Object Drawing.Size(285, 42)
    $script:CreatedFilesButton.Anchor = 'Top, Right'
    $filesTab.Controls.Add($script:CreatedFilesButton)

    $script:OpenLogsButton = New-Object Windows.Forms.Button
    $script:OpenLogsButton.Text = L '打开本次日志目录' 'Open current log folder'
    $script:OpenLogsButton.Location = New-Object Drawing.Point(930, 156)
    $script:OpenLogsButton.Size = New-Object Drawing.Size(285, 42)
    $script:OpenLogsButton.Anchor = 'Top, Right'
    $filesTab.Controls.Add($script:OpenLogsButton)

    $script:OpenBackupButton = New-Object Windows.Forms.Button
    $script:OpenBackupButton.Text = L '打开用户选择的备份目录' 'Open the user-selected backup folder'
    $script:OpenBackupButton.Location = New-Object Drawing.Point(930, 210)
    $script:OpenBackupButton.Size = New-Object Drawing.Size(285, 42)
    $script:OpenBackupButton.Anchor = 'Top, Right'
    $filesTab.Controls.Add($script:OpenBackupButton)

    $script:ExportDiagnosticsButton = New-Object Windows.Forms.Button
    $script:ExportDiagnosticsButton.Text = L '导出诊断报告…' 'Export diagnostic report...'
    $script:ExportDiagnosticsButton.Location = New-Object Drawing.Point(930, 264)
    $script:ExportDiagnosticsButton.Size = New-Object Drawing.Size(285, 42)
    $script:ExportDiagnosticsButton.Anchor = 'Top, Right'
    $filesTab.Controls.Add($script:ExportDiagnosticsButton)


    $refresh = New-Object Windows.Forms.Button
    $refresh.Text = L '重新检测' 'Detect again'
    $refresh.Location = New-Object Drawing.Point(1000, 825)
    $refresh.Size = New-Object Drawing.Size(135, 40)
    $refresh.Anchor = 'Bottom, Right'
    $form.Controls.Add($refresh)

    $exit = New-Object Windows.Forms.Button
    $exit.Text = L '退出软件' 'Exit'
    $exit.Location = New-Object Drawing.Point(1150, 825)
    $exit.Size = New-Object Drawing.Size(135, 40)
    $exit.Anchor = 'Bottom, Right'
    $form.Controls.Add($exit)

    $script:MainToolTip = New-Object Windows.Forms.ToolTip
    $toolTip = $script:MainToolTip
    $toolTip.SetToolTip($script:CertificateSourceButton, (L '使用默认浏览器打开 Microsoft 官方下载页。' 'Opens the official Microsoft download page in the default browser.'))
    $toolTip.SetToolTip($script:RecoveryImportButton, (L '修复中断、记录丢失或只剩部分 Keys 时，用恢复文件或 Default Keys 备份校验并恢复进度。' 'For an interrupted repair, missing records, or partial Keys, use a recovery file or Default Keys backups to check and restore progress.'))
    $toolTip.SetToolTip($script:RecoveryExportButton, (L '保存恢复所需信息，方便以后继续处理中断的流程。文件只在你选择位置后生成。' 'Saves recovery information for a future interrupted repair. Created only after you choose a destination.'))
    $toolTip.SetToolTip($script:ExportDiagnosticsButton, (L '导出本次日志、脱敏状态和错误事件。不包含Default Keys原始备份、BitLocker恢复密钥或个人文件。' 'Exports this session''s logs, sanitized state, and error events. It excludes raw Default Keys backups, BitLocker recovery keys, and personal files.'))

    $primaryAction = { Invoke-PrimaryAction }
    $refreshAction = { Write-UiLog (L '开始手动重新检测。' 'Manual re-detection started.') 'INFO' }
    $certificateAction = { Show-CertificateInfo }
    $bitLockerAction = { Show-BitLockerHandlingInfo }
    $exportAction = { Export-DiagnosticPackage }
    $recoveryImportAction = { Show-AdvancedRecoveryDialog }
    $recoveryExportAction = { Export-RecoveryPackage }

    $script:PrimaryButton.Add_Click({ Invoke-SafeUiAction -Name (L '当前下一步' 'Current next step') -Action $primaryAction })
    $refresh.Add_Click({ Invoke-SafeUiAction -Name (L '手动重新检测' 'Manual re-detection') -Action $refreshAction })
    $script:CertificateSourceButton.Add_Click({ Invoke-SafeUiAction -Name (L '打开微软证书下载页' 'Open Microsoft certificate download page') -Action { Open-TrustedUrl $script:OfficialCertificateUrl } })
    $script:CertificateButton.Add_Click({ Invoke-SafeUiAction -Name (L '证书校验' 'Certificate validation') -Action $certificateAction })
    $script:BitLockerButton.Add_Click({ Invoke-SafeUiAction -Name (L 'BitLocker处理' 'BitLocker handling') -Action $bitLockerAction })
    $script:PendingOverrideButton.Add_Click({ Invoke-SafeUiAction -Name (L '强制忽略待处理重启' 'Force pending-restart override') -Action { Enable-PendingRebootOverride } })
    $script:DeveloperForceButton.Add_Click({ Invoke-SafeUiAction -Name (L '开发者强制继续' 'Developer force continue') -Action { Invoke-DeveloperForceAction } })
    $script:RecoveryImportButton.Add_Click({ Invoke-SafeUiAction -Name (L '中断恢复' 'Interrupted recovery') -Action $recoveryImportAction })
    $script:RecoveryExportButton.Add_Click({ Invoke-SafeUiAction -Name (L '保存恢复文件' 'Save recovery file') -Action $recoveryExportAction })
    $script:CreatedFilesButton.Add_Click({ Show-FileCreationInfo })
    $script:OpenLogsButton.Add_Click({ if ($script:SessionLogRoot -and (Test-Path -LiteralPath $script:SessionLogRoot)) { Start-Process explorer.exe -ArgumentList ('"{0}"' -f $script:SessionLogRoot) } })
    $script:OpenBackupButton.Add_Click({ if ($script:BackupRoot -and (Test-Path -LiteralPath $script:BackupRoot)) { Start-Process explorer.exe -ArgumentList ('"{0}"' -f $script:BackupRoot) } })
    $script:ExportDiagnosticsButton.Add_Click({ Invoke-SafeUiAction -Name (L '导出诊断报告' 'Export diagnostic report') -Action $exportAction })
    $exit.Add_Click({ $form.Close() })

    $languageState = @{ Initialized = $false }
    $script:LanguageBox.Add_SelectedIndexChanged({
        if (-not $languageState.Initialized) { return }
        $newLanguage = if ($script:LanguageBox.SelectedIndex -eq 1) { 'en-US' } else { 'zh-CN' }
        if ($newLanguage -eq $script:Language) { return }
        $languageChangeMessage = L '切换后重新载入主界面，当前进度不变。继续？' 'The main window reloads after the language changes. Current progress is unchanged. Continue?'
        if (Show-ConfirmationWarning -Title (L '切换语言' 'Change language') -Message $languageChangeMessage) {
            $script:RequestedLanguage = $newLanguage
            Save-Settings -BackupRoot $script:BackupRoot -OobeAccepted $true -SelectedLanguage $newLanguage
            $form.Close()
        } else {
            $languageState.Initialized = $false
            $script:LanguageBox.SelectedIndex = if ($script:Language -eq 'en-US') { 1 } else { 0 }
            $languageState.Initialized = $true
        }
    })

    $pulseState = @{ On = $false }
    $script:PrimaryPulseTimer = New-Object Windows.Forms.Timer
    $script:PrimaryPulseTimer.Interval = 650
    $script:PrimaryPulseTimer.Add_Tick({
        if ($script:PrimaryButton.Visible -and $script:PrimaryButton.Enabled) {
            $pulseState.On = -not $pulseState.On
            $script:PrimaryButton.UseVisualStyleBackColor = $false
            $script:PrimaryButton.BackColor = if ($pulseState.On) { [Drawing.Color]::FromArgb(255,220,102) } else { [Drawing.Color]::FromArgb(255,241,179) }
        } else {
            $pulseState.On = $false
            $script:PrimaryButton.UseVisualStyleBackColor = $true
        }
    })
    $script:PrimaryPulseTimer.Start()

    $form.Add_Shown({
        $languageState.Initialized = $true
        if (-not [string]::IsNullOrWhiteSpace($script:TransactionLoadError)) {
            $loadErrorDisplay = if ($script:Language -eq 'en-US') { 'Transaction recovery validation failed. The unfinished transaction is locked. See diagnostics for technical details.' } else { $script:TransactionLoadError }
            Write-UiLog (((L '恢复信息：{0}' 'Recovery information: {0}') -f $loadErrorDisplay)) 'ERROR'
        }
        Resolve-DetectedPostPkReboot
        if ($script:ResumeDetected) { Resolve-ResumeCheckpoint }
        if ($null -ne $script:CurrentTransaction -and $script:CurrentTransaction.Status -ne 'Complete') {
            $pending = [string]$script:CurrentTransaction.PendingOperation
            Write-UiLog ((L '发现未完成进度 {0}。上次待执行或可能中断的步骤：{1}。已进入恢复诊断模式，并以真实 UEFI 状态重建进度。' 'Unfinished progress {0} detected. Last pending or interrupted step: {1}. Recovery diagnostics are active and progress is reconstructed from real UEFI state.') -f $script:CurrentTransaction.TransactionId,$pending) 'WARN'
        }
        Write-UiLog ((L '文件位置：备份根目录={0}，本次日志={1}，状态目录={2}' 'File locations: backup root={0}, session log={1}, state folder={2}') -f $script:BackupRoot,$script:SessionLogRoot,$script:AppDataRoot) 'INFO'
        Refresh-MainUi -Reason 'ApplicationShown'
    })
    $form.Add_FormClosing({
        try { if ($script:PrimaryPulseTimer) { $script:PrimaryPulseTimer.Stop(); $script:PrimaryPulseTimer.Dispose() } } catch {}
        try { Export-DiagnosticSnapshot -State (Get-SystemState) -Reason 'ApplicationClosing' } catch {}
    })
    $form.ShowDialog() | Out-Null
}
try {
    Assert-PackageIntegrity
    $settings = Get-Settings
    if ($Language -ne 'Auto') {
        Set-AppLanguage $Language
    } else {
        Set-AppLanguage ([string]$settings.Language)
    }
    $needOobe = ($settings.OobeVersion -ne $script:OobeVersion)
    if ($needOobe) {
        $selection = Show-Oobe -DefaultBackupRoot $settings.BackupRoot -DefaultLanguage $script:Language
        if ($null -eq $selection) { exit }
        Set-AppLanguage ([string]$selection.Language)
        $script:BackupRoot = [string]$selection.BackupRoot
        Save-Settings -BackupRoot $script:BackupRoot -OobeAccepted $true -SelectedLanguage $script:Language
    } else {
        $script:BackupRoot = $settings.BackupRoot
        if (-not (Test-WritableDirectory $script:BackupRoot)) {
            $selection = Show-Oobe -DefaultBackupRoot (Get-DefaultBackupRoot) -DefaultLanguage $script:Language
            if ($null -eq $selection) { exit }
            Set-AppLanguage ([string]$selection.Language)
            $script:BackupRoot = [string]$selection.BackupRoot
            Save-Settings -BackupRoot $script:BackupRoot -OobeAccepted $true -SelectedLanguage $script:Language
        }
    }
    Start-SessionLog -BackupRoot $script:BackupRoot
    $script:CurrentTransaction = Load-CurrentTransaction
    do {
        $script:RequestedLanguage = $null
        Show-MainForm
        if ($script:RequestedLanguage) {
            Set-AppLanguage $script:RequestedLanguage
            continue
        }
        break
    } while ($true)
} catch {
    $message = $_.Exception.Message
    try {
        if ($script:SessionLogRoot) {
            Add-Content -LiteralPath (Join-Path $script:SessionLogRoot 'fatal-error.txt') -Value ($_ | Out-String) -Encoding UTF8
        }
    } catch {}
    $fatalDisplay = if ($script:Language -eq 'en-US') {
        'A fatal error occurred. Technical details are in fatal-error.txt when a log folder is available.'
    } else {
        "发生致命错误，程序已停止。`r`n`r`n$message"
    }
    [Windows.Forms.MessageBox]::Show($fatalDisplay, $script:AppName, 'OK', 'Error') | Out-Null
} finally {
    try { if ($script:Mutex) { $script:Mutex.ReleaseMutex(); $script:Mutex.Dispose() } } catch {}
}
