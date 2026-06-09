param(
    [string]$ProfileDir = "var/perf/profiles/wild-400",
    [int]$TargetPlayers = 400
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$resolvedProfile = Resolve-Path (Join-Path $root $ProfileDir)
$serverPropertiesPath = Join-Path $resolvedProfile "server.properties"
$pocketmineYmlPath = Join-Path $resolvedProfile "pocketmine.yml"

if (-not (Test-Path -LiteralPath $serverPropertiesPath)) {
    throw "Missing server.properties in $resolvedProfile"
}
if (-not (Test-Path -LiteralPath $pocketmineYmlPath)) {
    throw "Missing pocketmine.yml in $resolvedProfile"
}

$serverProperties = @{}
Get-Content -LiteralPath $serverPropertiesPath | ForEach-Object {
    if ($_ -match "^\s*([^#=]+?)\s*=\s*(.*?)\s*$") {
        $serverProperties[$matches[1]] = $matches[2]
    }
}

$pocketmineYml = Get-Content -LiteralPath $pocketmineYmlPath -Raw
$findings = New-Object System.Collections.Generic.List[object]

function Add-Finding([string]$level, [string]$key, [string]$message) {
    $findings.Add([pscustomobject]@{ level = $level; key = $key; message = $message }) | Out-Null
}

if ([int]$serverProperties["max-players"] -lt $TargetPlayers) {
    Add-Finding "fail" "max-players" "max-players is below target players."
}
if ([int]$serverProperties["view-distance"] -gt 4) {
    Add-Finding "warn" "view-distance" "view-distance above 4 increases chunk pressure for 400-player survival."
}
if ($serverProperties["enable-query"] -ne "false") {
    Add-Finding "warn" "enable-query" "query should be disabled during high-load baseline unless needed."
}
if ($pocketmineYml -notmatch "async-compression:\s*true") {
    Add-Finding "fail" "network.async-compression" "async compression is not enabled."
}
if ($pocketmineYml -notmatch "compression-level:\s*1") {
    Add-Finding "warn" "network.compression-level" "compression level should start at 1 for CPU-heavy high concurrency tests."
}
if ($pocketmineYml -notmatch "per-tick:\s*2") {
    Add-Finding "warn" "chunk-sending.per-tick" "chunk-sending per-tick should start low and be raised only after measurements."
}
if ($pocketmineYml -notmatch "tick-radius:\s*2") {
    Add-Finding "warn" "chunk-ticking.tick-radius" "chunk ticking radius should be small for first 400-player profile."
}

$verdict = if (($findings | Where-Object { $_.level -eq "fail" } | Measure-Object).Count -gt 0) { "fail" } elseif ($findings.Count -gt 0) { "warn" } else { "pass" }
$report = [pscustomobject]@{
    profile_dir = $resolvedProfile.Path
    target_players = $TargetPlayers
    verdict = $verdict
    findings = $findings
}

$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $resolvedProfile "perf-config-audit.json") -Encoding UTF8
$report | ConvertTo-Json -Depth 5
