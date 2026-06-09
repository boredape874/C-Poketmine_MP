param(
    [string]$RunsDir = "var/perf/baseline",
    [int]$Limit = 12,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$resolvedRunsDir = Join-Path $root $RunsDir

if (-not (Test-Path -LiteralPath $resolvedRunsDir)) {
    if ($Json) {
        "[]" | Write-Output
    } else {
        Write-Output "No baseline runs found at $resolvedRunsDir"
    }
    exit 0
}

$runs = Get-ChildItem -LiteralPath $resolvedRunsDir -Directory |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First $Limit |
    ForEach-Object {
        $summaryPath = Join-Path $_.FullName "run-summary.json"
        $serverLogPath = Join-Path $_.FullName "data/server.log"
        $stdoutPath = Join-Path $_.FullName "stdout.log"
        $summary = if (Test-Path -LiteralPath $summaryPath) {
            Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
        } else {
            [pscustomobject]@{
                run_name = $_.Name
                ready = $false
                ready_seconds = $null
                fatal_log_matches = $null
                exit_code = $null
                duration_seconds = $null
            }
        }

        $logText = ""
        if (Test-Path -LiteralPath $serverLogPath) {
            $logText = Get-Content -LiteralPath $serverLogPath -Raw
        } elseif (Test-Path -LiteralPath $stdoutPath) {
            $logText = Get-Content -LiteralPath $stdoutPath -Raw
        }

        $warningCount = ([regex]::Matches($logText, "WARNING|WARN|경고", "IgnoreCase")).Count
        $criticalCount = ([regex]::Matches($logText, "CRITICAL|Fatal error|Uncaught|crashed|segfault|segmentation fault", "IgnoreCase")).Count
        $latestTps = $null
        $tpsMatches = [regex]::Matches($logText, "TPS[:=]\s*([0-9]+(?:\.[0-9]+)?)", "IgnoreCase")
        if ($tpsMatches.Count -gt 0) {
            $latestTps = [double]$tpsMatches[$tpsMatches.Count - 1].Groups[1].Value
        }

        [pscustomobject]@{
            run_name = $summary.run_name
            ready = [bool]$summary.ready
            ready_seconds = $summary.ready_seconds
            fatal_log_matches = $summary.fatal_log_matches
            critical_matches = $criticalCount
            warning_matches = $warningCount
            latest_tps = $latestTps
            max_working_set_mb = $summary.process.max_working_set_mb
            max_private_mb = $summary.process.max_private_mb
            max_threads = $summary.process.max_threads
            max_handles = $summary.process.max_handles
            rak_ping = $summary.rak_ping
            exit_code = $summary.exit_code
            duration_seconds = $summary.duration_seconds
            path = $_.FullName
        }
    }

if ($Json) {
    $runs | ConvertTo-Json -Depth 4
} else {
    $runs | Format-Table -AutoSize
}
