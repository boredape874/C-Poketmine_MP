param(
    [switch]$Markdown
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$evidenceRoot = Join-Path $rootPath "var/perf/production-evidence"

$audit = & (Join-Path $PSScriptRoot "audit-production-readiness.ps1") -Markdown -NoExitCode | ConvertFrom-Json
$evidence = & (Join-Path $PSScriptRoot "summarize-production-evidence.ps1") -Markdown | ConvertFrom-Json
$soak = & (Join-Path $PSScriptRoot "check-production-soak-status.ps1") | ConvertFrom-Json
$finalizer = & (Join-Path $PSScriptRoot "check-production-finalizer-status.ps1") | ConvertFrom-Json
$pipeline = & (Join-Path $PSScriptRoot "check-native-promotion-pipeline-status.ps1") | ConvertFrom-Json
$nativeLocalPath = Join-Path $evidenceRoot "native-local-build.json"
$nativeV142Path = Join-Path $evidenceRoot "native-v142-build.json"
$stagedNativeDllPath = Join-Path $rootPath "var/native-build/php_pmmp_perf_ext.dll"
$bundledNativeDllPath = Join-Path $rootPath "bin/php/ext/php_pmmp_perf_ext.dll"
$stagedNativePerformanceGatePath = Join-Path $rootPath "var/perf/native-performance-gate/staged-native-performance-gate-last.json"
$nativeLocal = if(Test-Path -LiteralPath $nativeLocalPath){ Get-Content -LiteralPath $nativeLocalPath -Raw | ConvertFrom-Json }else{ $null }
$nativeV142 = if(Test-Path -LiteralPath $nativeV142Path){ Get-Content -LiteralPath $nativeV142Path -Raw | ConvertFrom-Json }else{ $null }
$stagedNativeHash = if(Test-Path -LiteralPath $stagedNativeDllPath){ (Get-FileHash -LiteralPath $stagedNativeDllPath -Algorithm SHA256).Hash }else{ $null }
$bundledNativeHash = if(Test-Path -LiteralPath $bundledNativeDllPath){ (Get-FileHash -LiteralPath $bundledNativeDllPath -Algorithm SHA256).Hash }else{ $null }
$nativePromotionNeeded = $stagedNativeHash -ne $null -and $bundledNativeHash -ne $null -and $stagedNativeHash -ne $bundledNativeHash
$stagedNativePerformanceGate = $null
if($nativePromotionNeeded){
    try{
        $stagedNativePerformanceGate = & (Join-Path $PSScriptRoot "run-staged-native-performance-gate.ps1") -NoExitCode | ConvertFrom-Json
    }catch{
        $stagedNativePerformanceGate = [pscustomobject]@{
            passed = $false
            error = $_.Exception.Message
        }
    }
}
$postPromotionValidationRequired = $nativePromotionNeeded
$nativePromotionBlockedReason = if(-not $nativePromotionNeeded -and $stagedNativeHash -ne $null -and $bundledNativeHash -ne $null){
    "already_promoted"
}elseif($soak.running -eq $true){
    "production_soak_running"
}elseif($stagedNativeHash -eq $null){
    "missing_staged_dll"
}elseif($bundledNativeHash -eq $null){
    "missing_bundled_dll"
}elseif(-not $nativePromotionNeeded){
    "already_promoted"
}else{
    $null
}

$status = if($audit.verdict -eq "ready"){
    "ready"
}elseif($audit.verdict -eq "ready_with_warnings"){
    "ready_with_warnings"
}elseif($soak.running -eq $true){
    "waiting_for_soak"
}else{
    "not_ready"
}

$blockers = @($audit.findings | Where-Object { $_.level -eq "blocker" })
$warnings = @($audit.findings | Where-Object { $_.level -eq "warn" })
$onlyWaitingForSoak = $blockers.Count -eq 1 -and $blockers[0].key -eq "production.soak" -and $soak.running -eq $true
$expectedPostSoakVerdict = if($audit.verdict -ne "not_ready"){
    $audit.verdict
}elseif($onlyWaitingForSoak -and $warnings.Count -gt 0){
    "ready_with_warnings"
}elseif($onlyWaitingForSoak){
    "ready"
}else{
    "not_ready"
}
$expectedPostSoakReadiness = if($expectedPostSoakVerdict -eq "ready"){
    90
}elseif($expectedPostSoakVerdict -eq "ready_with_warnings"){
    85
}else{
    $audit.readiness_percent
}
$nextActions = New-Object System.Collections.Generic.List[string]
$nextCommandToRun = $null
if($onlyWaitingForSoak){
    $nextActions.Add("Wait for the running 2-hour soak to write soak.json.") | Out-Null
    if($nativePromotionNeeded){
        $nextCommandToRun = "pmmp-run-native-promotion-pipeline.cmd -AcceptLgpl"
        $nextActions.Add("After the soak stops, run pmmp-promote-staged-native-extension.cmd to promote the staged native DLL safely.") | Out-Null
        $nextActions.Add("After native promotion, run pmmp-run-post-native-promotion-validation.cmd -AcceptLgpl -StartSoak to launch a production fast gate, background clean soak, and finalizer watcher for the promoted DLL.") | Out-Null
    }else{
        $nextCommandToRun = "pmmp-check-production-soak-status.cmd"
    }
    $nextActions.Add("After soak completion, inspect production-deployment-status.md and production-readiness-finalize-last.json.") | Out-Null
}
if($warnings | Where-Object { $_.key -eq "production.native_v142" }){
    $toolsetNote = if($nativeLocal -ne $null -and $nativeLocal.toolset_version -ne $null){ " Current local toolset: " + $nativeLocal.toolset_version + "." }else{ "" }
    $nextActions.Add("Build and record VS2019/v142 native extension evidence to clear the remaining native warning." + $toolsetNote) | Out-Null
}
if($audit.verdict -eq "ready" -or $audit.verdict -eq "ready_with_warnings"){
    $nextActions.Add("Run a final staging launch using the exact production plugin/world/network host before public opening.") | Out-Null
    if($nextCommandToRun -eq $null -and $soak.running -eq $true){
        $nextCommandToRun = "pmmp-check-production-soak-status.cmd"
    }elseif($nextCommandToRun -eq $null){
        $nextCommandToRun = "pmmp-run-post-native-promotion-validation.cmd -AcceptLgpl -StartSoak"
    }
}
if(-not $soak.running -and $nativePromotionNeeded -and $nextCommandToRun -eq $null){
    $nextCommandToRun = "pmmp-promote-staged-native-extension.cmd"
}
if(-not $nativePromotionNeeded -and $postPromotionValidationRequired -and $nextCommandToRun -eq $null){
    $nextCommandToRun = "pmmp-run-post-native-promotion-validation.cmd -AcceptLgpl -StartSoak"
}

$report = [pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    root = $rootPath
    status = $status
    verdict = $audit.verdict
    readiness_percent = $audit.readiness_percent
    blocker_count = $audit.blocker_count
    warning_count = $audit.warning_count
    only_waiting_for_soak = $onlyWaitingForSoak
    current_soak_validates_staged_native = -not $nativePromotionNeeded
    post_promotion_validation_required = $postPromotionValidationRequired
    expected_post_soak_verdict_if_clean = $expectedPostSoakVerdict
    expected_post_soak_readiness_if_clean = $expectedPostSoakReadiness
    next_command_to_run = $nextCommandToRun
    next_actions = @($nextActions)
    high_performance_core_ready = $audit.high_performance_core_ready
    gate_name = $audit.gate_name
    blockers = $blockers
    warnings = $warnings
    soak = [pscustomobject]@{
        run_name = $soak.run_name
        running = $soak.running
        ready = $soak.ready
        elapsed_seconds = $soak.elapsed_seconds
        remaining_seconds = $soak.remaining_seconds
        progress_percent = $soak.progress_percent
        expected_complete_at = $soak.expected_complete_at
        fatal_log_matches = $soak.fatal_log_matches
        pass_evidence_exists = $soak.pass_evidence_exists
        pass_evidence_matches_run = $soak.pass_evidence_matches_run
        failed_evidence_exists = $soak.failed_evidence_exists
        failed_evidence_matches_run = $soak.failed_evidence_matches_run
    }
    native_promotion_pipeline = [pscustomobject]@{
        running = $pipeline.running
        process_count = $pipeline.process_count
        latest_name = if($pipeline.latest_meta -ne $null){ $pipeline.latest_meta.name }else{ $null }
        latest_pid = if($pipeline.latest_meta -ne $null){ $pipeline.latest_meta.pid }else{ $null }
        strict_soak_pass_required = if($pipeline.latest_meta -ne $null){ $pipeline.latest_meta.strict_soak_pass_required }else{ $null }
        heartbeat_stage = if($pipeline.latest_heartbeat -ne $null){ $pipeline.latest_heartbeat.stage }else{ $null }
        heartbeat_generated_at = if($pipeline.latest_heartbeat -ne $null){ $pipeline.latest_heartbeat.generated_at }else{ $null }
        heartbeat_waited_seconds = if($pipeline.latest_heartbeat -ne $null){ $pipeline.latest_heartbeat.waited_seconds }else{ $null }
        heartbeat_wait_progress_percent = if($pipeline.latest_heartbeat -ne $null){ $pipeline.latest_heartbeat.wait_progress_percent }else{ $null }
        heartbeat_remaining_seconds = if($pipeline.latest_heartbeat -ne $null){ $pipeline.latest_heartbeat.remaining_seconds }else{ $null }
        heartbeat_soak_progress_percent = if($pipeline.latest_heartbeat -ne $null){ $pipeline.latest_heartbeat.soak_progress_percent }else{ $null }
        stderr_tail = $pipeline.stderr_tail
    }
    finalizer = [pscustomobject]@{
        watcher_running = $finalizer.watcher_running
        watcher_count = $finalizer.watcher_count
        finalize_matches_current_soak = $finalizer.finalize_matches_current_soak
        finalize_is_completed_pass_report = $finalizer.finalize_is_completed_pass_report
        finalize_is_stale_for_running_soak = $finalizer.finalize_is_stale_for_running_soak
    }
    native = [pscustomobject]@{
        v142_evidence_exists = $nativeV142 -ne $null
        local_evidence_exists = $nativeLocal -ne $null
        local_verdict = if($nativeLocal -ne $null){ $nativeLocal.verdict }else{ $null }
        local_toolset_version = if($nativeLocal -ne $null){ $nativeLocal.toolset_version }else{ $null }
        local_build_ready = if($nativeLocal -ne $null){ $nativeLocal.build_ready }else{ $null }
        bundled_dll_exists = Test-Path -LiteralPath $bundledNativeDllPath
        bundled_dll_sha256 = $bundledNativeHash
        staged_dll_path = $stagedNativeDllPath
        staged_dll_exists = Test-Path -LiteralPath $stagedNativeDllPath
        staged_dll_sha256 = $stagedNativeHash
        live_bundled_dll_path = $bundledNativeDllPath
        live_bundled_dll_exists = Test-Path -LiteralPath $bundledNativeDllPath
        live_bundled_dll_sha256 = $bundledNativeHash
        staged_matches_live_bundled = $stagedNativeHash -ne $null -and $bundledNativeHash -ne $null -and $stagedNativeHash -eq $bundledNativeHash
        promotion_needed = $nativePromotionNeeded
        promotion_blocked_reason = $nativePromotionBlockedReason
        staged_performance_gate_ran = $stagedNativePerformanceGate -ne $null
        staged_performance_gate_passed = if($stagedNativePerformanceGate -ne $null){ $stagedNativePerformanceGate.passed }else{ $null }
        staged_performance_gate_metrics = if($stagedNativePerformanceGate -ne $null){ $stagedNativePerformanceGate.metrics }else{ $null }
        staged_performance_gate_failures = if($stagedNativePerformanceGate -ne $null){ $stagedNativePerformanceGate.failures }else{ $null }
        staged_performance_gate_error = if($stagedNativePerformanceGate -ne $null -and $stagedNativePerformanceGate.PSObject.Properties.Name -contains "error"){ $stagedNativePerformanceGate.error }else{ $null }
        staged_performance_gate_evidence_path = $stagedNativePerformanceGatePath
        staged_performance_gate_generated_at = if($stagedNativePerformanceGate -ne $null -and $stagedNativePerformanceGate.PSObject.Properties.Name -contains "generated_at"){ $stagedNativePerformanceGate.generated_at }else{ $null }
        staged_performance_gate_metric_policy = if($stagedNativePerformanceGate -ne $null -and $stagedNativePerformanceGate.PSObject.Properties.Name -contains "metric_policy"){ $stagedNativePerformanceGate.metric_policy }else{ $null }
        staged_performance_gate_samples_run = if($stagedNativePerformanceGate -ne $null -and $stagedNativePerformanceGate.PSObject.Properties.Name -contains "samples_run"){ $stagedNativePerformanceGate.samples_run }else{ $null }
        current_soak_validates_this_dll = -not $nativePromotionNeeded
        post_promotion_fast_gate_required = $postPromotionValidationRequired
        post_promotion_soak_required = $postPromotionValidationRequired
        post_promotion_default_fast_gate_port = 19154
        post_promotion_default_soak_port = 19155
        promotion_command = "pmmp-promote-staged-native-extension.cmd"
        post_promotion_validation_command = "pmmp-run-post-native-promotion-validation.cmd -AcceptLgpl -StartSoak"
        v142_evidence_path = $nativeV142Path
        local_evidence_path = $nativeLocalPath
    }
    evidence = $evidence
}

if($Markdown){
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# PMMP production deployment status") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add(('- Generated: `{0}`' -f $report.generated_at)) | Out-Null
    $lines.Add(('- Status: `{0}`' -f $report.status)) | Out-Null
    $lines.Add(('- Verdict/readiness: `{0}` / `{1}%`' -f $report.verdict, $report.readiness_percent)) | Out-Null
    $lines.Add(('- Blockers/warnings: `{0}` / `{1}`' -f $report.blocker_count, $report.warning_count)) | Out-Null
    $lines.Add(('- Only waiting for soak: `{0}`' -f $report.only_waiting_for_soak)) | Out-Null
    $lines.Add(('- Current soak validates staged native: `{0}`' -f $report.current_soak_validates_staged_native)) | Out-Null
    $lines.Add(('- Post-promotion validation required: `{0}`' -f $report.post_promotion_validation_required)) | Out-Null
    $lines.Add(('- Expected post-soak verdict/readiness if clean: `{0}` / `{1}%`' -f $report.expected_post_soak_verdict_if_clean, $report.expected_post_soak_readiness_if_clean)) | Out-Null
    $lines.Add(('- Next command to run: `{0}`' -f $report.next_command_to_run)) | Out-Null
    $lines.Add(('- Latest gate: `{0}`' -f $report.gate_name)) | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## Next actions") | Out-Null
    if($report.next_actions.Count -eq 0){
        $lines.Add("- None.") | Out-Null
    }else{
        foreach($action in $report.next_actions){
            $lines.Add(("- {0}" -f $action)) | Out-Null
        }
    }
    $lines.Add("") | Out-Null
    $lines.Add("## Soak") | Out-Null
    $lines.Add(('- Run name: `{0}`' -f $report.soak.run_name)) | Out-Null
    $lines.Add(('- Running/ready/pass evidence: `{0}` / `{1}` / `{2}`' -f $report.soak.running, $report.soak.ready, $report.soak.pass_evidence_exists)) | Out-Null
    $lines.Add(('- Pass/failed evidence matches this run: `{0}` / `{1}`' -f $report.soak.pass_evidence_matches_run, $report.soak.failed_evidence_matches_run)) | Out-Null
    $lines.Add(('- Elapsed/remaining seconds: `{0}` / `{1}`' -f $report.soak.elapsed_seconds, $report.soak.remaining_seconds)) | Out-Null
    $lines.Add(('- Progress: `{0}%`' -f $report.soak.progress_percent)) | Out-Null
    $lines.Add(('- Expected complete at: `{0}`' -f $report.soak.expected_complete_at)) | Out-Null
    $lines.Add(('- Fatal matches: `{0}`' -f $report.soak.fatal_log_matches)) | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## Finalizer") | Out-Null
    $lines.Add(('- Watcher running/count: `{0}` / `{1}`' -f $report.finalizer.watcher_running, $report.finalizer.watcher_count)) | Out-Null
    $lines.Add(('- Completed pass report: `{0}`' -f $report.finalizer.finalize_is_completed_pass_report)) | Out-Null
    $lines.Add(('- Stale for running soak: `{0}`' -f $report.finalizer.finalize_is_stale_for_running_soak)) | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## Native") | Out-Null
    $lines.Add(('- v142 evidence exists: `{0}`' -f $report.native.v142_evidence_exists)) | Out-Null
    $lines.Add(('- local evidence/verdict: `{0}` / `{1}`' -f $report.native.local_evidence_exists, $report.native.local_verdict)) | Out-Null
    $lines.Add(('- local toolset/build ready: `{0}` / `{1}`' -f $report.native.local_toolset_version, $report.native.local_build_ready)) | Out-Null
    $lines.Add(('- bundled DLL exists: `{0}`' -f $report.native.bundled_dll_exists)) | Out-Null
    $lines.Add(('- staged/live bundled SHA256: `{0}` / `{1}`' -f $report.native.staged_dll_sha256, $report.native.live_bundled_dll_sha256)) | Out-Null
    $lines.Add(('- staged matches live bundled: `{0}`' -f $report.native.staged_matches_live_bundled)) | Out-Null
    $lines.Add(('- promotion needed: `{0}`' -f $report.native.promotion_needed)) | Out-Null
    $lines.Add(('- promotion blocked reason: `{0}`' -f $report.native.promotion_blocked_reason)) | Out-Null
    $lines.Add(('- staged performance gate ran/passed: `{0}` / `{1}`' -f $report.native.staged_performance_gate_ran, $report.native.staged_performance_gate_passed)) | Out-Null
    $lines.Add(('- staged performance gate generated/policy/samples: `{0}` / `{1}` / `{2}`' -f $report.native.staged_performance_gate_generated_at, $report.native.staged_performance_gate_metric_policy, $report.native.staged_performance_gate_samples_run)) | Out-Null
    $lines.Add(('- staged performance gate evidence: `{0}`' -f $report.native.staged_performance_gate_evidence_path)) | Out-Null
    if($report.native.staged_performance_gate_metrics -ne $null){
        $metrics = $report.native.staged_performance_gate_metrics
        $lines.Add(('- staged performance packet batch ratio: `{0:N2}x`' -f [double]$metrics.packet_batch_vs_php_ratio)) | Out-Null
        $lines.Add(('- staged performance decode/full-chunk/fast-chunk: `{0:N0}` / `{1:N0}` / `{2:N0}`' -f [double]$metrics.native_decode_packets_per_second, [double]$metrics.full_chunk_chunks_per_second, [double]$metrics.fast_chunk_serialize_chunks_per_second)) | Out-Null
    }
    if($report.native.staged_performance_gate_error -ne $null){
        $lines.Add(('- staged performance gate error: `{0}`' -f $report.native.staged_performance_gate_error)) | Out-Null
    }
    $lines.Add(('- post-promotion fast gate required: `{0}`' -f $report.native.post_promotion_fast_gate_required)) | Out-Null
    $lines.Add(('- post-promotion soak required: `{0}`' -f $report.native.post_promotion_soak_required)) | Out-Null
    $lines.Add(('- post-promotion default fast gate/soak ports: `{0}` / `{1}`' -f $report.native.post_promotion_default_fast_gate_port, $report.native.post_promotion_default_soak_port)) | Out-Null
    $lines.Add(('- promotion command: `{0}`' -f $report.native.promotion_command)) | Out-Null
    $lines.Add(('- post-promotion validation command: `{0}`' -f $report.native.post_promotion_validation_command)) | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## Native promotion pipeline") | Out-Null
    $lines.Add(('- Running/count: `{0}` / `{1}`' -f $report.native_promotion_pipeline.running, $report.native_promotion_pipeline.process_count)) | Out-Null
    $lines.Add(('- Latest name/PID: `{0}` / `{1}`' -f $report.native_promotion_pipeline.latest_name, $report.native_promotion_pipeline.latest_pid)) | Out-Null
    $lines.Add(('- Strict soak pass required: `{0}`' -f $report.native_promotion_pipeline.strict_soak_pass_required)) | Out-Null
    $lines.Add(('- Heartbeat stage/generated: `{0}` / `{1}`' -f $report.native_promotion_pipeline.heartbeat_stage, $report.native_promotion_pipeline.heartbeat_generated_at)) | Out-Null
    $lines.Add(('- Heartbeat waited/remaining seconds: `{0}` / `{1}`' -f $report.native_promotion_pipeline.heartbeat_waited_seconds, $report.native_promotion_pipeline.heartbeat_remaining_seconds)) | Out-Null
    $lines.Add(('- Heartbeat wait/soak progress: `{0}%` / `{1}%`' -f $report.native_promotion_pipeline.heartbeat_wait_progress_percent, $report.native_promotion_pipeline.heartbeat_soak_progress_percent)) | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## Blockers") | Out-Null
    if($report.blockers.Count -eq 0){
        $lines.Add("- None.") | Out-Null
    }else{
        foreach($finding in $report.blockers){
            $lines.Add(('- `{0}`: {1}' -f $finding.key, $finding.message)) | Out-Null
        }
    }
    $lines.Add("") | Out-Null
    $lines.Add("## Warnings") | Out-Null
    if($report.warnings.Count -eq 0){
        $lines.Add("- None.") | Out-Null
    }else{
        foreach($finding in $report.warnings){
            $lines.Add(('- `{0}`: {1}' -f $finding.key, $finding.message)) | Out-Null
        }
    }

    $markdownPath = Join-Path $evidenceRoot "production-deployment-status.md"
    $lines | Set-Content -LiteralPath $markdownPath -Encoding UTF8
}

$outPath = Join-Path $evidenceRoot "production-deployment-status.json"
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $outPath -Encoding UTF8
$report | ConvertTo-Json -Depth 10
