param(
    [Parameter(Mandatory=$true)]
    [string]$InputJson,
    [int]$TargetPlayers = 400,
    [string]$OutputDir = "var/perf/production-evidence"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$resolvedInput = Resolve-Path $InputJson
$evidenceRoot = Join-Path $rootPath $OutputDir
New-Item -ItemType Directory -Force -Path $evidenceRoot | Out-Null

$input = Get-Content -LiteralPath $resolvedInput -Raw | ConvertFrom-Json
function Get-FirstPropertyValue([object]$Object, [string[]]$Names, [object]$Default){
    foreach($name in $Names){
        if($Object.PSObject.Properties.Name -contains $name -and $null -ne $Object.$name){
            return $Object.$name
        }
    }
    return $Default
}

$attempted = [int](Get-FirstPropertyValue $input @("attempted_players", "attempted") 0)
$successful = [int](Get-FirstPropertyValue $input @("successful_logins", "successful_players", "successful") 0)
$chunkReady = [int](Get-FirstPropertyValue $input @("chunk_ready_players", "chunk_ready") 0)
$disconnects = [int](Get-FirstPropertyValue $input @("disconnects") 0)
$fatalLogMatches = [int](Get-FirstPropertyValue $input @("fatal_log_matches") 0)
$durationSeconds = [int](Get-FirstPropertyValue $input @("duration_seconds") 0)
$lossPercent = [double](Get-FirstPropertyValue $input @("loss_percent") 0)

$passed = $attempted -ge $TargetPlayers -and
    $successful -ge $TargetPlayers -and
    $chunkReady -ge $TargetPlayers -and
    $disconnects -eq 0 -and
    $fatalLogMatches -eq 0 -and
    $durationSeconds -ge 60 -and
    $lossPercent -le 10.0

$report = [pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    root = $rootPath
    source = $resolvedInput.Path
    verdict = if($passed){ "pass" }else{ "fail" }
    target_players = $TargetPlayers
    attempted_players = $attempted
    successful_logins = $successful
    chunk_ready_players = $chunkReady
    disconnects = $disconnects
    fatal_log_matches = $fatalLogMatches
    duration_seconds = $durationSeconds
    loss_percent = $lossPercent
    raw = $input
}

$outName = if($passed){ "bedrock-login-swarm.json" }else{ "bedrock-login-swarm-last-failed.json" }
$outPath = Join-Path $evidenceRoot $outName
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outPath -Encoding UTF8
$report | ConvertTo-Json -Depth 8
if(-not $passed){
    exit 12
}
