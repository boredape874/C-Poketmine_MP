param(
    [Parameter(Mandatory = $true)]
    [string]$BaseRun,
    [Parameter(Mandatory = $true)]
    [string]$CandidateRun
)

$ErrorActionPreference = "Stop"

function Read-RunSummary([string]$path) {
    $resolved = Resolve-Path $path
    $summaryPath = Join-Path $resolved "run-summary.json"
    if (-not (Test-Path -LiteralPath $summaryPath)) {
        throw "Missing run-summary.json in $resolved"
    }
    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    [pscustomobject]@{
        path = $resolved.Path
        run_name = $summary.run_name
        ready = [bool]$summary.ready
        ready_seconds = $summary.ready_seconds
        fatal_log_matches = $summary.fatal_log_matches
        exit_code = $summary.exit_code
        duration_seconds = $summary.duration_seconds
        max_working_set_mb = $summary.process.max_working_set_mb
        max_private_mb = $summary.process.max_private_mb
        max_threads = $summary.process.max_threads
        max_handles = $summary.process.max_handles
        rak_ping_sent = $summary.rak_ping.sent
        rak_ping_received = $summary.rak_ping.received
        rak_ping_loss_percent = $summary.rak_ping.loss_percent
        rak_ping_latency_avg_ms = $summary.rak_ping.latency_ms_avg
    }
}

$base = Read-RunSummary $BaseRun
$candidate = Read-RunSummary $CandidateRun

function Get-Delta($baseValue, $candidateValue, [int]$digits = 3) {
    if ($baseValue -eq $null -or $candidateValue -eq $null) {
        return $null
    }
    return [math]::Round(([double]$candidateValue - [double]$baseValue), $digits)
}

$readyDelta = Get-Delta $base.ready_seconds $candidate.ready_seconds 3
$workingSetDelta = Get-Delta $base.max_working_set_mb $candidate.max_working_set_mb 3
$privateDelta = Get-Delta $base.max_private_mb $candidate.max_private_mb 3
$threadsDelta = Get-Delta $base.max_threads $candidate.max_threads 0
$handlesDelta = Get-Delta $base.max_handles $candidate.max_handles 0
$rakLossDelta = Get-Delta $base.rak_ping_loss_percent $candidate.rak_ping_loss_percent 3
$rakLatencyDelta = Get-Delta $base.rak_ping_latency_avg_ms $candidate.rak_ping_latency_avg_ms 3

$result = [pscustomobject]@{
    base = $base
    candidate = $candidate
    delta = [pscustomobject]@{
        ready_seconds = $readyDelta
        fatal_log_matches = [int]$candidate.fatal_log_matches - [int]$base.fatal_log_matches
        max_working_set_mb = $workingSetDelta
        max_private_mb = $privateDelta
        max_threads = $threadsDelta
        max_handles = $handlesDelta
        rak_ping_loss_percent = $rakLossDelta
        rak_ping_latency_avg_ms = $rakLatencyDelta
    }
    verdict = if (-not $candidate.ready -or [int]$candidate.fatal_log_matches -gt 0 -or ($candidate.rak_ping_loss_percent -ne $null -and [double]$candidate.rak_ping_loss_percent -gt 0)) { "fail" } elseif (($readyDelta -ne $null -and $readyDelta -gt 2.0) -or ($workingSetDelta -ne $null -and $workingSetDelta -gt 128) -or ($rakLatencyDelta -ne $null -and $rakLatencyDelta -gt 50)) { "warn" } else { "pass" }
}

$outDir = Split-Path -Parent (Resolve-Path $CandidateRun)
$baseName = (Split-Path -Leaf (Resolve-Path $BaseRun))
$candidateName = (Split-Path -Leaf (Resolve-Path $CandidateRun))
$jsonPath = Join-Path $outDir "compare-$baseName-to-$candidateName.json"
$mdPath = Join-Path $outDir "compare-$baseName-to-$candidateName.md"

$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
@"
# Baseline Compare

- Base: $($base.run_name)
- Candidate: $($candidate.run_name)
- Verdict: $($result.verdict)
- Ready delta seconds: $readyDelta
- Fatal delta: $($result.delta.fatal_log_matches)
- Working set delta MB: $workingSetDelta
- Private memory delta MB: $privateDelta
- Threads delta: $threadsDelta
- Handles delta: $handlesDelta
- Rak ping loss delta percent: $rakLossDelta
- Rak ping avg latency delta ms: $rakLatencyDelta
"@ | Set-Content -LiteralPath $mdPath -Encoding UTF8

$result | ConvertTo-Json -Depth 6
