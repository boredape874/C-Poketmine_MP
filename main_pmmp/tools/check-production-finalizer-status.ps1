param()

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$watchRoot = Join-Path $rootPath "var/perf/finalizer-watchers"
$evidenceRoot = Join-Path $rootPath "var/perf/production-evidence"
$finalizeReportPath = Join-Path $evidenceRoot "production-readiness-finalize-last.json"

$watchers = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object {
        $_.CommandLine -like "*finalize-production-readiness-after-soak.ps1*" -and
        $_.CommandLine -like "*-Wait*"
    } |
    ForEach-Object {
        [pscustomobject]@{
            pid = $_.ProcessId
            name = $_.Name
            command_line = $_.CommandLine
        }
    })

$latestMeta = $null
if(Test-Path -LiteralPath $watchRoot){
    $latestMetaFile = Get-ChildItem -LiteralPath $watchRoot -Filter "production-finalizer-*.json" -File -ErrorAction SilentlyContinue |
        Sort-Object -Property LastWriteTime -Descending |
        Select-Object -First 1
    if($null -ne $latestMetaFile){
        $latestMeta = Get-Content -LiteralPath $latestMetaFile.FullName -Raw | ConvertFrom-Json
    }
}

$finalizeReport = $null
if(Test-Path -LiteralPath $finalizeReportPath){
    $finalizeReport = Get-Content -LiteralPath $finalizeReportPath -Raw | ConvertFrom-Json
}
$finalizeReportSummary = if($finalizeReport -ne $null){
    [pscustomobject]@{
        generated_at = $finalizeReport.generated_at
        run_name = $finalizeReport.run_name
        waited = $finalizeReport.waited
        soak_running = $finalizeReport.soak_running
        soak_ready = $finalizeReport.soak_ready
        soak_elapsed_seconds = $finalizeReport.soak_elapsed_seconds
        soak_remaining_seconds = $finalizeReport.soak_remaining_seconds
        soak_fatal_log_matches = $finalizeReport.soak_fatal_log_matches
        soak_pass_evidence_exists = $finalizeReport.soak_pass_evidence_exists
        soak_pass_evidence_matches_run = $finalizeReport.soak_pass_evidence_matches_run
        soak_failed_evidence_matches_run = $finalizeReport.soak_failed_evidence_matches_run
        production_verdict = $finalizeReport.production_verdict
        readiness_percent = $finalizeReport.readiness_percent
        blocker_count = $finalizeReport.blocker_count
        warning_count = $finalizeReport.warning_count
        audit_path = $finalizeReport.audit_path
        audit_markdown_path = $finalizeReport.audit_markdown_path
        evidence_summary_markdown_path = $finalizeReport.evidence_summary_markdown_path
        deployment_status_path = $finalizeReport.deployment_status_path
        deployment_status_markdown_path = $finalizeReport.deployment_status_markdown_path
    }
}else{
    $null
}

$soakStatus = $null
try{
    $soakStatus = & (Join-Path $PSScriptRoot "check-production-soak-status.ps1") | ConvertFrom-Json
}catch{
    $soakStatus = $null
}
$soakStatusSummary = if($soakStatus -ne $null){
    [pscustomobject]@{
        run_name = $soakStatus.run_name
        running = $soakStatus.running
        ready = $soakStatus.ready
        elapsed_seconds = $soakStatus.elapsed_seconds
        remaining_seconds = $soakStatus.remaining_seconds
        progress_percent = $soakStatus.progress_percent
        fatal_log_matches = $soakStatus.fatal_log_matches
        pass_evidence_exists = $soakStatus.pass_evidence_exists
        pass_evidence_matches_run = $soakStatus.pass_evidence_matches_run
        failed_evidence_exists = $soakStatus.failed_evidence_exists
        failed_evidence_matches_run = $soakStatus.failed_evidence_matches_run
    }
}else{
    $null
}

$finalizeMatchesCurrentSoak = (
    $soakStatus -ne $null -and
    $finalizeReport -ne $null -and
    $soakStatus.run_name -ne $null -and
    $finalizeReport.run_name -eq $soakStatus.run_name
)
$finalizeIsCompletedPassReport = (
    $finalizeMatchesCurrentSoak -and
    $soakStatus.running -ne $true -and
    $finalizeReport.soak_pass_evidence_matches_run -eq $true -and
    $finalizeReport.production_verdict -ne "not_ready"
)
$finalizeIsStaleForRunningSoak = (
    $finalizeMatchesCurrentSoak -and
    $soakStatus.running -eq $true -and
    $finalizeReport.soak_pass_evidence_matches_run -ne $true
)

$stdoutTail = @()
$stderrTail = @()
if($false -and $latestMeta -ne $null){
    if($latestMeta.stdout -ne $null -and (Test-Path -LiteralPath $latestMeta.stdout)){
        $stdoutTail = @(Get-Content -LiteralPath $latestMeta.stdout -Tail 20)
    }
    if($latestMeta.stderr -ne $null -and (Test-Path -LiteralPath $latestMeta.stderr)){
        $stderrTail = @(Get-Content -LiteralPath $latestMeta.stderr -Tail 20)
    }
}

[pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    root = $rootPath
    watcher_running = $watchers.Count -gt 0
    watcher_count = $watchers.Count
    watchers = $watchers
    latest_watcher_meta = $latestMeta
    soak_status = $soakStatusSummary
    finalize_report_exists = Test-Path -LiteralPath $finalizeReportPath
    finalize_report_path = $finalizeReportPath
    finalize_report = $finalizeReportSummary
    finalize_matches_current_soak = $finalizeMatchesCurrentSoak
    finalize_is_completed_pass_report = $finalizeIsCompletedPassReport
    finalize_is_stale_for_running_soak = $finalizeIsStaleForRunningSoak
    stdout_tail = $stdoutTail
    stderr_tail = $stderrTail
} | ConvertTo-Json -Depth 8
