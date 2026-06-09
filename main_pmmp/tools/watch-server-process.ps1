param(
    [int]$ProcessId = 0,
    [string]$RunDir = "",
    [int]$IntervalMs = 1000,
    [int]$DurationSeconds = 60
)

$ErrorActionPreference = "Stop"

if ($ProcessId -le 0 -and $RunDir -eq "") {
    throw "Provide -ProcessId or -RunDir."
}

$targetPid = $ProcessId
if ($targetPid -le 0) {
    $commandPath = Join-Path (Resolve-Path $RunDir) "command.txt"
    if (-not (Test-Path -LiteralPath $commandPath)) {
        throw "Cannot infer process from RunDir after process exit. Provide -ProcessId for live sampling."
    }
    throw "RunDir inference is reserved for future live runner integration. Provide -ProcessId for now."
}

$outRoot = if ($RunDir -ne "") { Resolve-Path $RunDir } else { Resolve-Path "." }
$csvPath = Join-Path $outRoot "process-samples.csv"
$summaryPath = Join-Path $outRoot "process-summary.json"

"timestamp,pid,cpu_seconds,working_set_mb,private_mb,threads,handles" | Set-Content -LiteralPath $csvPath -Encoding ASCII

$deadline = (Get-Date).AddSeconds($DurationSeconds)
$samples = New-Object System.Collections.Generic.List[object]
while ((Get-Date) -lt $deadline) {
    $process = Get-Process -Id $targetPid -ErrorAction SilentlyContinue
    if ($null -eq $process) {
        break
    }

    $sample = [pscustomobject]@{
        timestamp = (Get-Date).ToString("o")
        pid = $process.Id
        cpu_seconds = [math]::Round($process.CPU, 3)
        working_set_mb = [math]::Round($process.WorkingSet64 / 1MB, 3)
        private_mb = [math]::Round($process.PrivateMemorySize64 / 1MB, 3)
        threads = $process.Threads.Count
        handles = $process.HandleCount
    }
    $samples.Add($sample) | Out-Null
    "$($sample.timestamp),$($sample.pid),$($sample.cpu_seconds),$($sample.working_set_mb),$($sample.private_mb),$($sample.threads),$($sample.handles)" | Add-Content -LiteralPath $csvPath -Encoding ASCII
    Start-Sleep -Milliseconds $IntervalMs
}

$summary = [pscustomobject]@{
    pid = $targetPid
    sample_count = $samples.Count
    max_working_set_mb = if ($samples.Count -gt 0) { ($samples | Measure-Object -Property working_set_mb -Maximum).Maximum } else { $null }
    max_private_mb = if ($samples.Count -gt 0) { ($samples | Measure-Object -Property private_mb -Maximum).Maximum } else { $null }
    max_threads = if ($samples.Count -gt 0) { ($samples | Measure-Object -Property threads -Maximum).Maximum } else { $null }
    max_handles = if ($samples.Count -gt 0) { ($samples | Measure-Object -Property handles -Maximum).Maximum } else { $null }
    csv = $csvPath
}

$summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
$summary | ConvertTo-Json -Depth 4
