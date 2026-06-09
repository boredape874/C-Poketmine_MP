param(
    [string]$GateDir = $null,
    [string]$CompareJsonPath = $null
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$gateRoot = Join-Path $rootPath "var/perf/gates"

if($GateDir -eq $null){
    if(-not (Test-Path -LiteralPath $gateRoot)){
        throw "No gate directory found at $gateRoot"
    }
    $latestGate = Get-ChildItem -LiteralPath $gateRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if($latestGate -eq $null){
        throw "No gate run directories found at $gateRoot"
    }
    $GateDir = $latestGate.FullName
}

$summaryPath = Join-Path $GateDir "gate-summary.json"
if(-not (Test-Path -LiteralPath $summaryPath)){
    throw "Gate summary not found: $summaryPath"
}

$summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
$compare = if(-not [string]::IsNullOrWhiteSpace($CompareJsonPath) -and (Test-Path -LiteralPath $CompareJsonPath)){
    Get-Content -LiteralPath $CompareJsonPath -Raw | ConvertFrom-Json
}else{
    $localCompare = Join-Path $GateDir "compare-summary.json"
    if(Test-Path -LiteralPath $localCompare){
        Get-Content -LiteralPath $localCompare -Raw | ConvertFrom-Json
    }else{
        $null
    }
}

function Format-Value($Value){
    if($null -eq $Value){
        return "n/a"
    }
    return [string]$Value
}

function Get-WarningReasons($Compare){
    $reasons = New-Object System.Collections.Generic.List[string]
    if($Compare -eq $null -or $Compare.verdict -eq "pass"){
        return $reasons
    }

    if($Compare.delta.ready_seconds -ne $null -and [double]$Compare.delta.ready_seconds -gt 1.0){
        $reasons.Add(("ready time increased by {0}s" -f $Compare.delta.ready_seconds)) | Out-Null
    }
    if($Compare.delta.fatal_log_matches -ne $null -and [int]$Compare.delta.fatal_log_matches -gt 0){
        $reasons.Add(("fatal log matches increased by {0}" -f $Compare.delta.fatal_log_matches)) | Out-Null
    }
    if($Compare.delta.max_working_set_mb -ne $null -and [double]$Compare.delta.max_working_set_mb -gt 64.0){
        $reasons.Add(("working set increased by {0} MB" -f $Compare.delta.max_working_set_mb)) | Out-Null
    }
    if($Compare.delta.max_private_mb -ne $null -and [double]$Compare.delta.max_private_mb -gt 64.0){
        $reasons.Add(("private memory increased by {0} MB" -f $Compare.delta.max_private_mb)) | Out-Null
    }
    if($Compare.delta.max_threads -ne $null -and [int]$Compare.delta.max_threads -gt 8){
        $reasons.Add(("thread count increased by {0}" -f $Compare.delta.max_threads)) | Out-Null
    }
    if($Compare.delta.max_handles -ne $null -and [int]$Compare.delta.max_handles -gt 128){
        $reasons.Add(("handle count increased by {0}" -f $Compare.delta.max_handles)) | Out-Null
    }

    if($reasons.Count -eq 0){
        $reasons.Add("compare verdict was not pass; inspect compare-summary.json for threshold details") | Out-Null
    }

    return $reasons
}

function Get-HotpathWarnings($Summary){
    $warnings = New-Object System.Collections.Generic.List[string]
    $thresholds = [ordered]@{
        "chunk_selector_chunks_per_second" = 3000000
        "chunk_prefetch_priority_selections_per_second" = 300000
        "varint_cases_per_second" = 10000000
        "item_translator_conversions_per_second" = 1500000
        "simple_inventory_adds_per_second" = 75000
        "packet_batch_raw_batches_per_second" = 700000
        "packet_encoding_packets_per_second" = 450000
        "packet_decoding_packets_per_second" = 500000
        "packet_pool_lookups_per_second" = 4500000
        "block_update_packets_per_second" = 750000
        "block_state_data_lookups_per_second" = 750000
        "nearby_entity_array_entities_per_second" = 10000000
        "nearby_entity_callback_entities_per_second" = 12000000
        "nearby_entity_boolean_queries_per_second" = 300000
        "subchunk_serialization_per_second" = 600000
        "full_chunk_serialization_per_second" = 40000
        "compression_batches_per_second" = 90000
        "mining_progress_updates_per_second" = 6000000
        "movement_process_updates_per_second" = 3500000
        "chunk_pressure_snapshots_per_second" = 1000000
        "global_chunk_budget_decisions_per_second" = 1000000
        "population_prefetch_selection_candidates_per_second" = 1000000
    }

    $thresholdPath = Join-Path $PSScriptRoot "hotpath-thresholds.json"
    if(Test-Path -LiteralPath $thresholdPath){
        $configuredThresholds = Get-Content -LiteralPath $thresholdPath -Raw | ConvertFrom-Json
        foreach($property in $configuredThresholds.PSObject.Properties){
            $thresholds[$property.Name] = $property.Value
        }
    }

    foreach($entry in $thresholds.GetEnumerator()){
        $value = $Summary.($entry.Key)
        if($null -ne $value -and [double]$value -lt [double]$entry.Value){
            $warnings.Add(("{0} below threshold: {1} < {2}" -f $entry.Key, $value, $entry.Value)) | Out-Null
        }
    }

    return $warnings
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# PMMP Gate Summary") | Out-Null
$lines.Add("") | Out-Null
$lines.Add(('Gate: `{0}`' -f $summary.gate_name)) | Out-Null
$lines.Add(('Ready: `{0}` in `{1}` seconds' -f $summary.ready, $summary.ready_seconds)) | Out-Null
$lines.Add(('Fatal log matches: `{0}`' -f $summary.fatal_log_matches)) | Out-Null
$lines.Add(('PHPStan exit: `{0}`' -f $summary.phpstan_exit)) | Out-Null
$lines.Add(('Rak ping: `{0}/{1}`, loss `{2}%`, avg `{3}` ms' -f $summary.rak_ping_received, $summary.rak_ping_sent, $summary.rak_ping_loss_percent, $summary.rak_ping_latency_avg_ms)) | Out-Null
$lines.Add(('Audits: config `{0}`, chunk budget `{1}`, plugin `{2}`' -f $summary.config_audit, $summary.chunk_budget, $summary.plugin_audit)) | Out-Null
$lines.Add("") | Out-Null

$lines.Add("## Chunk Cache") | Out-Null
$lines.Add("") | Out-Null
$chunkCacheFields = [ordered]@{
    "reports" = $summary.chunk_cache_reports
    "hits" = $summary.chunk_cache_hits
    "misses" = $summary.chunk_cache_misses
    "prefetch attempts" = $summary.chunk_cache_prefetch_attempts
    "prefetch started" = $summary.chunk_cache_prefetch_started
    "prefetch skipped cached" = $summary.chunk_cache_prefetch_skipped_cached
    "prefetch skipped unloaded" = $summary.chunk_cache_prefetch_skipped_unloaded
    "prefetch promise hits" = $summary.chunk_cache_prefetch_promise_hits
    "prefetch packet hits" = $summary.chunk_cache_prefetch_packet_hits
    "probe reports" = $summary.chunk_cache_probe_reports
    "probe ok" = $summary.chunk_cache_probe_ok
    "probe failed" = $summary.chunk_cache_probe_failed
    "probe targets" = $summary.chunk_cache_probe_targets
    "probe prefetch started" = $summary.chunk_cache_probe_prefetch_started
    "probe promise requests" = $summary.chunk_cache_probe_promise_requests
    "probe packet requests" = $summary.chunk_cache_probe_packet_requests
    "probe stat prefetch attempts" = $summary.chunk_cache_probe_stat_prefetch_attempts
    "probe stat prefetch started" = $summary.chunk_cache_probe_stat_prefetch_started
    "probe stat prefetch promise hits" = $summary.chunk_cache_probe_stat_prefetch_promise_hits
    "probe stat prefetch packet hits" = $summary.chunk_cache_probe_stat_prefetch_packet_hits
    "probe stat hits" = $summary.chunk_cache_probe_stat_hits
    "probe stat misses" = $summary.chunk_cache_probe_stat_misses
}
foreach($entry in $chunkCacheFields.GetEnumerator()){
    $lines.Add(('- {0}: `{1}`' -f $entry.Key, (Format-Value $entry.Value))) | Out-Null
}
$lines.Add("") | Out-Null

$lines.Add("## Chunk Budget Pressure") | Out-Null
$lines.Add("") | Out-Null
$chunkBudgetPressureFields = [ordered]@{
    "reports" = $summary.chunk_budget_pressure_reports
    "scale total" = $summary.chunk_budget_pressure_scale_total
    "scale min" = $summary.chunk_budget_pressure_scale_min
    "scale max" = $summary.chunk_budget_pressure_scale_max
    "pending total" = $summary.chunk_budget_pressure_pending_total
    "async backlog total" = $summary.chunk_budget_pressure_async_backlog_total
    "population prefetch started total" = $summary.chunk_budget_pressure_population_prefetch_started_total
    "population prefetch resolved total" = $summary.chunk_budget_pressure_population_prefetch_resolved_total
    "population prefetch stale total" = $summary.chunk_budget_pressure_population_prefetch_stale_total
    "population prefetch active total" = $summary.chunk_budget_pressure_population_prefetch_active_total
}
foreach($entry in $chunkBudgetPressureFields.GetEnumerator()){
    $lines.Add(('- {0}: `{1}`' -f $entry.Key, (Format-Value $entry.Value))) | Out-Null
}
$lines.Add("") | Out-Null

$lines.Add("## Chunk Population") | Out-Null
$lines.Add("") | Out-Null
$chunkPopulationFields = [ordered]@{
    "reports" = $summary.chunk_population_reports
    "requests total" = $summary.chunk_population_requests_total
    "shared hits total" = $summary.chunk_population_shared_hits_total
    "queued total" = $summary.chunk_population_queued_total
    "queue duplicates total" = $summary.chunk_population_queue_duplicates_total
    "started total" = $summary.chunk_population_started_total
    "resolved total" = $summary.chunk_population_resolved_total
    "rejected total" = $summary.chunk_population_rejected_total
    "active total" = $summary.chunk_population_active_total
    "pending total" = $summary.chunk_population_pending_total
    "queued unique total" = $summary.chunk_population_queued_unique_total
}
foreach($entry in $chunkPopulationFields.GetEnumerator()){
    $lines.Add(('- {0}: `{1}`' -f $entry.Key, (Format-Value $entry.Value))) | Out-Null
}
$lines.Add("") | Out-Null

if($compare -ne $null){
    $lines.Add("## Compare") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add(('Base: `{0}`' -f $compare.base.run_name)) | Out-Null
    $lines.Add(('Candidate: `{0}`' -f $compare.candidate.run_name)) | Out-Null
    $lines.Add(('Verdict: `{0}`' -f $compare.verdict)) | Out-Null
    $lines.Add(('Ready delta: `{0}` seconds' -f $compare.delta.ready_seconds)) | Out-Null
    $lines.Add(('Memory delta: working set `{0}` MB, private `{1}` MB' -f $compare.delta.max_working_set_mb, $compare.delta.max_private_mb)) | Out-Null
    $warningReasons = Get-WarningReasons $compare
    if($warningReasons.Count -gt 0){
        $lines.Add("") | Out-Null
        $lines.Add("### Warning Reasons") | Out-Null
        $lines.Add("") | Out-Null
        foreach($reason in $warningReasons){
            $lines.Add("- $reason") | Out-Null
        }
    }
    $lines.Add("") | Out-Null
}

$lines.Add("## Hotpath Bench") | Out-Null
$lines.Add("") | Out-Null
$benchFields = [ordered]@{
    "chunk selector chunks/sec" = $summary.chunk_selector_chunks_per_second
    "chunk prefetch priority selections/sec" = $summary.chunk_prefetch_priority_selections_per_second
    "chunk prefetch baseline front selected" = $summary.chunk_prefetch_priority_baseline_front_selected
    "chunk prefetch biased front selected" = $summary.chunk_prefetch_priority_biased_front_selected
    "chunk prefetch biased total selected" = $summary.chunk_prefetch_priority_biased_total_selected
    "varint cases/sec" = $summary.varint_cases_per_second
    "item translator conversions/sec" = $summary.item_translator_conversions_per_second
    "simple inventory adds/sec" = $summary.simple_inventory_adds_per_second
    "packet batch raw batches/sec" = $summary.packet_batch_raw_batches_per_second
    "packet batch native loaded" = $summary.packet_batch_raw_native_loaded
    "packet encoding packets/sec" = $summary.packet_encoding_packets_per_second
    "packet decoding packets/sec" = $summary.packet_decoding_packets_per_second
    "packet decoding generator packets/sec" = $summary.packet_decoding_generator_packets_per_second
    "packet decoding callback packets/sec" = $summary.packet_decoding_callback_packets_per_second
    "packet decoding native string packets/sec" = $summary.packet_decoding_native_string_packets_per_second
    "packet decoding native loaded" = $summary.packet_decoding_native_loaded
    "packet pool lookups/sec" = $summary.packet_pool_lookups_per_second
    "block update packets/sec" = $summary.block_update_packets_per_second
    "block state data lookups/sec" = $summary.block_state_data_lookups_per_second
    "nearby entity array entities/sec" = $summary.nearby_entity_array_entities_per_second
    "nearby entity callback entities/sec" = $summary.nearby_entity_callback_entities_per_second
    "nearby entity boolean queries/sec" = $summary.nearby_entity_boolean_queries_per_second
    "subchunk serialization/sec" = $summary.subchunk_serialization_per_second
    "full chunk serialization/sec" = $summary.full_chunk_serialization_per_second
    "full chunk native loaded" = $summary.full_chunk_serialization_native_loaded
    "fast chunk serialize/sec" = $summary.fast_chunk_serializer_serialize_per_second
    "fast chunk deserialize/sec" = $summary.fast_chunk_serializer_deserialize_per_second
    "fast chunk native pack loaded" = $summary.fast_chunk_serializer_native_pack_loaded
    "fast chunk native unpack loaded" = $summary.fast_chunk_serializer_native_unpack_loaded
    "compression batches/sec" = $summary.compression_batches_per_second
    "mining progress updates/sec" = $summary.mining_progress_updates_per_second
    "movement process updates/sec" = $summary.movement_process_updates_per_second
    "chunk pressure snapshots/sec" = $summary.chunk_pressure_snapshots_per_second
    "chunk pressure pending accumulator" = $summary.chunk_pressure_pending_accumulator
    "global chunk budget decisions/sec" = $summary.global_chunk_budget_decisions_per_second
    "global chunk budget scale accumulator" = $summary.global_chunk_budget_scale_accumulator
    "population prefetch selection candidates/sec" = $summary.population_prefetch_selection_candidates_per_second
    "population prefetch selection candidates" = $summary.population_prefetch_selection_candidates
    "population prefetch selection active skips" = $summary.population_prefetch_selection_active_skips
    "population prefetch selection stale completions" = $summary.population_prefetch_selection_stale_completions
    "chunk population coalescing requests/sec" = $summary.chunk_population_coalescing_requests_per_second
    "chunk population coalescing requests" = $summary.chunk_population_coalescing_requests
    "chunk population coalescing unique requests" = $summary.chunk_population_coalescing_unique_requests
    "chunk population coalescing shared hits" = $summary.chunk_population_coalescing_shared_hits
}
foreach($entry in $benchFields.GetEnumerator()){
    $lines.Add(('- {0}: `{1}`' -f $entry.Key, (Format-Value $entry.Value))) | Out-Null
}

$hotpathWarnings = Get-HotpathWarnings $summary
if($hotpathWarnings.Count -gt 0){
    $lines.Add("") | Out-Null
    $lines.Add("### Hotpath Warnings") | Out-Null
    $lines.Add("") | Out-Null
    foreach($warning in $hotpathWarnings){
        $lines.Add("- $warning") | Out-Null
    }
}

$outputPath = Join-Path $GateDir "summary.md"
$lines | Set-Content -LiteralPath $outputPath -Encoding UTF8

[pscustomobject]@{
    gate_dir = $GateDir
    markdown = $outputPath
    gate_name = $summary.gate_name
} | ConvertTo-Json -Depth 4
