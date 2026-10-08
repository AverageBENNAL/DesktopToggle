# Removes Desktop Toggle: stops it, then deletes its startup shortcut, files and saved position.

Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*DesktopToggle.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

$paths = @(
    (Join-Path ([Environment]::GetFolderPath('Startup')) 'Desktop Toggle.lnk'),
    (Join-Path $env:LOCALAPPDATA 'Programs\DesktopToggle'),
    (Join-Path $env:LOCALAPPDATA 'DesktopToggle')
)
foreach ($path in $paths) {
    if (Test-Path $path) { Remove-Item $path -Recurse -Force }
}

Write-Host 'Desktop Toggle removed.'
Write-Host 'If your icons are still hidden: right-click the desktop > View > Show desktop icons.'
