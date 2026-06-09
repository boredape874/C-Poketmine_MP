param(
    [string]$GateDir = "",
    [switch]$Markdown,
    [switch]$NoExitCode
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path

if($GateDir -eq ""){
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
    $resolvedGate = $latestGate.FullName
}else{
    $resolvedGate = (Resolve-Path $GateDir).Path
}

$summaryPath = Join-Path $resolvedGate "gate-summary.json"
if(-not (Test-Path -LiteralPath $summaryPath)){
    throw "Missing gate-summary.json in $resolvedGate"
}

$summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
$evidenceRoot = Join-Path $rootPath "var/perf/production-evidence"
$nativeDllPath = Join-Path $rootPath "bin/php/ext/php_pmmp_perf_ext.dll"
$phpIniPath = Join-Path $rootPath "bin/php/php.ini"
$wildProfilePath = Join-Path $rootPath "var/perf/profiles/wild-400/pocketmine.yml"
$pluginsPath = Join-Path $rootPath "plugins"

$findings = New-Object System.Collections.Generic.List[object]

function Add-Finding([string]$Level, [string]$Key, [string]$Message, [object]$Evidence = $null){
    $script:findings.Add([pscustomobject]@{
        level = $Level
        key = $Key
        message = $Message
        evidence = $Evidence
    }) | Out-Null
}

function Test-Marker([string]$FileName){
    $path = Join-Path $evidenceRoot $FileName
    if(Test-Path -LiteralPath $path){
        return (Resolve-Path $path).Path
    }
    return $null
}

function Read-Marker([string]$FileName){
    $path = Join-Path $evidenceRoot $FileName
    if(Test-Path -LiteralPath $path){
        return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    }
    return $null
}

if(-not [bool]$summary.ready){
    Add-Finding "blocker" "gate.ready" "The latest gate did not reach ready state." $summary.ready
}
if([int]$summary.fatal_log_matches -ne 0){
    Add-Finding "blocker" "gate.fatal_log_matches" "Fatal or crash-like log matches were found." $summary.fatal_log_matches
}
if($summary.phpstan_exit -ne $null -and [int]$summary.phpstan_exit -ne 0){
    Add-Finding "blocker" "gate.phpstan_exit" "PHPStan did not pass." $summary.phpstan_exit
}
if($summary.rak_ping_sent -eq $null -or [int]$summary.rak_ping_sent -lt 400){
    Add-Finding "blocker" "gate.rak_ping_sent" "Production readiness requires at least a 400-packet Rak burst gate." $summary.rak_ping_sent
}
if($summary.rak_ping_loss_percent -eq $null -or [double]$summary.rak_ping_loss_percent -gt 10.0){
    Add-Finding "blocker" "gate.rak_ping_loss_percent" "Rak burst loss must be at most 10%." $summary.rak_ping_loss_percent
}
if($summary.packet_decoding_native_loaded -ne $true){
    Add-Finding "blocker" "native.packet_decode" "Native packet decode path is not loaded in the gate." $summary.packet_decoding_native_loaded
}
if($summary.full_chunk_serialization_native_loaded -ne $true){
    Add-Finding "blocker" "native.full_chunk" "Native full chunk serialization path is not loaded in the gate." $summary.full_chunk_serialization_native_loaded
}
if($summary.config_audit -ne "pass"){
    Add-Finding "blocker" "audit.config" "400-player profile config audit is not passing." $summary.config_audit
}
if($summary.chunk_budget -ne "pass"){
    Add-Finding "blocker" "audit.chunk_budget" "400-player chunk budget estimate is not passing." $summary.chunk_budget
}
if($summary.plugin_audit -ne "pass"){
    Add-Finding "warn" "audit.plugin_hotpaths" "Plugin hotpath audit is not clean." $summary.plugin_audit
}
if([double]$summary.full_chunk_serialization_per_second -lt 50000){
    Add-Finding "warn" "bench.full_chunk_serialization" "Full chunk serialization throughput is below the production-readiness warning floor." $summary.full_chunk_serialization_per_second
}
if([double]$summary.packet_decoding_native_string_packets_per_second -lt 800000){
    Add-Finding "warn" "bench.packet_decode" "Native packet decode throughput is below the production-readiness warning floor." $summary.packet_decoding_native_string_packets_per_second
}
if([double]$summary.global_chunk_budget_decisions_per_second -lt 10000000){
    Add-Finding "warn" "bench.global_chunk_budget" "Global chunk budget decision throughput is below the production-readiness warning floor." $summary.global_chunk_budget_decisions_per_second
}

if(-not (Test-Path -LiteralPath $nativeDllPath)){
    Add-Finding "blocker" "native.dll" "Native extension DLL is missing from the bundled PHP extension directory." $nativeDllPath
}
if(-not (Test-Path -LiteralPath $phpIniPath) -or (Get-Content -LiteralPath $phpIniPath -Raw) -notmatch "php_pmmp_perf_ext\.dll"){
    Add-Finding "blocker" "native.php_ini" "Bundled php.ini does not load php_pmmp_perf_ext.dll." $phpIniPath
}
if(Test-Path -LiteralPath $wildProfilePath){
    $wildProfile = Get-Content -LiteralPath $wildProfilePath -Raw
    if($wildProfile -notmatch "raklib-packet-limit:\s*1200"){
        Add-Finding "warn" "profile.raklib_packet_limit" "wild-400 profile does not set raklib-packet-limit to 1200." $wildProfilePath
    }
}else{
    Add-Finding "blocker" "profile.wild_400" "wild-400 profile pocketmine.yml is missing." $wildProfilePath
}

$pluginPhpFiles = if(Test-Path -LiteralPath $pluginsPath){
    @(Get-ChildItem -LiteralPath $pluginsPath -Recurse -File -Include *.php -ErrorAction SilentlyContinue)
}else{
    @()
}
$pluginMarker = Read-Marker "production-plugins.json"
if($pluginPhpFiles.Count -eq 0 -and $pluginMarker -ne $null -and $pluginMarker.no_production_plugins -eq $true){
    # Explicit no-plugin deployments are valid only while the production plugin directory is empty.
}elseif($pluginPhpFiles.Count -eq 0 -or $null -eq $pluginMarker){
    Add-Finding "blocker" "production.plugins" "No registered production plugin evidence was found for main_pmmp/plugins." (Join-Path $evidenceRoot "production-plugins.json")
}elseif([int]$pluginMarker.plugin_yml_count -eq 0 -and [int]$pluginMarker.phar_count -eq 0){
    Add-Finding "blocker" "production.plugins" "Production plugin marker does not include any plugin.yml or phar plugin." (Join-Path $evidenceRoot "production-plugins.json")
}

$loginSwarmMarker = Read-Marker "bedrock-login-swarm.json"
if($null -eq $loginSwarmMarker){
    Add-Finding "blocker" "production.bedrock_login_swarm" "Missing real Bedrock login/chunk-request swarm evidence." (Join-Path $evidenceRoot "bedrock-login-swarm.json")
}elseif($loginSwarmMarker.verdict -ne "pass" -or [int]$loginSwarmMarker.successful_logins -lt 400 -or [int]$loginSwarmMarker.chunk_ready_players -lt 400){
    Add-Finding "blocker" "production.bedrock_login_swarm" "Bedrock login/chunk-request swarm evidence does not prove 400 successful chunk-ready players." (Join-Path $evidenceRoot "bedrock-login-swarm.json")
}
$runningSoakStatus = $null
try{
    $runningSoakStatus = & (Join-Path $PSScriptRoot "check-production-soak-status.ps1") | ConvertFrom-Json
}catch{
    $runningSoakStatus = $null
}
$soakMarker = Read-Marker "soak.json"
if($null -eq $soakMarker){
    if($runningSoakStatus -ne $null -and $runningSoakStatus.running -eq $true){
        Add-Finding "blocker" "production.soak" "2+ hour soak evidence is not written yet; a production soak is currently running." ([pscustomobject]@{
            run_name = $runningSoakStatus.run_name
            running = $runningSoakStatus.running
            ready = $runningSoakStatus.ready
            elapsed_seconds = $runningSoakStatus.elapsed_seconds
            remaining_seconds = $runningSoakStatus.remaining_seconds
            expected_complete_at = $runningSoakStatus.expected_complete_at
            fatal_log_matches = $runningSoakStatus.fatal_log_matches
            pass_evidence_exists = $runningSoakStatus.pass_evidence_exists
            pass_evidence_matches_run = $runningSoakStatus.pass_evidence_matches_run
            failed_evidence_exists = $runningSoakStatus.failed_evidence_exists
            failed_evidence_matches_run = $runningSoakStatus.failed_evidence_matches_run
            baseline_dir = $runningSoakStatus.baseline_dir
        })
    }else{
        Add-Finding "blocker" "production.soak" "Missing 2-6 hour soak evidence." (Join-Path $evidenceRoot "soak.json")
    }
}elseif(
    $soakMarker.verdict -ne "pass" -or
    [int]$soakMarker.duration_seconds -lt 7200 -or
    [int]$soakMarker.fatal_log_matches -ne 0 -or
    ($soakMarker.exit_code -ne $null -and [int]$soakMarker.exit_code -ne 0) -or
    ($soakMarker.failure_reasons -ne $null -and @($soakMarker.failure_reasons).Count -gt 0)
){
    Add-Finding "blocker" "production.soak" "Soak evidence does not prove a clean 2+ hour run." (Join-Path $evidenceRoot "soak.json")
}
$rollbackMarker = Read-Marker "rollback-package.json"
if($null -eq $rollbackMarker){
    Add-Finding "blocker" "production.rollback" "Missing rollback/package evidence." (Join-Path $evidenceRoot "rollback-package.json")
}elseif($rollbackMarker.files.disable_native_script -eq $null -or -not (Test-Path -LiteralPath $rollbackMarker.files.disable_native_script)){
    Add-Finding "blocker" "production.rollback" "Rollback evidence is missing the native-disable script." (Join-Path $evidenceRoot "rollback-package.json")
}
$nativeBuildMarker = Read-Marker "native-v142-build.json"
if($null -eq $nativeBuildMarker){
    Add-Finding "warn" "production.native_v142" "Missing VS2019/v142 production native build evidence." (Join-Path $evidenceRoot "native-v142-build.json")
}elseif($nativeBuildMarker.is_v142 -ne $true){
    Add-Finding "warn" "production.native_v142" "Native build marker is present but does not prove a v142 build." (Join-Path $evidenceRoot "native-v142-build.json")
}
$hostNetworkMarker = Read-Marker "host-network.json"
if($null -eq $hostNetworkMarker){
    Add-Finding "warn" "production.host_network" "Missing host UDP/firewall/NIC evidence for the actual deployment machine." (Join-Path $evidenceRoot "host-network.json")
}elseif($hostNetworkMarker.machine -eq $null -or $hostNetworkMarker.adapters -eq $null){
    Add-Finding "warn" "production.host_network" "Host network marker is present but missing machine or adapter evidence." (Join-Path $evidenceRoot "host-network.json")
}

$blockerCount = @($findings | Where-Object { $_.level -eq "blocker" }).Count
$warnCount = @($findings | Where-Object { $_.level -eq "warn" }).Count
$coreReady = $blockerCount -eq 0 -or (
    [bool]$summary.ready -and
    [int]$summary.fatal_log_matches -eq 0 -and
    ($summary.phpstan_exit -eq $null -or [int]$summary.phpstan_exit -eq 0) -and
    [int]$summary.rak_ping_sent -ge 400 -and
    [double]$summary.rak_ping_loss_percent -le 10.0 -and
    $summary.packet_decoding_native_loaded -eq $true -and
    $summary.full_chunk_serialization_native_loaded -eq $true
)
$verdict = if($blockerCount -gt 0){ "not_ready" }elseif($warnCount -gt 0){ "ready_with_warnings" }else{ "ready" }
$readinessPercent = if($verdict -eq "ready"){
    90
}elseif($verdict -eq "ready_with_warnings"){
    85
}elseif($coreReady -and $blockerCount -eq 1){
    80
}elseif($coreReady -and $blockerCount -eq 2){
    70
}elseif($coreReady){
    60
}else{
    40
}

$report = [pscustomobject]@{
    root = $rootPath
    gate_dir = $resolvedGate
    gate_name = $summary.gate_name
    verdict = $verdict
    readiness_percent = $readinessPercent
    high_performance_core_ready = $coreReady
    blocker_count = $blockerCount
    warning_count = $warnCount
    latest_gate = [pscustomobject]@{
        ready = $summary.ready
        ready_seconds = $summary.ready_seconds
        fatal_log_matches = $summary.fatal_log_matches
        phpstan_exit = $summary.phpstan_exit
        rak_ping = [pscustomobject]@{
            sent = $summary.rak_ping_sent
            received = $summary.rak_ping_received
            loss_percent = $summary.rak_ping_loss_percent
            latency_avg_ms = $summary.rak_ping_latency_avg_ms
        }
        packet_decoding_native_loaded = $summary.packet_decoding_native_loaded
        full_chunk_serialization_native_loaded = $summary.full_chunk_serialization_native_loaded
        packet_decoding_native_string_packets_per_second = $summary.packet_decoding_native_string_packets_per_second
        full_chunk_serialization_per_second = $summary.full_chunk_serialization_per_second
        fast_chunk_serializer_serialize_per_second = $summary.fast_chunk_serializer_serialize_per_second
        fast_chunk_serializer_deserialize_per_second = $summary.fast_chunk_serializer_deserialize_per_second
        fast_chunk_serializer_native_pack_loaded = $summary.fast_chunk_serializer_native_pack_loaded
        fast_chunk_serializer_native_unpack_loaded = $summary.fast_chunk_serializer_native_unpack_loaded
        global_chunk_budget_decisions_per_second = $summary.global_chunk_budget_decisions_per_second
    }
    evidence_root = $evidenceRoot
    running_soak_status = $runningSoakStatus
    findings = $findings
}

$jsonPath = Join-Path $resolvedGate "production-readiness.json"
$report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

if($Markdown){
    $mdPath = Join-Path $resolvedGate "production-readiness.md"
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Production Readiness Audit") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add(('- Gate: `{0}`' -f $summary.gate_name)) | Out-Null
    $lines.Add(('- Verdict: `{0}`' -f $verdict)) | Out-Null
    $lines.Add(('- Readiness: `{0}%`' -f $readinessPercent)) | Out-Null
    $lines.Add(('- High-performance core ready: `{0}`' -f $coreReady)) | Out-Null
    $lines.Add(('- Blockers: `{0}`' -f $blockerCount)) | Out-Null
    $lines.Add(('- Warnings: `{0}`' -f $warnCount)) | Out-Null
    $lines.Add("") | Out-Null
    if($runningSoakStatus -ne $null){
        $lines.Add("## Running Soak") | Out-Null
        $lines.Add("") | Out-Null
        $lines.Add(('- Run: `{0}`' -f $runningSoakStatus.run_name)) | Out-Null
        $lines.Add(('- Running: `{0}`' -f $runningSoakStatus.running)) | Out-Null
        $lines.Add(('- Ready: `{0}`' -f $runningSoakStatus.ready)) | Out-Null
        $lines.Add(('- Elapsed seconds: `{0}`' -f $runningSoakStatus.elapsed_seconds)) | Out-Null
        $lines.Add(('- Fatal/error matches: `{0}`' -f $runningSoakStatus.fatal_log_matches)) | Out-Null
        $lines.Add(('- Pass evidence exists: `{0}`' -f $runningSoakStatus.pass_evidence_exists)) | Out-Null
        $lines.Add(('- Pass/failed evidence matches this run: `{0}` / `{1}`' -f $runningSoakStatus.pass_evidence_matches_run, $runningSoakStatus.failed_evidence_matches_run)) | Out-Null
        $lines.Add("") | Out-Null
    }
    $lines.Add("## Findings") | Out-Null
    $lines.Add("") | Out-Null
    foreach($finding in $findings){
        $lines.Add(("- `{0}` `{1}`: {2}" -f $finding.level, $finding.key, $finding.message)) | Out-Null
    }
    $lines | Set-Content -LiteralPath $mdPath -Encoding UTF8
}

$report | ConvertTo-Json -Depth 7
if($verdict -eq "not_ready" -and -not $NoExitCode){
    exit 9
}
