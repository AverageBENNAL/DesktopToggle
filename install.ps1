# Installs Desktop Toggle for the current user (no admin needed) and starts it.
# Works both from a downloaded copy of the repo and piped straight from the web.

$ErrorActionPreference = 'Stop'

$repoRaw = 'https://raw.githubusercontent.com/AverageBENNAL/DesktopToggle/main'
$files = 'DesktopToggle.ps1', 'DesktopToggle.vbs'
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\DesktopToggle'

# Stop a running copy so its files can be replaced.
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*DesktopToggle.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

New-Item -ItemType Directory -Force $installDir | Out-Null
foreach ($file in $files) {
    $target = Join-Path $installDir $file
    if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot $file))) {
        Copy-Item (Join-Path $PSScriptRoot $file) $target -Force
    } else {
        Invoke-WebRequest "$repoRaw/$file" -OutFile $target -UseBasicParsing
    }
}

# Start with Windows.
$launcher = Join-Path $installDir 'DesktopToggle.vbs'
$shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut(
    (Join-Path ([Environment]::GetFolderPath('Startup')) 'Desktop Toggle.lnk'))
$shortcut.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'
$shortcut.Arguments = "`"$launcher`""
$shortcut.WorkingDirectory = $installDir
$shortcut.Save()

Start-Process (Join-Path $env:WINDIR 'System32\wscript.exe') "`"$launcher`""

Write-Host "Desktop Toggle installed to $installDir"
Write-Host 'Look for the small round button in the bottom-right corner of your desktop.'
