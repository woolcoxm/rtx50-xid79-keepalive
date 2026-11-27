# Puts "GPU keep-alive" in your Startup folder using Python's window-less pythonw.exe, and starts it now.
# Needs Python 3 for Windows on this PC. No administrator rights needed.
# Run:  powershell -ExecutionPolicy Bypass -File install_keepalive.ps1
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $dir 'gpu_keepalive.py'

$pythonw = $null
$command = Get-Command pythonw.exe -ErrorAction SilentlyContinue
if ($command) { $pythonw = $command.Source }
if (-not $pythonw) {
    $py = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($py) {
        $found = & $py.Source -3 -c 'import sys,os; print(os.path.join(os.path.dirname(sys.executable), "pythonw.exe"))' 2>$null
        if ($LASTEXITCODE -eq 0 -and (Test-Path $found)) { $pythonw = $found }
    }
}
if (-not $pythonw) {
    $found = Get-ChildItem -Path 'C:\Program Files\Python3*\pythonw.exe', "$env:LOCALAPPDATA\Programs\Python\Python3*\pythonw.exe" `
        -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
    if ($found) { $pythonw = $found.FullName }
}
if (-not $pythonw) {
    'pythonw.exe was not found. Install Python 3 from python.org or the Microsoft Store, or use GpuKeepAlive.exe (no Python needed).'
    exit 1
}

$shell = New-Object -ComObject WScript.Shell
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'GPU keep-alive.lnk'
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $pythonw
$shortcut.Arguments = '"' + $script + '"'
$shortcut.WorkingDirectory = $dir
$shortcut.WindowStyle = 7   # minimised; pythonw shows no window anyway
$shortcut.Description = 'Holds a small CUDA context on the NVIDIA card so it does not drop off the PCIe bus'
$shortcut.Save()
'Startup shortcut: ' + $shortcutPath
'  runs: ' + $pythonw + ' "' + $script + '"'

$running = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^pythonw?\.exe$' -and $_.CommandLine -match 'gpu_keepalive\.py' })
if ($running.Count -eq 0) {
    Start-Process -FilePath $pythonw -ArgumentList ('"' + $script + '"') -WorkingDirectory $dir -WindowStyle Hidden
    'Started the keep-alive.'
} else {
    'The keep-alive is already running (pid ' + ($running.ProcessId -join ', ') + ').'
}
''
'Check it with:  python gpu_keepalive.py --status   (or ..\GpuKeepAlive\status.cmd)'
