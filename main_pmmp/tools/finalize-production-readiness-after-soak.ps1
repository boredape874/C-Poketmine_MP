param(
    [string]$GateDir = "",
    [string]$RunName = "",
    [int]$PollSeconds = 60,
    [switch]$Wait,
    [switch]$NoExitCode
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$evidenceRoot = Join-Path $rootPath "var/perf/production-evidence"
$soakEvidence = Join-Path $evidenceRoot "soak.json"

function Resolve-GateDir([string]$InputGateDir){
    if($InputGateDir -eq ""){
        $gatesRoot = Join-Path $rootPath "var/perf/gates"
        $gateCandidates = @(Get-ChildItem -LiteralPath $gatesRoot -Directory -ErrorAction SilentlyContinue |
            Sort-Object -Property Name -Descending)
        $latestGate = $null
        foreach($candidate in $gateCandidates){
            $candidateSummaryPath = Join-Path $candidate.FullName "gate-summary.json"
            if(-not (Test-Path -LiteralPath $candidateSummaryPath)){
                continue
            }
            $candidateSummary = Get-Content -LiteralPath $candidateSummaryPath -Raw | ConvertFrom-Json
            if(
                $candidateSummary.ready -eq $true -and
                [int]$candidateSummary.fatal_log_matches -eq 0 -and
                $candidateSummary.phpstan_exit -ne $null -and
                [int]$candidateSummary.phpstan_exit -eq 0 -and
                $candidateSummary.rak_ping_sent -ne $null -and
                [int]$candidateSummary.rak_ping_sent -ge 400
            ){
                $latestGate = $candidate
                break
            }
        }
        if($null -eq $latestGate -and $gateCandidates.Count -gt 0){
            $latestGate = $gateCandidates[0]
        }
        if($null -eq $latestGate){
            throw "No gate directory found under $gatesRoot"
        }
        return $latestGate.FullName
    }

    if([System.IO.Path]::IsPathRooted($InputGateDir)){
        return (Resolve-Path $InputGateDir).Path
    }

    return (Resolve-Path (Join-Path $rootPath $InputGateDir)).Path
}

$resolvedGate = Resolve-GateDir $GateDir

do{
    $status = & (Join-Path $PSScriptRoot "check-production-soak-status.ps1") -RunName $RunName | ConvertFrom-Json
    if($status.pass_evidence_matches_run -eq $true){
        break
    }
    if($status.running -ne $true){
        break
    }
    if(-not $Wait){
        break
    }
    Start-Sleep -Seconds $PollSeconds
}while($true)

$audit = & (Join-Path $PSScriptRoot "audit-production-readiness.ps1") -GateDir $resolvedGate -Markdown -NoExitCode | ConvertFrom-Json
$summary = & (Join-Path $PSScriptRoot "summarize-production-evidence.ps1") -Markdown | ConvertFrom-Json

$report = [pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    root = $rootPath
    gate_dir = $resolvedGate
    run_name = $status.run_name
    waited = [bool]$Wait
    soak_running = $status.running
    soak_ready = $status.ready
    soak_elapsed_seconds = $status.elapsed_seconds
    soak_remaining_seconds = $status.remaining_seconds
    soak_fatal_log_matches = $status.fatal_log_matches
    soak_pass_evidence_exists = Test-Path -LiteralPath $soakEvidence
    soak_pass_evidence_matches_run = $status.pass_evidence_matches_run
    soak_failed_evidence_matches_run = $status.failed_evidence_matches_run
    production_verdict = $audit.verdict
    readiness_percent = $audit.readiness_percent
    blocker_count = $audit.blocker_count
    warning_count = $audit.warning_count
    audit_path = Join-Path $resolvedGate "production-readiness.json"
    audit_markdown_path = Join-Path $resolvedGate "production-readiness.md"
    evidence_summary_markdown_path = Join-Path $evidenceRoot "production-evidence-summary.md"
    deployment_status_path = Join-Path $evidenceRoot "production-deployment-status.json"
    deployment_status_markdown_path = Join-Path $evidenceRoot "production-deployment-status.md"
    evidence_summary = $summary
}

$outPath = Join-Path $evidenceRoot "production-readiness-finalize-last.json"
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outPath -Encoding UTF8
$deploymentStatus = & (Join-Path $PSScriptRoot "write-production-deployment-status.ps1") -Markdown | ConvertFrom-Json
$report | Add-Member -NotePropertyName deployment_status -NotePropertyValue $deploymentStatus
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $outPath -Encoding UTF8
$report | ConvertTo-Json -Depth 8

if($audit.verdict -eq "not_ready" -and -not $NoExitCode){
    exit 9
}
