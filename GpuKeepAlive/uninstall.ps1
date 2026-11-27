# Removes the keep-alive: stops it and deletes the Startup shortcut. The card is no longer protected.
$ErrorActionPreference = 'Continue'
Get-Process -Name GpuKeepAlive -ErrorAction SilentlyContinue | ForEach-Object {
    Stop-Process -Id $_.Id -Force
    'Stopped the keep-alive (pid ' + $_.Id + ').'
}
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'GPU keep-alive.lnk'
if (Test-Path $shortcutPath) {
    $shell = New-Object -ComObject WScript.Shell
    $target = $shell.CreateShortcut($shortcutPath).TargetPath
    if ($target -like '*GpuKeepAlive.exe') {
        Remove-Item $shortcutPath -Force
        'Removed the Startup shortcut.'
    } else {
        'The Startup shortcut "GPU keep-alive" points at something else (' + $target + '); left it alone.'
    }
} else {
    'No Startup shortcut found.'
}
