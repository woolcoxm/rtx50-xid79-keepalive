# Installs the keep-alive: puts "GPU keep-alive" in your Startup folder and starts it now.
# Run install.cmd (double-click), or:  powershell -ExecutionPolicy Bypass -File install.ps1
param([switch]$NoStart)
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe = Join-Path $dir 'GpuKeepAlive.exe'
if (-not (Test-Path $exe)) {
    'GpuKeepAlive.exe is not next to this script. Build it first with build.cmd.'
    exit 1
}
# A downloaded copy carries a "mark of the web"; removing it lets it start at sign-in without prompts.
Unblock-File -Path $exe -ErrorAction SilentlyContinue

$shell = New-Object -ComObject WScript.Shell
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'GPU keep-alive.lnk'
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $exe
$shortcut.WorkingDirectory = $dir
$shortcut.WindowStyle = 7   # minimised; the program has no window
$shortcut.Description = 'Holds a small CUDA context on the NVIDIA card so it does not drop off the PCIe bus'
$shortcut.Save()
'Startup shortcut: ' + $shortcutPath

if ($NoStart) { return }
if (@(Get-Process -Name GpuKeepAlive -ErrorAction SilentlyContinue).Count -eq 0) {
    Start-Process -FilePath $exe -WorkingDirectory $dir
    'Started the keep-alive.'
} else {
    'The keep-alive is already running.'
}
''
'Check it with status.cmd. The keep-alive must be running before the card gets a heavy load.'
