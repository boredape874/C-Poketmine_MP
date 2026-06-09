param(
    [Parameter(Mandatory = $true)]
    [string]$RunDir,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedRunDir = Resolve-Path $RunDir
$serverLogPath = Join-Path $resolvedRunDir "data/server.log"
$stdoutPath = Join-Path $resolvedRunDir "stdout.log"
$stderrPath = Join-Path $resolvedRunDir "stderr.log"
$summaryPath = Join-Path $resolvedRunDir "run-summary.json"

$serverLog = if (Test-Path -LiteralPath $serverLogPath) { Get-Content -LiteralPath $serverLogPath -Raw } else { "" }
$stdout = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { "" }
$stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { "" }
$combined = "$serverLog`n$stdout`n$stderr"
$summary = if (Test-Path -LiteralPath $summaryPath) { Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json } else { $null }

$patterns = [ordered]@{
    fatal = "Fatal error|Uncaught|segmentation fault|segfault"
    critical = "CRITICAL|Worker .* crashed|crashed"
    warning = "WARNING|WARN|경고"
    bind_failure = "Failed to bind|Address already in use|Only one usage of each socket address"
    compression = "compress|compression|zlib"
    auth = "xbox|xuid|auth"
    lag = "Can't keep up|overloaded|tick took|TPS"
}

$matches = [ordered]@{}
foreach ($key in $patterns.Keys) {
    $matches[$key] = ([regex]::Matches($combined, $patterns[$key], "IgnoreCase")).Count
}

$chunkCacheStats = [ordered]@{
    reports = 0
    hits = 0
    misses = 0
    cached_entries = 0
    prefetch_attempts = 0
    prefetch_started = 0
    prefetch_skipped_cached = 0
    prefetch_skipped_unloaded = 0
    prefetch_promise_hits = 0
    prefetch_packet_hits = 0
}
$chunkCachePattern = "PMMP_CHUNK_CACHE_STATS\s+(\{[^\r\n]+\})"
foreach ($match in [regex]::Matches($serverLog, $chunkCachePattern)) {
    try {
        $stats = $match.Groups[1].Value | ConvertFrom-Json
        $chunkCacheStats.reports++
        foreach ($key in @(
            "hits",
            "misses",
            "cached_entries",
            "prefetch_attempts",
            "prefetch_started",
            "prefetch_skipped_cached",
            "prefetch_skipped_unloaded",
            "prefetch_promise_hits",
            "prefetch_packet_hits"
        )) {
            if ($stats.PSObject.Properties.Name -contains $key) {
                $chunkCacheStats[$key] += [int]$stats.$key
            }
        }
    } catch {
    }
}

$chunkCacheProbe = [ordered]@{
    reports = 0
    ok = 0
    failed = 0
    targets = 0
    prefetch_started_probe = 0
    promise_requests_probe = 0
    packet_requests_probe = 0
    prefetch_attempts = 0
    prefetch_started = 0
    prefetch_promise_hits = 0
    prefetch_packet_hits = 0
    hits = 0
    misses = 0
}
$chunkCacheProbePattern = "PMMP_CHUNK_CACHE_PROBE\s+(\{[^\r\n]+\})"
foreach ($match in [regex]::Matches($serverLog, $chunkCacheProbePattern)) {
    try {
        $probe = $match.Groups[1].Value | ConvertFrom-Json
        $chunkCacheProbe.reports++
        if ($probe.ok -eq $true) {
            $chunkCacheProbe.ok++
            foreach ($key in @(
                "targets",
                "prefetch_started_probe",
                "promise_requests_probe",
                "packet_requests_probe"
            )) {
                if ($probe.PSObject.Properties.Name -contains $key) {
                    $chunkCacheProbe[$key] += [int]$probe.$key
                }
            }
            if ($probe.stats -ne $null) {
                foreach ($key in @(
                    "prefetch_attempts",
                    "prefetch_started",
                    "prefetch_promise_hits",
                    "prefetch_packet_hits",
                    "hits",
                    "misses"
                )) {
                    if ($probe.stats.PSObject.Properties.Name -contains $key) {
                        $chunkCacheProbe[$key] += [int]$probe.stats.$key
                    }
                }
            }
        } else {
            $chunkCacheProbe.failed++
        }
    } catch {
    }
}

$chunkBudgetPressure = [ordered]@{
    reports = 0
    scale_total = 0
    scale_min = $null
    scale_max = $null
    pending_total = 0
    async_backlog_total = 0
    population_prefetch_started_total = 0
    population_prefetch_resolved_total = 0
    population_prefetch_stale_total = 0
    population_prefetch_active_total = 0
}
$chunkBudgetPressurePattern = "PMMP_CHUNK_BUDGET_PRESSURE\s+(\{[^\r\n]+\})"
foreach ($match in [regex]::Matches($serverLog, $chunkBudgetPressurePattern)) {
    try {
        $pressure = $match.Groups[1].Value | ConvertFrom-Json
        $chunkBudgetPressure.reports++
        if ($pressure.PSObject.Properties.Name -contains "scale") {
            $scale = [int]$pressure.scale
            $chunkBudgetPressure.scale_total += $scale
            if ($chunkBudgetPressure.scale_min -eq $null -or $scale -lt $chunkBudgetPressure.scale_min) {
                $chunkBudgetPressure.scale_min = $scale
            }
            if ($chunkBudgetPressure.scale_max -eq $null -or $scale -gt $chunkBudgetPressure.scale_max) {
                $chunkBudgetPressure.scale_max = $scale
            }
        }
        if ($pressure.PSObject.Properties.Name -contains "pending") {
            $chunkBudgetPressure.pending_total += [int]$pressure.pending
        }
        if ($pressure.PSObject.Properties.Name -contains "async_backlog") {
            $chunkBudgetPressure.async_backlog_total += [int]$pressure.async_backlog
        }
        if ($pressure.PSObject.Properties.Name -contains "population_prefetch_started") {
            $chunkBudgetPressure.population_prefetch_started_total += [int]$pressure.population_prefetch_started
        }
        if ($pressure.PSObject.Properties.Name -contains "population_prefetch_resolved") {
            $chunkBudgetPressure.population_prefetch_resolved_total += [int]$pressure.population_prefetch_resolved
        }
        if ($pressure.PSObject.Properties.Name -contains "population_prefetch_stale") {
            $chunkBudgetPressure.population_prefetch_stale_total += [int]$pressure.population_prefetch_stale
        }
        if ($pressure.PSObject.Properties.Name -contains "population_prefetch_active") {
            $chunkBudgetPressure.population_prefetch_active_total += [int]$pressure.population_prefetch_active
        }
    } catch {
    }
}

$chunkPopulationStats = [ordered]@{
    reports = 0
    requests_total = 0
    shared_hits_total = 0
    queued_total = 0
    queue_duplicates_total = 0
    started_total = 0
    resolved_total = 0
    rejected_total = 0
    active_total = 0
    pending_total = 0
    queued_unique_total = 0
}
$chunkPopulationStatsPattern = "PMMP_CHUNK_POPULATION_STATS\s+(\{[^\r\n]+\})"
foreach ($match in [regex]::Matches($serverLog, $chunkPopulationStatsPattern)) {
    try {
        $stats = $match.Groups[1].Value | ConvertFrom-Json
        $chunkPopulationStats.reports++
        foreach ($field in @("requests", "shared_hits", "queued", "queue_duplicates", "started", "resolved", "rejected", "active", "pending", "queued_unique")) {
            if ($stats.PSObject.Properties.Name -contains $field) {
                $chunkPopulationStats["$($field)_total"] += [int]$stats.$field
            }
        }
    } catch {
    }
}

$riskLevel = "pass"
if ($matches.fatal -gt 0 -or $matches.critical -gt 0 -or $matches.bind_failure -gt 0) {
    $riskLevel = "fail"
} elseif ($matches.warning -gt 0 -or $matches.lag -gt 0) {
    $riskLevel = "warn"
}

$report = [pscustomobject]@{
    run_dir = $resolvedRunDir.Path
    risk_level = $riskLevel
    ready = if ($summary -ne $null) { [bool]$summary.ready } else { $null }
    ready_seconds = if ($summary -ne $null) { $summary.ready_seconds } else { $null }
    exit_code = if ($summary -ne $null) { $summary.exit_code } else { $null }
    matches = $matches
    chunk_cache = $chunkCacheStats
    chunk_cache_probe = $chunkCacheProbe
    chunk_budget_pressure = $chunkBudgetPressure
    chunk_population_stats = $chunkPopulationStats
}

$reportJson = $report | ConvertTo-Json -Depth 5
$reportJson | Set-Content -LiteralPath (Join-Path $resolvedRunDir "log-risk-report.json") -Encoding UTF8

if ($Json) {
    $reportJson
} else {
    $report
}
