param(
    [int]$PollSeconds = 60,
    [int]$MaxWaitSeconds = 10800,
    [int]$FastGatePort = 19154,
    [int]$SoakPort = 19155,
    [int]$SoakDurationSeconds = 7200,
    [int]$SoakMinimumDurationSeconds = 7200,
    [switch]$AcceptLgpl,
    [switch]$ForceAfterFailedSoak,
    [switch]$NoExitCode
)

$ErrorActionPreference = "Stop"

if(-not $AcceptLgpl){
    throw "LGPL license acceptance is required. Re-run with -AcceptLgpl after you have accepted the LICENSE in this PMMP directory."
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$evidenceRoot = Join-Path $rootPath "var/perf/production-evidence"
$pipelineLogRoot = Join-Path $rootPath "var/perf/native-promotion-pipeline"
New-Item -ItemType Directory -Force -Path $pipelineLogRoot | Out-Null
$heartbeatPath = Join-Path $pipelineLogRoot "native-promotion-pipeline-heartbeat-last.json"
$startedAt = Get-Date
$waitedSeconds = 0
$checks = New-Object System.Collections.Generic.List[object]

do{
    $soak = & (Join-Path $PSScriptRoot "check-production-soak-status.ps1") | ConvertFrom-Json
    $checks.Add([pscustomobject]@{
        checked_at = (Get-Date).ToString("o")
        run_name = $soak.run_name
        running = $soak.running
        ready = $soak.ready
        elapsed_seconds = $soak.elapsed_seconds
        remaining_seconds = $soak.remaining_seconds
        fatal_log_matches = $soak.fatal_log_matches
    }) | Out-Null
    [pscustomobject]@{
        generated_at = (Get-Date).ToString("o")
        root = $rootPath
        stage = if($soak.running){ "waiting_for_existing_soak" }else{ "existing_soak_stopped" }
        waited_seconds = $waitedSeconds
        wait_progress_percent = if($MaxWaitSeconds -gt 0){ [Math]::Min(100, [Math]::Round(($waitedSeconds / $MaxWaitSeconds) * 100, 2)) }else{ $null }
        max_wait_seconds = $MaxWaitSeconds
        poll_seconds = $PollSeconds
        run_name = $soak.run_name
        running = $soak.running
        ready = $soak.ready
        elapsed_seconds = $soak.elapsed_seconds
        remaining_seconds = $soak.remaining_seconds
        soak_progress_percent = $soak.progress_percent
        expected_complete_at = $soak.expected_complete_at
        fatal_log_matches = $soak.fatal_log_matches
        pass_evidence_matches_run = $soak.pass_evidence_matches_run
        failed_evidence_matches_run = $soak.failed_evidence_matches_run
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $heartbeatPath -Encoding UTF8
    if(-not $soak.running){
        break
    }
    if($waitedSeconds -ge $MaxWaitSeconds){
        [pscustomobject]@{
            completed = $false
            reason = "wait_timeout"
            root = $rootPath
            waited_seconds = $waitedSeconds
            max_wait_seconds = $MaxWaitSeconds
            latest_soak = $soak
            checks = $checks.ToArray()
            next_command = "pmmp-check-production-soak-status.cmd"
        } | ConvertTo-Json -Depth 8
        if(-not $NoExitCode){ exit 9 }
        exit 0
    }
    Start-Sleep -Seconds $PollSeconds
    $waitedSeconds = [int]((Get-Date) - $startedAt).TotalSeconds
}while($true)

$passEvidencePath = Join-Path $evidenceRoot "soak.json"
$failedEvidencePath = Join-Path $evidenceRoot "soak-last-failed.json"
$passEvidence = if(Test-Path -LiteralPath $passEvidencePath){ Get-Content -LiteralPath $passEvidencePath -Raw | ConvertFrom-Json }else{ $null }
$failedEvidence = if(Test-Path -LiteralPath $failedEvidencePath){ Get-Content -LiteralPath $failedEvidencePath -Raw | ConvertFrom-Json }else{ $null }
$passMatchesStoppedSoak = $passEvidence -ne $null -and $passEvidence.baseline_dir -eq $soak.baseline_dir -and $passEvidence.verdict -eq "pass"
$failedMatchesStoppedSoak = $failedEvidence -ne $null -and $failedEvidence.baseline_dir -eq $soak.baseline_dir
$summaryClean = $soak.summary_exists -eq $true -and $soak.ready -eq $true -and $soak.fatal_log_matches -ne $null -and [int]$soak.fatal_log_matches -eq 0 -and ($soak.summary.exit_code -eq $null -or [int]$soak.summary.exit_code -eq 0)
$soakPassed = $passMatchesStoppedSoak -and $summaryClean -and -not $failedMatchesStoppedSoak
[pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    root = $rootPath
    stage = "checking_stopped_soak_pass_evidence"
    waited_seconds = $waitedSeconds
    run_name = $soak.run_name
    pass_evidence_matches_stopped_soak = $passMatchesStoppedSoak
    failed_evidence_matches_stopped_soak = $failedMatchesStoppedSoak
    summary_clean = $summaryClean
    soak_passed = $soakPassed
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $heartbeatPath -Encoding UTF8

if(-not $ForceAfterFailedSoak -and -not $soakPassed){
    [pscustomobject]@{
        completed = $false
        reason = "previous_soak_not_clean_pass"
        root = $rootPath
        waited_seconds = $waitedSeconds
        latest_soak = $soak
        pass_evidence_matches_stopped_soak = $passMatchesStoppedSoak
        failed_evidence_matches_stopped_soak = $failedMatchesStoppedSoak
        summary_clean = $summaryClean
        pass_evidence_path = $passEvidencePath
        failed_evidence_path = $failedEvidencePath
        checks = $checks.ToArray()
        next_command = "pmmp-finalize-production-readiness-after-soak.cmd -NoExitCode"
    } | ConvertTo-Json -Depth 8
    if(-not $NoExitCode){ exit 10 }
    exit 0
}

$promotion = & (Join-Path $PSScriptRoot "promote-staged-native-extension.ps1") | ConvertFrom-Json
[pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    root = $rootPath
    stage = "promotion_completed"
    waited_seconds = $waitedSeconds
    promoted = $promotion.promoted
    copied = $promotion.copied
    staged_sha256 = $promotion.staged_sha256
    after_sha256 = $promotion.after_sha256
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $heartbeatPath -Encoding UTF8
if($promotion.promoted -ne $true){
    [pscustomobject]@{
        completed = $false
        reason = "promotion_failed_or_refused"
        root = $rootPath
        waited_seconds = $waitedSeconds
        latest_soak = $soak
        promotion = $promotion
        checks = $checks.ToArray()
        next_command = "pmmp-promote-staged-native-extension.cmd"
    } | ConvertTo-Json -Depth 8
    if(-not $NoExitCode){ exit 11 }
    exit 0
}

$validation = & (Join-Path $PSScriptRoot "run-post-native-promotion-validation.ps1") `
    -AcceptLgpl `
    -StartSoak `
    -FastGatePort $FastGatePort `
    -SoakPort $SoakPort `
    -SoakDurationSeconds $SoakDurationSeconds `
    -SoakMinimumDurationSeconds $SoakMinimumDurationSeconds `
    -NoExitCode | ConvertFrom-Json
[pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    root = $rootPath
    stage = "post_promotion_validation_started"
    waited_seconds = $waitedSeconds
    validation_started = $validation.started
    validation_reason = $validation.reason
    soak_run_name = if($validation.soak -ne $null){ $validation.soak.run_name }else{ $null }
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $heartbeatPath -Encoding UTF8

$deployment = & (Join-Path $PSScriptRoot "write-production-deployment-status.ps1") -Markdown | ConvertFrom-Json

[pscustomobject]@{
    completed = $validation.started -eq $true
    root = $rootPath
    waited_seconds = $waitedSeconds
    previous_soak = $soak
    promotion = $promotion
    validation = $validation
    deployment_status = [pscustomobject]@{
        status = $deployment.status
        readiness_percent = $deployment.readiness_percent
        next_command_to_run = $deployment.next_command_to_run
        current_soak_validates_staged_native = $deployment.current_soak_validates_staged_native
        post_promotion_validation_required = $deployment.post_promotion_validation_required
    }
    checks = $checks.ToArray()
    next_command = if($validation.started -eq $true -and $validation.soak -ne $null){ "pmmp-check-production-soak-status.cmd -RunName $($validation.soak.run_name)" }else{ $deployment.next_command_to_run }
} | ConvertTo-Json -Depth 10
