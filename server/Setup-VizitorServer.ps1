<#
 ═══════════════════════════════════════════════════════════════════════════
  Vizitor — آتیران ویزیتور | نصب خودکار سرور (ویندوز ۱۱ / سرور ۲۰۱۹+)
  Developed by Milano Technical Team, Milad Yaghoobi
  ─────────────────────────────────────────────────────────────────────────
  این اسکریپت به‌صورت خودکار انجام می‌دهد:
    ۱) نصب و راه‌اندازی IIS همراه با CGI/FastCGI
    ۲) نصب PHP 8.3 (نسخهٔ NTS x64) + راه‌اندازی php.ini سبک و مناسب API
    ۳) نصب درایورهای Microsoft SQLSRV برای PHP (+ pdo_sqlsrv)
    ۴) ساخت سایت IIS روی پورت دلخواه + هندر PHP + تنظیمات لازم برای API
       (به‌ویژه httpErrors=PassThrough تا خطاهای JSON توسط IIS بلعیده نشوند)
    ۵) آماده‌سازی SQL Server: فعال‌سازی TCP/IP روی ۱۴۳۳ و احراز هویت Mixed
       (با پشتیبان‌گیری از رجیستری پیش از هر تغییر)
    ۶) ساخت دیتابیس + کاربر SQL با کمترین دسترسی + اجرای اسکریپت‌های ساختار
    ۷) ساخت کاربر ویزیتور و تولید کلید API و نوشتن فایل config.php
    ۸) قواعد فایروال، گواهی HTTPS اختیاری، و تست سرتاسری API

  نمونهٔ اجرا:
    .\Setup-VizitorServer.ps1
    .\Setup-VizitorServer.ps1 -Port 8731 -Https
    .\Setup-VizitorServer.ps1 -OfflinePackagePath D:\VizitorOffline   # نصب بدون اینترنت
    .\Setup-VizitorServer.ps1 -SkipSqlConfiguration -DbHost SRV01     # دیتابیس روی سرور دیگر

  پارامترهای مهم:
    -Port                 پورت سایت (پیش‌فرض 8731 — همین را در اپ وارد کنید)
    -Https                ساخت گواهی خودامضا و بایندینگ HTTPS (پیش‌فرض: HTTP)
    -OfflinePackagePath   پوشه‌ای شامل php-*-nts-Win32-*.zip و Windows_*RTW.zip
    -NoSqlRestart         تغییر تنظیمات SQL بدون ری‌استارت سرویس (برای ساعت کاری)
    -SkipSqlConfiguration اگر SQL Server را دست نمی‌زنیم (دیتابیس روی سرور دیگر است)

  ⚠️ هشدار مهم: این اسکریپت روی سرویس SQL Server در حال کار تغییر تنظیمات
  می‌دهد (TCP/IP و حالت احراز هویت). پیش از هر تغییر، بکاپ .reg گرفته می‌شود و
  سرویس‌های وابسته به‌خاطر سپرده و دوباره بالا آورده می‌شوند؛ اما اگر نرم‌افزار
  حسابداری روی همین سرور در حال استفاده است، اجرای اسکریپت را به بعد از ساعت
  کاری موکول کنید یا از -NoSqlRestart استفاده کنید.
 ═══════════════════════════════════════════════════════════════════════════
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string] $SiteName   = 'Vizitor',
    [int]    $Port       = 8731,
    [switch] $Https,
    [string] $DbHost     = '.',
    [string] $DbName     = 'AtiranVizitor',
    [string] $DbUser     = 'vizitor_app',
    [string] $DbPassword,
    [string] $AppUser     = 'vizitor',
    [string] $AppPassword,
    [string] $ApiKey,
    [string] $PhpPath    = 'C:\PHP',
    [string] $SitePath   = 'C:\inetpub\Vizitor',
    [string] $OfflinePackagePath,
    [switch] $SkipSqlConfiguration,
    [switch] $NoSqlRestart,
    [switch] $SkipFirewall,
    [switch] $Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # سرعت دانلود در ویندوز ۱۱

# ── مسیرها و ثابت‌ها ─────────────────────────────────────────────────────────
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$WebSource   = Join-Path $ScriptDir 'web'
$SqlSource   = Join-Path $ScriptDir 'sql'
$LogDir      = Join-Path $env:ProgramData 'Vizitor'
$BackupDir   = Join-Path $LogDir 'backup'
$Transcript  = Join-Path $LogDir ('setup-{0:yyyyMMdd-HHmmss}.log' -f (Get-Date))
$PhpZipUrls   = @(
    'https://downloads.php.net/~windows/releases/php-8.3.33-nts-Win32-vs16-x64.zip',
    'https://downloads.php.net/~windows/releases/php-8.2.33-nts-Win32-vs16-x64.zip',
    'https://windows.php.net/downloads/releases/php-8.3.33-nts-Win32-vs16-x64.zip'
)
$SqlsrvUrl   = 'https://github.com/microsoft/msphpsql/releases/download/v5.13.3/Windows_5.13.3RTW.zip'

# ── وضعیت نتیجه‌ها (برای گزارش پایان) ────────────────────────────────────────
$Results = [ordered]@{}

# ── توابع نمایش پیشرفت ──────────────────────────────────────────────────────
function Write-Head([string]$Text) {
    Write-Host ''
    Write-Host ('═' * 74) -ForegroundColor DarkGray
    Write-Host ("  $Text") -ForegroundColor Cyan
    Write-Host ('═' * 74) -ForegroundColor DarkGray
}
function Write-Step([string]$Text) { Write-Host ("`n▶ $Text") -ForegroundColor White }
function Write-Ok([string]$Text)   { Write-Host ("  ✔ $Text") -ForegroundColor Green;  Write-Log "OK   $Text" }
function Write-Warn2([string]$Text) { Write-Host ("  ! $Text") -ForegroundColor Yellow; Write-Log "WARN $Text" }
function Write-Bad([string]$Text)  { Write-Host ("  ✘ $Text") -ForegroundColor Red;    Write-Log "FAIL $Text" }
function Write-Info([string]$Text) { Write-Host ("  • $Text") -ForegroundColor Gray }
function Write-Log([string]$Text) {
    try {
        if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
        Add-Content -Path $Transcript -Value ("[{0:HH:mm:ss}] {1}" -f (Get-Date), $Text) -Encoding UTF8
    } catch { }
}

# ── کمک‌های عمومی ───────────────────────────────────────────────────────────
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function New-RandomPassword([int]$Length = 14) {
    # بدون نویسه‌های گیج‌کننده (0/O، 1/l/I) تا تایپ کردنش راحت باشد
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789@#%'
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

function New-RandomApiKey([int]$Length = 40) {
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

function Backup-RegistryKey([string]$Path, [string]$Label) {
    try {
        if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
        $file = Join-Path $BackupDir ("{0}-{1:yyyyMMdd-HHmmss}.reg" -f $Label, (Get-Date))
        $regPath = $Path -replace '^HKLM:', 'HKLM'
        $null = & reg.exe export $regPath $file /y 2>&1
        if (Test-Path $file) { Write-Ok "بکاپ رجیستری: $file"; return $file }
        Write-Warn2 "بکاپ رجیستری ساخته نشد: $regPath"
    } catch {
        Write-Warn2 "خطا در بکاپ رجیستری: $($_.Exception.Message)"
    }
    return $null
}

function Download-File([string[]]$Urls, [string]$Destination, [string]$Label) {
    foreach ($url in $Urls) {
        try {
            Write-Info "دانلود $Label از $url"
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $url -OutFile $Destination -UseBasicParsing -TimeoutSec 300
            if ((Get-Item $Destination).Length -gt 1000) {
                Write-Ok "$Label دانلود شد ($([math]::Round((Get-Item $Destination).Length/1MB,1)) مگابایت)"
                return $true
            }
            Write-Warn2 "فایل دانلودشده کوچک/ناقص است: $url"
        } catch {
            Write-Warn2 "دانلود ناموفق از $url — $($_.Exception.Message)"
        }
    }
    return $false
}

# ── نوشتن فایل متنی UTF-8 بدون BOM (مهم برای config.php و php.ini) ─────────
function Write-Utf8NoBom([string]$Path, [string]$Content) {
    $enc = New-Object System.Text.UTF8Encoding($false)   # $false = بدون BOM
    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

function Add-Utf8NoBom([string]$Path, [string]$Line) {
    $enc  = New-Object System.Text.UTF8Encoding($false)
    $text = if (Test-Path $Path) { [System.IO.File]::ReadAllText($Path, $enc) } else { '' }
    [System.IO.File]::WriteAllText($Path, $text + [Environment]::NewLine + $Line, $enc)
}

# ── ساخت رشتهٔ اتصال SQL (مدیریتی) ─────────────────────────────────────────
function Get-SqlConnectionString([string]$Database, [string]$Server) {
    $base = "Database=$Database;TrustServerCertificate=True;Connect Timeout=15;MultipleActiveResultSets=False"
    if ($script:SqlUseIntegrated) { return "Server=$Server;$base;Integrated Security=True" }
    return "Server=$Server;$base;User Id=$script:SqlAdminUser;Password=$script:SqlAdminPass"
}

# ── اجرای دستورات SQL: اول با sqlcmd، در نبود آن با .NET SqlClient ──────────
# خروجی: متن (برای اسکریپت‌های ساختاری کافی است)
function Invoke-Sql([string]$Query, [string]$Database = 'master', [string]$Server = $null) {
    if (-not $Server) { $Server = $script:SqlServerInstance }

    if ($script:SqlcmdPath) {
        $sqlArgs = @('-S', $Server, '-b', '-f', '65001')
        if ($Database) { $sqlArgs += @('-d', $Database) }
        $sqlArgs += @('-Q', $Query)
        if ($script:SqlUseIntegrated) { $sqlArgs += '-E' }
        else { $sqlArgs += @('-U', $script:SqlAdminUser, '-P', $script:SqlAdminPass) }
        $out = & $script:SqlcmdPath @sqlArgs 2>&1
        if ($LASTEXITCODE -ne 0) { throw "sqlcmd: $($out -join ' ')" }
        return ($out -join "`n")
    }

    $conn = New-Object System.Data.SqlClient.SqlConnection (Get-SqlConnectionString -Database $Database -Server $Server)
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText    = $Query
        $cmd.CommandTimeout = 300
        $reader = $cmd.ExecuteReader()
        $rows = New-Object System.Collections.Generic.List[string]
        while ($reader.Read()) {
            $cells = @()
            for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                $cells += [string]$reader.GetValue($i)
            }
            $rows.Add(($cells -join "`t"))
        }
        $reader.Close()
        return ($rows -join "`n")
    } finally { $conn.Close() }
}

# ── خواندن یک مقدار تک از SQL (مثل نتیجهٔ SELECT 1 یا DB_ID) ────────────────
function Invoke-SqlScalar([string]$Query, [string]$Database = 'master', [string]$Server = $null) {
    if (-not $Server) { $Server = $script:SqlServerInstance }

    if ($script:SqlcmdPath) {
        $sqlArgs = @('-S', $Server, '-b', '-f', '65001', '-h', '-1', '-W')
        if ($Database) { $sqlArgs += @('-d', $Database) }
        $sqlArgs += @('-Q', $Query)
        if ($script:SqlUseIntegrated) { $sqlArgs += '-E' }
        else { $sqlArgs += @('-U', $script:SqlAdminUser, '-P', $script:SqlAdminPass) }
        $out = & $script:SqlcmdPath @sqlArgs 2>&1
        if ($LASTEXITCODE -ne 0) { throw "sqlcmd: $($out -join ' ')" }
        $text = ($out | Where-Object { "$_".Trim().Length -gt 0 } | Select-Object -First 1)
        return "$text".Trim()
    }

    $conn = New-Object System.Data.SqlClient.SqlConnection (Get-SqlConnectionString -Database $Database -Server $Server)
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText    = $Query
        $cmd.CommandTimeout = 300
        $value = $cmd.ExecuteScalar()
        if ($null -eq $value -or $value -is [System.DBNull]) { return '' }
        return ([string]$value).Trim()
    } finally { $conn.Close() }
}

function Invoke-SqlFile([string]$Path) {
    if (-not (Test-Path $Path)) { throw "فایل SQL پیدا نشد: $Path" }
    Write-Info "اجرای $(Split-Path -Leaf $Path)"
    # خواندن با UTF-8 (فارسی سالم بماند) و شکستن روی خطوط GO
    $text   = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $lines  = $text -split "`r?`n"
    $batch  = New-Object System.Collections.Generic.List[string]
    foreach ($line in $lines) {
        if ($line.Trim() -match '^(?i)GO\s*;?\s*$') {
            $sql = ($batch -join "`n").Trim()
            if ($sql.Length -gt 0) { $null = Invoke-Sql -Query $sql -Database $script:TargetDbName }
            $batch.Clear()
        } else {
            $batch.Add($line)
        }
    }
    $sql = ($batch -join "`n").Trim()
    if ($sql.Length -gt 0) { $null = Invoke-Sql -Query $sql -Database $script:TargetDbName }
}

function Get-PhpExe  { return (Join-Path $PhpPath 'php.exe') }
function Get-PhpCgiExe { return (Join-Path $PhpPath 'php-cgi.exe') }

function Get-LocalIpv4 {
    try {
        Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
            Select-Object -ExpandProperty IPAddress
    } catch { @() }
}

function Get-SqlInstances {
    $found = @()
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Microsoft SQL Server\Instance Names\SQL'
    )
    foreach ($root in $roots) {
        if (Test-Path $root) {
            $props = (Get-ItemProperty -Path $root).PSObject.Properties |
                Where-Object { $_.Name -notin @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider') }
            foreach ($p in $props) {
                $found += [pscustomobject]@{ Instance = $p.Name; InstanceId = $p.Value }
            }
        }
    }
    return $found
}

# ═════════════════════════════ ورود ═════════════════════════
if (-not (Test-Admin)) { throw 'این اسکریپت باید با دسترسی Administrator اجرا شود.' }

# اگر کاربر اسکریپت را در PowerShell 7+ اجرا کرده باشد، خودکار به Windows PowerShell
# منتقل می‌شود؛ چون ماژول WebAdministration فقط در PowerShell 5.1 کار می‌کند.
if ($PSVersionTable.PSEdition -eq 'Core') {
    Write-Host ''
    Write-Host '  این اسکریپت با Windows PowerShell 5.1 اجرا می‌شود (ماژول WebAdministration).' -ForegroundColor Yellow
    Write-Host '  انتقال به powershell.exe ...' -ForegroundColor Yellow
    $relaunch = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $MyInvocation.MyCommand.Path))
    $boundParams = @()
    foreach ($p in $PSBoundParameters.GetEnumerator()) {
        if ($p.Value -is [switch]) {
            if ($p.Value.IsPresent) { $boundParams += ('-{0}' -f $p.Key) }
        } else {
            $boundParams += ('-{0}' -f $p.Key)
            $boundParams += ('"{0}"' -f $p.Value)
        }
    }
    $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList ($relaunch + $boundParams) -Wait -PassThru
    exit $proc.ExitCode
}
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

Write-Head 'آتیران ویزیتور — نصب خودکار سرور (IIS + PHP + SQL Server)'
Write-Info "لاگ کامل: $Transcript"
Write-Log '=== شروع نصب ==='

$script:SqlServerInstance = $DbHost
$script:TargetDbName      = $DbName
$script:SqlUseIntegrated  = $true
$script:SqlAdminUser      = $null
$script:SqlAdminPass      = $null

# ═══════════════════════ ۰) پیش‌آماده‌سازی و سنجش محیط ═══════════════════════
Write-Step '۰) سنجش محیط و پیش‌نیازها'

$isServerOs = $false
try {
    $os = Get-CimInstance Win32_OperatingSystem
    $isServerOs = $os.ProductType -ne 1
    Write-Ok "سیستم‌عامل: $($os.Caption) (ساخت $($os.BuildNumber))"
} catch { Write-Warn2 "تشخیص نسخهٔ ویندوز ناموفق بود." }

$script:SqlcmdPath = $null
$candidates = @(
    (Join-Path ${env:ProgramFiles} 'Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE'),
    (Join-Path ${env:ProgramFiles} 'Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn\SQLCMD.EXE'),
    'C:\Program Files\Microsoft SQL Server\110\Tools\Binn\SQLCMD.EXE'
)
foreach ($c in $candidates) { if (Test-Path $c) { $script:SqlcmdPath = $c; break } }
if (-not $script:SqlcmdPath) {
    $cmd = Get-Command sqlcmd.exe -ErrorAction SilentlyContinue
    if ($cmd) { $script:SqlcmdPath = $cmd.Source }
}
if ($script:SqlcmdPath) { Write-Ok "sqlcmd: $script:SqlcmdPath" }
else { Write-Warn2 'sqlcmd پیدا نشد — از کتابخانهٔ .NET برای اجرای دستورات SQL استفاده می‌شود.' }

if (-not $ApiKey) { $ApiKey = New-RandomApiKey }
if (-not $DbPassword) { $DbPassword = New-RandomPassword 16 }
if (-not $AppPassword) { $AppPassword = New-RandomPassword 10 }
Write-Ok "کلید API تولید شد ($($ApiKey.Length) نویسه)"
$Results['کلید API'] = $ApiKey

# ═══════════════════════════════ ۱) IIS ════════════════════════════════════
Write-Step '۱) نصب و آماده‌سازی IIS'

if ($isServerOs) {
    $feat = @('Web-Server', 'Web-Common-Http', 'Web-Static-Content', 'Web-Default-Doc', 'Web-Http-Errors',
              'Web-Http-Logging', 'Web-Request-Monitor', 'Web-CGI', 'Web-Filtering', 'Web-Mgmt-Console')
    $missing = @()
    foreach ($f in $feat) {
        $state = (Get-WindowsFeature -Name $f -ErrorAction SilentlyContinue).InstallState
        if ($state -ne 'Installed') { $missing += $f }
    }
    if ($missing.Count -gt 0) {
        Write-Info ("نصب ویژگی‌های IIS: " + ($missing -join ', '))
        $null = Install-WindowsFeature -Name $missing -IncludeManagementTools
        Write-Ok 'ویژگی‌های IIS نصب شد.'
    } else { Write-Ok 'IIS از قبل نصب است.' }
} else {
    $feat = @('IIS-WebServerRole', 'IIS-WebServer', 'IIS-CommonHttpFeatures', 'IIS-StaticContent',
              'IIS-DefaultDocument', 'IIS-HttpErrors', 'IIS-RequestFiltering', 'IIS-HttpLogging',
              'IIS-CGI', 'IIS-WebServerManagementTools', 'IIS-ManagementConsole')
    $missing = @()
    foreach ($f in $feat) {
        $state = (Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction SilentlyContinue).State
        if ($state -ne 'Enabled') { $missing += $f }
    }
    if ($missing.Count -gt 0) {
        Write-Info ("فعال‌سازی ویژگی‌های IIS: " + ($missing -join ', '))
        foreach ($f in $missing) {
            $null = Enable-WindowsOptionalFeature -Online -FeatureName $f -All -NoRestart
        }
        Write-Ok 'ویژگی‌های IIS فعال شد.'
    } else { Write-Ok 'IIS از قبل فعال است.' }
}

$w3svc = Get-Service -Name W3SVC -ErrorAction SilentlyContinue
if (-not $w3svc) { throw 'سرویس W3SVC پیدا نشد؛ نصب IIS کامل نشده است. سرور را یک‌بار ری‌استارت و اسکریپت را دوباره اجرا کنید.' }
if ($w3svc.Status -ne 'Running') { Start-Service W3SVC; Start-Sleep -Seconds 3 }
Write-Ok "سرویس IIS در حال اجراست (W3SVC)."
$Results['IIS'] = 'نصب و در حال اجرا'

# ═══════════════════════════════ ۲) PHP ════════════════════════════════════
Write-Step '۲) نصب PHP (NTS x64)'

$phpExe = Get-PhpExe
if (Test-Path $phpExe) {
    Write-Ok "PHP از قبل نصب است: $((& $phpExe -r 'echo PHP_VERSION;'))"
} else {
    $zip = $null
    if ($OfflinePackagePath) {
        $zip = Get-ChildItem -Path $OfflinePackagePath -Filter 'php-*-nts-Win32-*.zip' -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
        if ($zip) { Write-Ok "بستهٔ آفلاین PHP: $zip" }
        else { Write-Warn2 "در $OfflinePackagePath فایل php-*-nts-Win32-*.zip پیدا نشد." }
    }
    if (-not $zip) {
        $tmp = Join-Path $env:TEMP 'vizitor-php.zip'
        if (-not (Download-File -Urls $PhpZipUrls -Destination $tmp -Label 'PHP')) {
            throw "دانلود PHP ناموفق بود. فایل php-8.3.*-nts-Win32-vs16-x64.zip را دستی از windows.php.net بگیرید و با -OfflinePackagePath مسیر پوشه را بدهید."
        }
        $zip = $tmp
    }

    if (-not (Test-Path $PhpPath)) { New-Item -ItemType Directory -Path $PhpPath -Force | Out-Null }
    Write-Info "استخراج در $PhpPath"
    Expand-Archive -Path $zip -DestinationPath $PhpPath -Force
    if (-not (Test-Path (Get-PhpExe))) { throw 'استخراج PHP ناموفق بود (php.exe پیدا نشد).' }
    Write-Ok "PHP نصب شد: $((& (Get-PhpExe) -r 'echo PHP_VERSION;'))"
}
$Results['PHP'] = (& (Get-PhpExe) -r 'echo PHP_VERSION;')

# ── php.ini ────────────────────────────────────────────────────────────────
$iniPath = Join-Path $PhpPath 'php.ini'
if (-not (Test-Path $iniPath)) {
    Write-Info 'ساخت php.ini مناسب API'
    $phpIni = @'
; ═══════════════════════════════════════════════════════════════════
;  Vizitor — php.ini تولیدشده توسط Setup-VizitorServer.ps1
; ═══════════════════════════════════════════════════════════════════
[PHP]
extension_dir = "ext"
cgi.fix_pathinfo = 1
fastcgi.impersonate = 1
date.timezone = "Asia/Tehran"
display_errors = Off
log_errors = On
error_log = "C:\PHP\logs\php-error.log"
memory_limit = 256M
max_execution_time = 60
post_max_size = 32M
upload_max_filesize = 24M
default_charset = "UTF-8"
expose_php = Off
session.use_strict_mode = 1
session.cookie_httponly = 1

; ── افزونه‌های لازم برای Vizitor ──────────────────────────────────
; (اگر PHP نسخهٔ ۸.۳.۳۳ باشد نام فایل‌ها به php_sqlsrv_83b_nts_x64.dll تغییر می‌کند؛
;  اسکریپت به‌طور خودکار نام درست را در ادامه به php.ini اضافه می‌کند)
extension=php_sqlsrv_83_nts_x64.dll
extension=php_pdo_sqlsrv_83_nts_x64.dll
extension=mbstring
extension=openssl
extension=curl

; ── apcu اختیاری (اگر فایلش موجود بود) ───────────────────────────
;extension=php_apcu.dll
'@
    Write-Utf8NoBom -Path $iniPath -Content $phpIni
    New-Item -ItemType Directory -Path (Join-Path $PhpPath 'logs') -Force | Out-Null
    Write-Ok "php.ini ساخته شد: $iniPath"
} else {
    Write-Ok "php.ini موجود است: $iniPath"
}

# ═══════════════════════ ۳) درایور SQLSRV برای PHP ════════════════════════
Write-Step '۳) نصب درایور Microsoft SQLSRV برای PHP'

$phpVersion = (& (Get-PhpExe) -r 'echo PHP_VERSION;')
$verTag = ($phpVersion -split '\.')[0] + ($phpVersion -split '\.')[1]      # مثل «83»
Write-Info "PHP $phpVersion → دنبال DLL برای نسخهٔ $verTag"

$extDir = Join-Path $PhpPath 'ext'
if (-not (Test-Path $extDir)) { New-Item -ItemType Directory -Path $extDir -Force | Out-Null }

$needSqlsrv = -not (Get-ChildItem -Path $extDir -Filter "*sqlsrv*$verTag*nts*x64*.dll" -ErrorAction SilentlyContinue)
if ($needSqlsrv) {
    $zip = $null
    if ($OfflinePackagePath) {
        $zip = Get-ChildItem -Path $OfflinePackagePath -Filter 'Windows_*RTW.zip' -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
        if ($zip) { Write-Ok "بستهٔ آفلاین SQLSRV: $zip" }
    }
    if (-not $zip) {
        $tmp = Join-Path $env:TEMP 'vizitor-sqlsrv.zip'
        if (Download-File -Urls @($SqlsrvUrl) -Destination $tmp -Label 'SQLSRV') { $zip = $tmp }
    }
    if (-not $zip) {
        Write-Warn2 'دانلود درایور SQLSRV ناموفق بود. فایل Windows_5.13.3RTW.zip را از صفحهٔ microsoft/msphpsql/releases بگیرید و با -OfflinePackagePath بدهید.'
        Write-Warn2 'بدون این درایور، PHP نمی‌تواند به SQL Server وصل شود.'
    } else {
        $tmpDir = Join-Path $env:TEMP ('vizitor-sqlsrv-' + [guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
        Expand-Archive -Path $zip -DestinationPath $tmpDir -Force
        # انتخاب فایل‌های NTS x64 مربوط به همین نسخهٔ PHP
        $dlls = Get-ChildItem -Path $tmpDir -Recurse -Filter "*.dll" |
            Where-Object { $_.Name -match "^(php_|)(pdo_)?sqlsrv_$verTag.*nts.*x64\.dll$" }
        if (@($dlls).Count -eq 0) {
            # الگوی برخی نسخه‌ها متفاوت است (مثل php_sqlsrv_83_nts.dll)
            $dlls = Get-ChildItem -Path $tmpDir -Recurse -Filter "*.dll" |
                Where-Object { $_.Name -match "sqlsrv" -and $_.Name -match $verTag -and $_.Name -match 'nts' }
        }
        if (@($dlls).Count -eq 0) {
            Write-Warn2 "در بستهٔ SQLSRV فایلی برای PHP $verTag پیدا نشد. محتوای بسته را بررسی کنید."
        } else {
            foreach ($d in $dlls) {
                $target = Join-Path $extDir $d.Name
                Copy-Item -Path $d.FullName -Destination $target -Force
                Write-Ok "کپی شد: $($d.Name)"
            }
        }
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
} else { Write-Ok 'درایور SQLSRV از قبل در ext موجود است.' }

# ── اطمینان از فعال‌بودن خطوط extension در php.ini ─────────────────────────
$iniText = Get-Content -Path $iniPath -Raw
$sqlsrvDlls = Get-ChildItem -Path $extDir -Filter '*sqlsrv*nts*x64*.dll' -ErrorAction SilentlyContinue
foreach ($dll in $sqlsrvDlls) {
    if ($iniText -notmatch [regex]::Escape($dll.Name)) {
        Add-Utf8NoBom -Path $iniPath -Line ("extension=" + $dll.Name)
        Write-Ok "به php.ini اضافه شد: extension=$($dll.Name)"
    }
}

# ── راستی‌آزمایی بارگذاری درایور ───────────────────────────────────────────
$modules = (& (Get-PhpExe) -m) -join "`n"
if ($modules -match 'sqlsrv') { Write-Ok 'درایور sqlsrv در PHP بارگذاری شد.'; $Results['درایور SQLSRV'] = 'نصب و فعال' }
else {
    Write-Warn2 'درایور sqlsrv در فهرست php -m دیده نشد. php.ini و نام DLL را بررسی کنید.'
    $Results['درایور SQLSRV'] = 'نصب نشد — بررسی کنید'
    Add-Content -Path $Transcript -Value 'PHP -m output:' -Encoding UTF8
    Add-Content -Path $Transcript -Value $modules -Encoding UTF8
}

# ═══════════════════════════ ۴) SQL Server ═════════════════════════════════
Write-Step '۴) آماده‌سازی SQL Server'

$instances = @(Get-SqlInstances)
$localInstanceId = $null
if ($instances.Count -gt 0) {
    Write-Ok ("نمونه(های) SQL Server: " + (($instances | ForEach-Object { $_.Instance }) -join ', '))
} else {
    Write-Warn2 'هیچ نمونهٔ SQL Server روی این سرور یافت نشد.'
}

$isLocalDb = ($DbHost -eq '.' -or $DbHost -eq '(local)' -or $DbHost -eq 'localhost' -or $DbHost -eq $env:COMPUTERNAME)
$script:DbHostForApp = $DbHost        # مقداری که در config.php نوشته می‌شود
if ($instances.Count -gt 0 -and $isLocalDb) {
    $picked = $instances | Where-Object { $_.Instance -eq 'MSSQLSERVER' } | Select-Object -First 1
    if (-not $picked) { $picked = $instances[0] }
    $localInstanceId = $picked.InstanceId
    Write-Info "نمونهٔ انتخابی: $($picked.Instance)"
    if ($picked.Instance -ne 'MSSQLSERVER') {
        # نمونهٔ نام‌دار (مثل SQLEXPRESS): اتصال مدیریتی با «SERVER\INSTANCE»
        $script:SqlServerInstance = "$env:COMPUTERNAME\$($picked.Instance)"
        Write-Info "اتصال مدیریتی به نمونهٔ نام‌دار: $script:SqlServerInstance"
        # چون TCP/IP روی پورت ۱۴۳۳ فعال می‌شود، اپ می‌تواند با localhost متصل شود
        $script:DbHostForApp = 'localhost'
    }
}

if ($SkipSqlConfiguration) {
    Write-Warn2 'آماده‌سازی SQL Server با -SkipSqlConfiguration رد شد (تنظیمات دستی لازم است).'
    $Results['SQL Server'] = 'رد شد (SkipSqlConfiguration)'
} elseif (-not $localInstanceId) {
    Write-Warn2 'دیتابیس روی سرور دیگری است یا SQL Server نصب نیست — تنظیمات رجیستری دست‌کاری نشد.'
    Write-Info 'باید روی سرور دیتابیس این‌ها برقرار باشد: TCP/IP فعال، پورت ۱۴۳۳، احراز هویت Mixed Mode، و کاربر SQL برای اپ.'
    $Results['SQL Server'] = 'تنظیم نشد (دیتابیس خارجی)'
} else {
    # ── بکاپ رجیستری پیش از هر تغییر ────────────────────────────────────
    $regRoot = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$localInstanceId"
    $null = Backup-RegistryKey -Path "$regRoot\MSSQLServer\SuperSocketNetLib\Tcp" -Label 'sql-tcp'
    $null = Backup-RegistryKey -Path "$regRoot\MSSQLServer" -Label 'sql-server'

    # ── فعال‌سازی TCP/IP روی پورت ۱۴۳۳ ──────────────────────────────────
    $tcpPath = "$regRoot\MSSQLServer\SuperSocketNetLib\Tcp"
    if (Test-Path $tcpPath) {
        $ipAll = Join-Path $tcpPath 'IPAll'
        if (-not (Test-Path $ipAll)) { $null = New-Item -Path $ipAll -Force }
        Set-ItemProperty -Path $tcpPath -Name 'Enabled' -Value 1 -Type DWord
        Set-ItemProperty -Path $ipAll   -Name 'TcpPort' -Value '1433' -Type String
        Set-ItemProperty -Path $ipAll   -Name 'TcpDynamicPorts' -Value '' -Type String
        Write-Ok 'TCP/IP فعال و پورت ۱۴۳۳ تنظیم شد.'
    } else {
        Write-Warn2 "کلید TCP/IP پیدا نشد: $tcpPath"
    }

    # ── احراز هویت Mixed Mode ───────────────────────────────────────────
    $loginModePath = "$regRoot\MSSQLServer"
    $current = (Get-ItemProperty -Path $loginModePath -Name 'LoginMode' -ErrorAction SilentlyContinue).LoginMode
    if ($current -ne 2) {
        Set-ItemProperty -Path $loginModePath -Name 'LoginMode' -Value 2 -Type DWord
        Write-Ok 'حالت احراز هویت روی Mixed Mode (SQL + Windows) تنظیم شد.'
    } else {
        Write-Ok 'حالت احراز هویت از قبل Mixed Mode است.'
    }

    # ── ری‌استارت سرویس با در نظر گرفتن سرویس‌های وابسته ────────────────
    $serviceName = if ($picked.Instance -eq 'MSSQLSERVER') { 'MSSQLSERVER' } else { "MSSQL`$$($picked.Instance)" }
    $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Warn2 "سرویس $serviceName پیدا نشد." }
    else {
        $dependents = @(Get-Service | Where-Object { $_.DependentServices.Name -contains $serviceName } |
                        Select-Object -ExpandProperty Name)
        if ($dependents.Count -gt 0) { Write-Info ("سرویس‌های وابسته به‌خاطر سپرده شد: " + ($dependents -join ', ')) }

        if ($NoSqlRestart) {
            Write-Warn2 "پارامتر -NoSqlRestart فعال است: تنظیمات اعمال شد ولی سرویس ری‌استارت نشد."
            Write-Info  "برای اعمال، سرویس $serviceName را در زمان مناسب ری‌استارت کنید."
            $Results['SQL Server'] = 'تنظیمات اعمال شد (ری‌استارت دستی لازم است)'
        } else {
            $answer = 'y'
            if (-not $Force) {
                Write-Host ''
                Write-Host '  ⚠️  سرویس SQL Server ری‌استارت می‌شود. اگر نرم‌افزار حسابداری در حال استفاده است،' -ForegroundColor Yellow
                Write-Host '      پاسخ n بدهید و بعد از ساعت کاری با -NoSqlRestart دوباره اجرا کنید.' -ForegroundColor Yellow
                $answer = Read-Host '  ری‌استارت سرویس SQL Server انجام شود؟ (y/n)'
            }
            if ($answer -match '^(y|Y|بله)') {
                Write-Info "توقف سرویس $serviceName ..."
                Stop-Service -Name $serviceName -Force
                Start-Sleep -Seconds 4
                Start-Service -Name $serviceName
                Start-Sleep -Seconds 5
                Write-Ok "سرویس $serviceName ری‌استارت شد."
                foreach ($dep in $dependents) {
                    try { Start-Service -Name $dep; Write-Ok "سرویس وابسته $dep روشن شد." }
                    catch { Write-Warn2 "روشن‌کردن $dep ناموفق: $($_.Exception.Message)" }
                }
                $Results['SQL Server'] = 'TCP/IP و Mixed Mode فعال شد'
            } else {
                Write-Warn2 'ری‌استارت انجام نشد — تغییرات پس از ری‌استارت بعدی اعمال می‌شوند.'
                $Results['SQL Server'] = 'تنظیمات اعمال شد (ری‌استارت نشد)'
            }
        }
    }
}

# ── اتصال مدیریتی ─────────────────────────────────────────────────────────
Write-Info 'آزمون اتصال به SQL Server ...'
$sqlConnected = $false
try {
    $null = Invoke-Sql -Query 'SELECT 1 AS ok' -Database 'master'
    $sqlConnected = $true
    Write-Ok 'اتصال با احراز هویت ویندوز برقرار شد.'
} catch {
    Write-Warn2 "اتصال ویندوزی ناموفق: $($_.Exception.Message)"
    if (-not $Force) {
        Write-Host '  اگر کاربر SQL با دسترسی مدیریتی دارید، همین حالا وارد کنید (خالی = رد کردن):' -ForegroundColor Yellow
        $su = Read-Host '  نام کاربر SQL (مثلاً sa)'
        if ($su) {
            $sp = Read-Host '  رمز کاربر SQL' -AsSecureString
            $script:SqlAdminUser = $su
            $script:SqlAdminPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sp))
            $script:SqlUseIntegrated = $false
            try {
                $null = Invoke-Sql -Query 'SELECT 1 AS ok' -Database 'master'
                $sqlConnected = $true
                Write-Ok 'اتصال با کاربر SQL برقرار شد.'
            } catch { Write-Bad "اتصال با کاربر SQL هم ناموفق بود: $($_.Exception.Message)" }
        }
    }
}

# ═══════════════════════ ۵) دیتابیس، کاربر و اسکریپت‌ها ════════════════════
Write-Step '۵) ساخت دیتابیس و اجرای اسکریپت‌های ساختار'

if ($sqlConnected) {
    try {
        $dbExists = (Invoke-SqlScalar -Query "SELECT CASE WHEN DB_ID(N'$DbName') IS NULL THEN 0 ELSE 1 END" -Database 'master') -eq '1'
        if (-not $dbExists) {
            $null = Invoke-Sql -Query "CREATE DATABASE [$DbName]" -Database 'master'
            Write-Ok "دیتابیس [$DbName] ساخته شد."
        } else { Write-Ok "دیتابیس [$DbName] از قبل وجود دارد." }

        # ── کاربر SQL با کمترین دسترسی ─────────────────────────────────
$safePwd = $DbPassword.Replace("'", "''")
$null = Invoke-Sql -Query "IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$DbUser')
                           CREATE LOGIN [$DbUser] WITH PASSWORD = N'$safePwd', CHECK_POLICY = ON;" -Database 'master'
$null = Invoke-Sql -Query "IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$DbUser')
                           CREATE USER [$DbUser] FOR LOGIN [$DbUser];" -Database $DbName
$null = Invoke-Sql -Query "ALTER ROLE db_datareader ADD MEMBER [$DbUser];
                           ALTER ROLE db_datawriter ADD MEMBER [$DbUser];" -Database $DbName
Write-Ok "کاربر SQL [$DbUser] آماده است (فقط خواندن/نوشتن روی همین دیتابیس)."

# ── در صورت نبود دیتابیس، اسکیما دستی ساخته می‌شود (وقتی 01_schema.sql
#    از ایجاد خودکار پایگاه داده صرف‌نظر کرده باشد) ────────────────────────
$null = Invoke-Sql -Database 'master' -Query @"
IF DB_ID(N'$DbName') IS NULL
BEGIN
    CREATE DATABASE [$DbName];
END
"@

        # ── ساختار و داده نمونه ─────────────────────────────────────────
        Invoke-SqlFile (Join-Path $SqlSource '01_schema.sql')
        Write-Ok 'ساختار جدول‌ها و نماها ساخته شد.'
        Invoke-SqlFile (Join-Path $SqlSource '02_seed.sql')
        Write-Ok 'داده نمونه درج شد (تا زمان اتصال به جداول واقعی آتیران).'

        # ── کاربر ویزیتور (رمز با password_hash تولید می‌شود) ───────────
        $phpExe = Get-PhpExe
        $hashCmd = '$h = password_hash(' + "'" + $AppPassword.Replace("'", "\'") + "'" + ', PASSWORD_DEFAULT); echo $h;'
        $appHash = (& $phpExe -r $hashCmd).Trim()
        if ([string]::IsNullOrWhiteSpace($appHash)) { throw 'تولید هش رمز کاربر ناموفق بود.' }
        $safeHash = $appHash.Replace("'", "''")
        $null = Invoke-Sql -Database $DbName -Query @"
IF NOT EXISTS (SELECT 1 FROM dbo.VizitorUsers WHERE Username = N'$AppUser')
    INSERT dbo.VizitorUsers (Username, PasswordHash, VisitorCode, DisplayName, Role)
    VALUES (N'$AppUser', N'$safeHash', N'VIS-01', N'ویزیتور ۱', N'visitor');
ELSE
    UPDATE dbo.VizitorUsers SET PasswordHash = N'$safeHash', IsActive = 1 WHERE Username = N'$AppUser';
"@
        Write-Ok "کاربر اپ [$AppUser] ساخته/به‌روزرسانی شد."
        $Results['کاربر اپ'] = $AppUser
        $Results['رمز کاربر اپ'] = $AppPassword
        $Results['کاربر دیتابیس'] = $DbUser
        $Results['رمز دیتابیس'] = $DbPassword
        $Results['دیتابیس'] = $DbName
    } catch {
        Write-Bad "خطا در آماده‌سازی دیتابیس: $($_.Exception.Message)"
        Write-Info 'می‌توانید اسکریپت‌های پوشهٔ server\sql را دستی و به‌ترتیب اجرا کنید (راهنمای README).'
    }
} else {
    Write-Warn2 'اتصال به SQL Server برقرار نشد — ساخت دیتابیس رد شد.'
    $Results['دیتابیس'] = 'ساخته نشد (اتصال برقرار نشد)'
}

# ═══════════════════════ ۶) سایت IIS و ساختار پوشه ═════════════════════════
Write-Step '۶) ساخت سایت IIS و کپی فایل‌های وب‌سرویس'

if (-not (Test-Path $SitePath)) { New-Item -ItemType Directory -Path $SitePath -Force | Out-Null }
if (-not (Test-Path $WebSource)) { throw "پوشهٔ وب‌سرویس پیدا نشد: $WebSource" }
Copy-Item -Path (Join-Path $WebSource '*') -Destination $SitePath -Recurse -Force
Write-Ok "فایل‌های وب‌سرویس در $SitePath کپی شد."

# ── config.php با مقادیر واقعی ─────────────────────────────────────────────
$configPath = Join-Path $SitePath 'config.php'
function ConvertTo-PhpString([string]$Value) {
    return $Value.Replace('\', '\\').Replace("'", "\'")
}
$config = @"
<?php
/* تولیدشده توسط Setup-VizitorServer.ps1 — تاریخ: $(Get-Date -Format 'yyyy-MM-dd HH:mm') */
return [
    'db' => [
        'host'                     => '$(ConvertTo-PhpString $script:DbHostForApp)',
        'port'                     => 1433,
        'name'                     => '$(ConvertTo-PhpString $DbName)',
        'user'                     => '$(ConvertTo-PhpString $DbUser)',
        'pass'                     => '$(ConvertTo-PhpString $DbPassword)',
        'encrypt'                  => false,
        'trust_server_certificate' => true,
    ],
    'api_key'     => '$(ConvertTo-PhpString $ApiKey)',
    'api_version' => '1.5.0',
    'timezone'    => 'Asia/Tehran',

    'token_ttl_minutes'     => 720,
    'max_login_attempts'    => 5,
    'login_lockout_minutes' => 15,

    'strict_totals'    => true,
    'decrement_stock'  => false,
    'write_to_erp'     => false,

    'log_requests'     => true,
    'allow_cors_debug' => false,
];
"@
Write-Utf8NoBom -Path $configPath -Content $config   # بدون BOM — وگرنه خروجی JSON اپ خراب می‌شود
Write-Ok 'فایل config.php با کلید API و اتصال دیتابیس نوشته شد.'

# ── ساخت Application Pool و Site ───────────────────────────────────────────
Import-Module WebAdministration -ErrorAction SilentlyContinue
if (-not (Get-Module -Name WebAdministration)) {
    throw 'ماژول WebAdministration بارگذاری نشد. اسکریپت را با Windows PowerShell 5.1 (نه PowerShell 7) اجرا کنید.'
}

# ── Application Pool (همیشه مطمئن می‌شویم وجود دارد) ──────────────────────
if (-not (Test-Path "IIS:\AppPools\$SiteName")) {
    $null = New-WebAppPool -Name $SiteName
    Write-Ok "Application Pool ساخته شد: $SiteName"
} else { Write-Info "Application Pool موجود است: $SiteName" }
foreach ($setting in @(
        @{ Name = 'managedRuntimeVersion'; Value = '' },
        @{ Name = 'enable32BitAppOnWin64';  Value = $false },
        @{ Name = 'startMode';              Value = 'AlwaysRunning' })) {
    try { Set-ItemProperty "IIS:\AppPools\$SiteName" -Name $setting.Name -Value $setting.Value }
    catch { Write-Warn2 "تنظیم $($setting.Name) روی App Pool ناموفق: $($_.Exception.Message)" }
}

# ── Site ───────────────────────────────────────────────────────────────────
$existingSite = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
if ($existingSite) {
    Write-Info "سایت $SiteName موجود است — پیکربندی به‌روزرسانی می‌شود."
    try { Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value $SitePath } catch { Write-Warn2 $_.Exception.Message }
    try { Set-ItemProperty "IIS:\Sites\$SiteName" -Name applicationPool -Value $SiteName } catch { Write-Warn2 $_.Exception.Message }
    $hasBinding = Get-WebBinding -Name $SiteName -Port $Port -ErrorAction SilentlyContinue
    if (-not $hasBinding) {
        $null = New-WebBinding -Name $SiteName -Protocol http -Port $Port -IPAddress '*'
        Write-Ok "بایندینگ HTTP روی پورت $Port اضافه شد."
    } else { Write-Ok "بایندینگ پورت $Port از قبل وجود دارد." }
} else {
    $null = New-Website -Name $SiteName -PhysicalPath $SitePath -ApplicationPool $SiteName `
        -Port $Port -HostHeader '' -Force
    Write-Ok "سایت $SiteName روی پورت $Port ساخته شد."
}
try { Set-ItemProperty "IIS:\Sites\$SiteName" -Name serverAutoStart -Value $true } catch { }

# ── هندر PHP و تنظیمات API در سطح سرور ────────────────────────────────────
$appcmd = Join-Path $env:WINDIR 'system32\inetsrv\appcmd.exe'
$phpCgi = (Get-PhpCgiExe)
if (-not (Test-Path $phpCgi)) { Write-Warn2 "php-cgi.exe پیدا نشد: $phpCgi" }

if (Test-Path $appcmd) {
    # ۱) حذف هندر/تضادهای قبلی با همین نام
    & $appcmd set config /section:handlers "/-[name='Vizitor_PHP']" /commit:apphost 2>$null | Out-Null
    # ۲) ثبت FastCGI برای php-cgi (اگر نبود)
    $fastCgiCheck = & $appcmd list config /section:system.webServer/fastCgi 2>$null
    if ($fastCgiCheck -notmatch [regex]::Escape($phpCgi)) {
        & $appcmd set config /section:system.webServer/fastCgi `
            "/+[fullPath='$phpCgi',arguments='',maxInstances='12',idleTimeout='300',activityTimeout='60',requestTimeout='90',instanceMaxRequests='2000',protocol='NamedPipe',flushNamedPipe='False']" `
            /commit:apphost | Out-Null
        Write-Ok 'FastCGI برای PHP ثبت شد.'
    } else { Write-Ok 'FastCGI از قبل ثبت شده است.' }

    # ۳) متغیر محیطی PHPRC برای PHP
    & $appcmd set config /section:system.webServer/fastCgi `
        "/+[fullPath='$phpCgi'].environmentVariables.[name='PHPRC',value='$PhpPath']" /commit:apphost 2>$null | Out-Null

    # ۴) هندر PHP در سطح سرور
    & $appcmd set config /section:system.webServer/handlers `
        "/+[name='Vizitor_PHP',path='*.php',verb='GET,HEAD,POST,PUT,DELETE,OPTIONS',modules='FastCgiModule',scriptProcessor='$phpCgi',resourceType='Either',requireAccess='Script']" `
        /commit:apphost | Out-Null
    Write-Ok 'هندر PHP برای IIS ثبت شد.'

    # ۵) خطاهای HTTP به‌صورت خام به اپ برگردند (وگرنه اپ HTML خطای IIS می‌گیرد)
    & $appcmd set config /section:system.webServer/httpErrors /existingResponse:PassThrough /commit:apphost | Out-Null
    Write-Ok 'httpErrors روی PassThrough تنظیم شد (خطاها به‌صورت JSON به اپ می‌رسند).'

    # ۶) defaultDocument
    & $appcmd set config /section:system.webServer/defaultDocument /+"files.[value='index.php']" /commit:apphost 2>$null | Out-Null
} else {
    Write-Warn2 "appcmd پیدا نشد؛ هندر PHP را دستی در IIS Manager اضافه کنید (راهنمای README)."
}

# ── دسترسی‌ها ──────────────────────────────────────────────────────────────
try {
    $acl = Get-Acl $SitePath
    foreach ($id in @('IIS_IUSRS', "IIS AppPool\$SiteName")) {
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($id, 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.SetAccessRule($rule)
    }
    Set-Acl -Path $SitePath -AclObject $acl
    Write-Ok 'دسترسی خواندن برای IIS روی پوشهٔ سایت تنظیم شد.'
    $phpAcl = Get-Acl $PhpPath
    $phpAcl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule('IIS_IUSRS', 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow')))
    Set-Acl -Path $PhpPath -AclObject $phpAcl
    Write-Ok 'دسترسی خواندن برای IIS روی پوشهٔ PHP تنظیم شد.'
} catch { Write-Warn2 "تنظیم دسترسی‌ها ناموفق: $($_.Exception.Message)" }

# ── HTTPS اختیاری ─────────────────────────────────────────────────────────
if ($Https) {
    Write-Info 'ساخت گواهی خودامضا و بایندینگ HTTPS'
    try {
        $certName = "Vizitor-$env:COMPUTERNAME"
        $cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -like "*CN=$certName*" } | Select-Object -First 1
        if (-not $cert) {
            $cert = New-SelfSignedCertificate -DnsName @($env:COMPUTERNAME, 'localhost') -CertStoreLocation 'Cert:\LocalMachine\My' `
                -FriendlyName 'Vizitor Web Service' -NotAfter (Get-Date).AddYears(5)
        }
        $cerPath = Join-Path $LogDir "$certName.cer"
        Export-Certificate -Cert $cert -FilePath $cerPath -Force | Out-Null
        $null = New-WebBinding -Name $SiteName -Protocol https -Port $Port -HostHeader '' -SslFlags 0 -ErrorAction SilentlyContinue
        $bind = Get-WebBinding -Name $SiteName -Protocol https -Port $Port
        if ($bind) { $bind.AddSslCertificate($cert.Thumbprint, 'My') }
        Write-Ok "بایندینگ HTTPS روی پورت $Port با گواهی خودامضا ساخته شد."
        Write-Info "فایل گواهی برای نصب روی گوشی‌ها: $cerPath"
        Write-Info 'روی هر گوشی این فایل را نصب کنید (تنظیمات → امنیت → رمزنگاری و اعتبارنامه → نصب گواهی → CA).'
        $Results['HTTPS'] = "فعال (گواهی خودامضا — $cerPath)"
    } catch {
        Write-Bad "ساخت گواهی/بایندینگ HTTPS ناموفق: $($_.Exception.Message)"
        $Results['HTTPS'] = 'ناموفق'
    }
} else {
    Write-Info 'حالت HTTP (بدون گواهی). در اپ، کلید «اتصال امن HTTPS» را خاموش کنید.'
    $Results['HTTPS'] = 'غیرفعال (HTTP)'
}

# ── ری‌استارت IIS ──────────────────────────────────────────────────────────
try { Restart-WebItem "IIS:\Sites\$SiteName" -ErrorAction SilentlyContinue } catch { }
try { $null = iisreset /noforce 2>&1; Write-Ok 'IIS ری‌استارت شد.' } catch { Write-Warn2 'ری‌استارت IIS ناموفق.' }

# ═══════════════════════════ ۷) فایروال ════════════════════════════════════
Write-Step '۷) قواعد فایروال'

if ($SkipFirewall) { Write-Warn2 'تنظیم فایروال رد شد (-SkipFirewall).' }
else {
    try {
        $ruleName = "Vizitor Web Service (TCP $Port)"
        Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
        $null = New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow `
            -Protocol TCP -LocalPort $Port -RemoteAddress LocalSubnet -Profile Any
        Write-Ok "قاعدهٔ فایروال برای پورت $Port (فقط شبکهٔ محلی) ساخته شد."

        # اگر SQL Server روی همین سرور است، پورت ۱۴۳۳ هم برای شبکهٔ محلی باز شود
        if ($localInstanceId) {
            $sqlRuleName = 'Vizitor SQL Server (TCP 1433)'
            Get-NetFirewallRule -DisplayName $sqlRuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
            $null = New-NetFirewallRule -DisplayName $sqlRuleName -Direction Inbound -Action Allow `
                -Protocol TCP -LocalPort 1433 -RemoteAddress LocalSubnet -Profile Any
            Write-Ok 'قاعدهٔ فایروال پورت ۱۴۳۳ (SQL Server) ساخته شد.'
        }
        $Results['فایروال'] = "پورت $Port برای LocalSubnet باز است"
    } catch { Write-Warn2 "تنظیم فایروال ناموفق: $($_.Exception.Message)" }
}

# ═══════════════════════ ۸) تست کد PHP و کل زنجیره ═════════════════════════
Write-Step '۸) تست صحت کد و آزمون سرتاسری API'

$phpExe = Get-PhpExe
$lintErrors = 0
Get-ChildItem -Path $SitePath -Filter '*.php' -Recurse | ForEach-Object {
    $out = & $phpExe -l $_.FullName 2>&1
    if ($LASTEXITCODE -ne 0) { $lintErrors++; Write-Bad "خطای نگارش PHP در $($_.Name): $out" }
}
if ($lintErrors -eq 0) { Write-Ok 'همهٔ فایل‌های PHP بدون خطای نگارشی هستند (php -l).' }
$Results['صحت کد PHP'] = if ($lintErrors -eq 0) { 'بدون خطا' } else { "$lintErrors فایل دارای خطا" }

$scheme = if ($Https) { 'https' } else { 'http' }
$pingUrl = "${scheme}://localhost:$Port/index.php?action=ping"
$apiOk = $false
try {
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $resp = Invoke-RestMethod -Uri $pingUrl -Headers @{ 'X-Api-Key' = $ApiKey } -TimeoutSec 30 `
            -SkipCertificateCheck -ErrorAction Stop
    } else {
        # ویندوز ۱۱ فقط PowerShell 5.1 دارد؛ ابتدا اعتماد موقت به گواهی خودامضا رد می‌شود
        try {
            $resp = Invoke-RestMethod -Uri $pingUrl -Headers @{ 'X-Api-Key' = $ApiKey } -TimeoutSec 30
        } catch {
            Write-Info 'گواهی خودامضا مورد اعتماد نبود؛ آزمون روی http انجام می‌شود.'
            $resp = Invoke-RestMethod -Uri "http://localhost:$Port/index.php?action=ping" `
                -Headers @{ 'X-Api-Key' = $ApiKey } -TimeoutSec 30
        }
    }
    if ($resp.success) {
        $apiOk = $true
        Write-Ok 'آزمون action=ping موفق بود:'
        Write-Info "دیتابیس: $($resp.data.db) | PHP: $($resp.data.php) | نسخهٔ API: $($resp.data.api_version)"
        Write-Info "نسخهٔ SQL Server: $($resp.data.version)"
        if ($resp.data.tables) {
            foreach ($p in $resp.data.tables.PSObject.Properties) {
                $val = if ($null -eq $p.Value) { 'وجود ندارد' } else { "$($p.Value) رکورد" }
                Write-Info ("  • {0}: {1}" -f $p.Name, $val)
            }
        }
        $Results['آزمون ping'] = 'موفق'
    } else {
        Write-Bad "سرور پاسخ موفق نداد: $($resp.message)"
        $Results['آزمون ping'] = "ناموفق: $($resp.message)"
    }
} catch {
    Write-Bad "آزمون ping ناموفق: $($_.Exception.Message)"
    Write-Info 'راهنما: ۱) لاگ PHP در C:\PHP\logs\php-error.log  ۲) لاگ IIS در %SystemDrive%\inetpub\logs\LogFiles'
    $Results['آزمون ping'] = 'ناموفق'
}

# ── آزمون ورود ─────────────────────────────────────────────────────────────
if ($apiOk) {
    try {
        $loginBody = @{ username = $AppUser; password = $AppPassword; device_id = 'setup-script' } | ConvertTo-Json
        $loginUrl = "${scheme}://localhost:$Port/index.php?action=login"
        $loginParams = @{
            Uri         = $loginUrl
            Method      = 'Post'
            Headers     = @{ 'X-Api-Key' = $ApiKey }
            ContentType = 'application/json; charset=utf-8'
            Body        = [System.Text.Encoding]::UTF8.GetBytes($loginBody)
            TimeoutSec  = 30
        }
        if ($PSVersionTable.PSVersion.Major -ge 7) { $loginParams['SkipCertificateCheck'] = $true }
        try { $login = Invoke-RestMethod @loginParams }
        catch {
            if ($Https) {
                $loginParams['Uri'] = "http://localhost:$Port/index.php?action=login"
                $login = Invoke-RestMethod @loginParams
            } else { throw }
        }
        if ($login.success) {
            Write-Ok "آزمون ورود موفق بود (توکن صادر شد؛ انقضا: $($login.data.expires_at) UTC)"
            $Results['آزمون ورود'] = 'موفق'
        } else {
            Write-Bad "ورود ناموفق: $($login.message)"
            $Results['آزمون ورود'] = "ناموفق: $($login.message)"
        }
    } catch { Write-Bad "آزمون ورود با خطا مواجه شد: $($_.Exception.Message)"; $Results['آزمون ورود'] = 'ناموفق' }
}

# ═══════════════════════════ گزارش پایانی ══════════════════════════════════
Write-Head 'گزارش نصب — این مقادیر را در اپ اندروید وارد کنید'

$localIps = @(Get-LocalIpv4)
$serverAddress = if ($localIps.Count -gt 0) { $localIps[0] } else { $env:COMPUTERNAME }

Write-Host ''
Write-Host '  ┌─────────────────────────────────────────────────────────────┐' -ForegroundColor DarkCyan
Write-Host '  │  تنظیمات تب «تنظیمات» در اپ آتیران ویزیتور                  │' -ForegroundColor DarkCyan
Write-Host '  └─────────────────────────────────────────────────────────────┘' -ForegroundColor DarkCyan
Write-Host ("    آدرس سرور (IP)      : {0}" -f $serverAddress) -ForegroundColor White
if ($localIps.Count -gt 1) { Write-Host ("    IP های دیگر این سرور : {0}" -f ($localIps -join ', ')) -ForegroundColor DarkGray }
Write-Host ("    پورت وب‌سرویس        : {0}" -f $Port) -ForegroundColor White
Write-Host ("    اتصال امن (HTTPS)   : {0}" -f $(if ($Https) { 'روشن' } else { 'خاموش' })) -ForegroundColor White
Write-Host ("    کلید API            : {0}" -f $ApiKey) -ForegroundColor Yellow
Write-Host ("    نام کاربری          : {0}" -f $AppUser) -ForegroundColor White
Write-Host ("    رمز عبور            : {0}" -f $AppPassword) -ForegroundColor Yellow
Write-Host ("    آدرس کامل وب‌سرویس   : {0}://{1}:{2}/index.php" -f $scheme, $serverAddress, $Port) -ForegroundColor DarkGray
Write-Host ''

Write-Host '  نتیجهٔ مراحل:' -ForegroundColor Cyan
foreach ($key in $Results.Keys) { Write-Host ("    • {0,-16} : {1}" -f $key, $Results[$key]) -ForegroundColor Gray }

Write-Host ''
Write-Host '  قدم بعدی:' -ForegroundColor Cyan
Write-Host '    ۱) در اپ: تنظیمات → پیکربندی سرور → مقادیر بالا را وارد و «ذخیره پیکربندی» را بزنید.' -ForegroundColor Gray
Write-Host '    ۲) «تست سلامت اتصال» را بزنید؛ باید همهٔ بخش‌ها تیک سبز بگیرند.' -ForegroundColor Gray
Write-Host '    ۳) اگر سرور دیتابیس مجزا دارید، اتصال به جداول واقعی آتیران را با فایل' -ForegroundColor Gray
Write-Host '       server\sql\03_erp_views_template.sql انجام دهید.' -ForegroundColor Gray
Write-Host ''
Write-Host ("  لاگ کامل نصب: {0}" -f $Transcript) -ForegroundColor DarkGray
Write-Host ''

# ── ذخیرهٔ اطلاعات نصب برای مراجعهٔ بعدی ────────────────────────────────────
$infoFile = Join-Path $LogDir 'install-info.txt'
@(
    "تاریخ نصب      : $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    "سرور           : $serverAddress"
    "آدرس وب‌سرویس  : $scheme://$serverAddress`:$Port/index.php"
    "پورت           : $Port"
    "HTTPS          : $Https"
    "کلید API       : $ApiKey"
    "کاربر اپ       : $AppUser"
    "رمز کاربر اپ   : $AppPassword"
    "دیتابیس        : $DbName روی $DbHost"
    "کاربر دیتابیس  : $DbUser"
    "رمز دیتابیس    : $DbPassword"
    "مسیر سایت      : $SitePath"
    "مسیر PHP       : $PhpPath"
) | Set-Content -Path $infoFile -Encoding UTF8
Write-Host ("  📄 خلاصهٔ اطلاعات نصب ذخیره شد: {0}" -f $infoFile) -ForegroundColor DarkGray
Write-Log '=== پایان نصب ==='
