param(
    [string]$EvidenceDir = "var/perf/production-evidence",
    [switch]$Markdown
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$evidenceRoot = Join-Path $rootPath $EvidenceDir

function Read-Evidence([string]$Name)
{
    $path = Join-Path $evidenceRoot $Name
    if(Test-Path -LiteralPath $path){
        return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    }
    return $null
}

$swarm = Read-Evidence "bedrock-login-swarm.json"
$plugins = Read-Evidence "production-plugins.json"
$soak = Read-Evidence "soak.json"
$rollback = Read-Evidence "rollback-package.json"
$nativeV142 = Read-Evidence "native-v142-build.json"
$nativeLocal = Read-Evidence "native-local-build.json"
$hostNetwork = Read-Evidence "host-network.json"
$soakStatus = $null
try{
    $soakStatus = & (Join-Path $PSScriptRoot "check-production-soak-status.ps1") | ConvertFrom-Json
}catch{
    $soakStatus = $null
}

$report = [pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    root = $rootPath
    evidence_root = $evidenceRoot
    bedrock_login_swarm = if($swarm -ne $null){
        [pscustomobject]@{
            exists = $true
            verdict = $swarm.verdict
            attempted_players = $swarm.attempted_players
            successful_logins = $swarm.successful_logins
            chunk_ready_players = $swarm.chunk_ready_players
            disconnects = $swarm.disconnects
            fatal_log_matches = $swarm.fatal_log_matches
            loss_percent = $swarm.loss_percent
        }
    }else{
        [pscustomobject]@{ exists = $false }
    }
    production_plugins = if($plugins -ne $null){
        [pscustomobject]@{
            exists = $true
            no_production_plugins = $plugins.no_production_plugins
            plugin_yml_count = $plugins.plugin_yml_count
            php_file_count = $plugins.php_file_count
            phar_count = $plugins.phar_count
        }
    }else{
        [pscustomobject]@{ exists = $false }
    }
    soak = if($soak -ne $null){
        [pscustomobject]@{
            exists = $true
            verdict = $soak.verdict
            duration_seconds = $soak.duration_seconds
            ready = $soak.ready
            fatal_log_matches = $soak.fatal_log_matches
            rak_ping = $soak.rak_ping
        }
    }else{
        [pscustomobject]@{
            exists = $false
            running_status = $soakStatus
        }
    }
    rollback = [pscustomobject]@{
        exists = $rollback -ne $null
    }
    native = [pscustomobject]@{
        v142_exists = $nativeV142 -ne $null
        local_exists = $nativeLocal -ne $null
        local_toolset_version = if($nativeLocal -ne $null){ $nativeLocal.toolset_version }else{ $null }
    }
    host_network = [pscustomobject]@{
        exists = $hostNetwork -ne $null
    }
}

if($Markdown){
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# PMMP production evidence summary") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add(('- Generated: `{0}`' -f $report.generated_at)) | Out-Null
    $lines.Add(('- Evidence root: `{0}`' -f $report.evidence_root)) | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## Bedrock login/chunk swarm") | Out-Null
    if($report.bedrock_login_swarm.exists){
        $lines.Add(('- Verdict: `{0}`' -f $report.bedrock_login_swarm.verdict)) | Out-Null
        $lines.Add(('- Attempted/successful/chunk-ready: `{0}/{1}/{2}`' -f $report.bedrock_login_swarm.attempted_players, $report.bedrock_login_swarm.successful_logins, $report.bedrock_login_swarm.chunk_ready_players)) | Out-Null
        $lines.Add(('- Disconnects/fatal/loss: `{0}/{1}/{2}%`' -f $report.bedrock_login_swarm.disconnects, $report.bedrock_login_swarm.fatal_log_matches, $report.bedrock_login_swarm.loss_percent)) | Out-Null
    }else{
        $lines.Add("- Missing.") | Out-Null
    }
    $lines.Add("") | Out-Null
    $lines.Add("## Production plugins") | Out-Null
    if($report.production_plugins.exists){
        $lines.Add(('- Explicit no-plugin deployment: `{0}`' -f $report.production_plugins.no_production_plugins)) | Out-Null
        $lines.Add(('- plugin.yml/php/phar counts: `{0}/{1}/{2}`' -f $report.production_plugins.plugin_yml_count, $report.production_plugins.php_file_count, $report.production_plugins.phar_count)) | Out-Null
    }else{
        $lines.Add("- Missing.") | Out-Null
    }
    $lines.Add("") | Out-Null
    $lines.Add("## Soak") | Out-Null
    if($report.soak.exists){
        $lines.Add(('- Verdict: `{0}`' -f $report.soak.verdict)) | Out-Null
        $lines.Add(('- Duration seconds: `{0}`' -f $report.soak.duration_seconds)) | Out-Null
        $lines.Add(('- Ready/fatal: `{0}/{1}`' -f $report.soak.ready, $report.soak.fatal_log_matches)) | Out-Null
    }elseif($report.soak.running_status -ne $null){
        $lines.Add("- Final pass evidence is not written yet.") | Out-Null
        $lines.Add(('- Running: `{0}`' -f $report.soak.running_status.running)) | Out-Null
        $lines.Add(('- Run name: `{0}`' -f $report.soak.running_status.run_name)) | Out-Null
        $lines.Add(('- Elapsed/remaining seconds: `{0}/{1}`' -f $report.soak.running_status.elapsed_seconds, $report.soak.running_status.remaining_seconds)) | Out-Null
        $lines.Add(('- Expected complete at: `{0}`' -f $report.soak.running_status.expected_complete_at)) | Out-Null
        $lines.Add(('- Ready/fatal: `{0}/{1}`' -f $report.soak.running_status.ready, $report.soak.running_status.fatal_log_matches)) | Out-Null
    }else{
        $lines.Add("- Missing.") | Out-Null
    }
    $lines.Add("") | Out-Null
    $lines.Add("## Rollback/native/host") | Out-Null
    $lines.Add(('- Rollback evidence: `{0}`' -f $report.rollback.exists)) | Out-Null
    $lines.Add(('- Native v142 evidence: `{0}`' -f $report.native.v142_exists)) | Out-Null
    $lines.Add(('- Native local evidence/toolset: `{0}` / `{1}`' -f $report.native.local_exists, $report.native.local_toolset_version)) | Out-Null
    $lines.Add(('- Host network evidence: `{0}`' -f $report.host_network.exists)) | Out-Null

    $markdownPath = Join-Path $evidenceRoot "production-evidence-summary.md"
    $lines | Set-Content -LiteralPath $markdownPath -Encoding UTF8
}

$report | ConvertTo-Json -Depth 8
