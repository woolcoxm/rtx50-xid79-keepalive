# Shows whether a keep-alive is running, holding the card, and what it last logged.
$ErrorActionPreference = 'SilentlyContinue'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path

$helpers = @(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq 'GpuKeepAlive.exe' -or ($_.Name -match '^pythonw?\.exe$' -and $_.CommandLine -and $_.CommandLine -match 'gpu_keepalive\.py')
})
$helperPids = @($helpers | ForEach-Object { $_.ProcessId })

$raw = (nvidia-smi --query-compute-apps=pid,process_name --format=csv,noheader 2>&1 | Out-String).Trim()
$cardLost = ($LASTEXITCODE -ne 0) -or ($raw -match 'lost|No devices')

if ($helperPids.Count -gt 0) {
    'Keep-alive process: running (' + (($helpers | ForEach-Object { $_.Name + ', pid ' + $_.ProcessId }) -join '; ') + ')'
} else {
    'Keep-alive process: NOT RUNNING. The card is not protected.'
}

if ($cardLost) {
    'Card: NOT ANSWERING. ' + ($raw -replace '\s+', ' ')
} else {
    $listed = @($raw -split "`n" | ForEach-Object { [int](($_ -split ',')[0] -replace '\D', '') } | Where-Object { $_ -gt 0 })
    if ($helperPids.Count -gt 0 -and @($listed | Where-Object { $helperPids -contains $_ }).Count -gt 0) {
        'Card: lists the keep-alive as a running program, so the card is protected.'
    } elseif ($helperPids.Count -gt 0) {
        'Card: answers, but does not list the keep-alive yet (it retries every 5 s; run this again shortly).'
    } else {
        'Card: answers.'
    }
    nvidia-smi --query-gpu=name,power.draw,memory.used --format=csv,noheader 2>&1 | ForEach-Object { 'Card readings: ' + $_.Trim() }
}

foreach ($log in @((Join-Path $dir 'gpu_keepalive.log'), (Join-Path (Split-Path -Parent $dir) 'python\gpu_keepalive.log'))) {
    if (Test-Path $log) {
        'Last log lines (' + $log + '):'
        Get-Content $log -Tail 5 | ForEach-Object { '    ' + $_.TrimStart([char]0xFEFF) }
    }
}
