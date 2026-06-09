param(
    [string]$PluginsDir = "plugins",
    [switch]$Markdown
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$resolvedPlugins = Join-Path $root $PluginsDir
$outRoot = Join-Path $root "var/perf/plugin-audit"
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

$patterns = [ordered]@{
    sync_file_io = "file_get_contents|file_put_contents|fopen|fwrite|scandir|glob|unlink|rename|copy\("
    sync_network_io = "curl_exec|file_get_contents\(['""]https?://|stream_socket_client|fsockopen"
    sync_database = "new\s+mysqli|PDO\(|SQLite3\(|query\(|executeQuery\("
    repeating_task = "scheduleRepeatingTask|scheduleDelayedRepeatingTask"
    all_players_loop = "getOnlinePlayers\(\)|foreach\s*\([^)]*getOnlinePlayers"
    packet_event = "DataPacketReceiveEvent|DataPacketSendEvent"
    sleep_block = "\bsleep\(|usleep\("
    debug_output = "var_dump|print_r|echo\s+|error_log"
}

$findings = New-Object System.Collections.Generic.List[object]
if (Test-Path -LiteralPath $resolvedPlugins) {
    Get-ChildItem -LiteralPath $resolvedPlugins -Recurse -File -Include *.php | ForEach-Object {
        $path = $_.FullName
        $lines = Get-Content -LiteralPath $path
        $content = $lines -join "`n"
        foreach ($key in $patterns.Keys) {
            $matches = [regex]::Matches($content, $patterns[$key], "IgnoreCase")
            if ($matches.Count -gt 0) {
                $locations = New-Object System.Collections.Generic.List[object]
                for ($lineIndex = 0; $lineIndex -lt $lines.Count; ++$lineIndex) {
                    if ($lines[$lineIndex] -match $patterns[$key]) {
                        $locations.Add([pscustomobject]@{
                            line = $lineIndex + 1
                            text = $lines[$lineIndex].Trim()
                        }) | Out-Null
                    }
                }
                $findings.Add([pscustomobject]@{
                    file = $path
                    rule = $key
                    matches = $matches.Count
                    locations = $locations
                }) | Out-Null
            }
        }
    }
}

$verdict = if ($findings.Count -eq 0) { "pass" } elseif (($findings | Where-Object { $_.rule -in @("sync_file_io", "sync_network_io", "sync_database", "sleep_block") } | Measure-Object).Count -gt 0) { "warn" } else { "info" }
$report = [pscustomobject]@{
    plugins_dir = $resolvedPlugins
    verdict = $verdict
    finding_count = $findings.Count
    findings = $findings
}

$jsonPath = Join-Path $outRoot "plugin-hotpath-report.json"
$mdPath = Join-Path $outRoot "plugin-hotpath-report.md"
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

if ($Markdown) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Plugin Hotpath Report") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("- Verdict: $verdict") | Out-Null
    $lines.Add("- Findings: $($findings.Count)") | Out-Null
    $lines.Add("") | Out-Null
    foreach ($finding in $findings) {
        $lines.Add(('- `{0}` x{1}: `{2}`' -f $finding.rule, $finding.matches, $finding.file)) | Out-Null
        foreach ($location in $finding.locations) {
            $lines.Add(('  - L{0}: `{1}`' -f $location.line, $location.text)) | Out-Null
        }
    }
    $lines | Set-Content -LiteralPath $mdPath -Encoding UTF8
}

$report | ConvertTo-Json -Depth 6
