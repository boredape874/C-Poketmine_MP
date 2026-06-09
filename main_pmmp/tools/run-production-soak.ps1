param(
    [int]$Port = 19133,
    [int]$DurationSeconds = 7200,
    [int]$MinimumDurationSeconds = 7200,
    [string]$RunName = "",
    [switch]$RunRakPingBurst,
    [switch]$AcceptLgpl
)

$ErrorActionPreference = "Stop"

if(-not $AcceptLgpl){
    throw "LGPL license acceptance is required. Re-run with -AcceptLgpl after you have accepted the LICENSE in this PMMP directory."
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$evidenceRoot = Join-Path $rootPath "var/perf/production-evidence"
New-Item -ItemType Directory -Force -Path $evidenceRoot | Out-Null
$logRoot = Join-Path $rootPath "var/perf/soak-command-logs"
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null

$profileDir = & (Join-Path $PSScriptRoot "create-400-wild-profile.ps1") -Port $Port
$runName = if($RunName -ne ""){ $RunName }else{ "production-soak-" + (Get-Date -Format "yyyyMMdd-HHmmss") }
$metaPath = Join-Path $logRoot "$runName.meta.json"
[pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    pid = $PID
    root = $rootPath
    port = $Port
    duration_seconds = $DurationSeconds
    minimum_duration_seconds = $MinimumDurationSeconds
    run_name = $runName
    started = $true
    expected_pass_evidence = Join-Path $evidenceRoot "soak.json"
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $metaPath -Encoding UTF8

$baselineParams = @{
    AcceptLgpl = $true
    Port = $Port
    DurationSeconds = $DurationSeconds
    RunName = $runName
    ProfileDir = $profileDir
    RunChunkCacheProbe = $true
}
if($RunRakPingBurst){
    $baselineParams.RunRakPingBurst = $true
    $baselineParams.RakPingCount = 400
    $baselineParams.RakPingTimeoutMs = 2500
    $baselineParams.RakPingBatchSize = 64
}

$baselineDir = & (Join-Path $PSScriptRoot "run-source-baseline.ps1") @baselineParams
$summaryPath = Join-Path $baselineDir "run-summary.json"
if(-not (Test-Path -LiteralPath $summaryPath)){
    throw "Missing soak run summary: $summaryPath"
}
$summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
$failureReasons = New-Object System.Collections.Generic.List[string]
if(-not [bool]$summary.ready){
    $failureReasons.Add("server_not_ready") | Out-Null
}
if([int]$summary.fatal_log_matches -ne 0){
    $failureReasons.Add("fatal_log_matches") | Out-Null
}
if($summary.exit_code -ne $null -and [int]$summary.exit_code -ne 0){
    $failureReasons.Add("nonzero_exit_code") | Out-Null
}
if($DurationSeconds -lt $MinimumDurationSeconds){
    $failureReasons.Add("duration_below_minimum") | Out-Null
}
if($RunRakPingBurst -and $summary.rak_ping -ne $null){
    if([int]$summary.rak_ping.sent -lt 400){
        $failureReasons.Add("rak_ping_sent_below_minimum") | Out-Null
    }
    if([double]$summary.rak_ping.loss_percent -gt 10.0){
        $failureReasons.Add("rak_ping_loss_above_limit") | Out-Null
    }
}elseif($RunRakPingBurst){
    $failureReasons.Add("missing_rak_ping_summary") | Out-Null
}
$passed = $failureReasons.Count -eq 0

$report = [pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    root = $rootPath
    verdict = if($passed){ "pass" }else{ "fail" }
    failure_reasons = @($failureReasons)
    baseline_dir = $baselineDir
    duration_seconds = $DurationSeconds
    minimum_duration_seconds = $MinimumDurationSeconds
    ready = $summary.ready
    ready_seconds = $summary.ready_seconds
    fatal_log_matches = $summary.fatal_log_matches
    exit_code = $summary.exit_code
    process = $summary.process
    rak_ping = $summary.rak_ping
}

$outName = if($passed){ "soak.json" }else{ "soak-last-failed.json" }
$outPath = Join-Path $evidenceRoot $outName
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outPath -Encoding UTF8
$report | ConvertTo-Json -Depth 6
if(-not $passed){
    exit 11
}
