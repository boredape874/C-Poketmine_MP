param(
    [int]$Port = 19132,
    [int]$DurationSeconds = 30,
    [switch]$AcceptLgpl,
    [switch]$SkipPhpStan,
    [switch]$RunHotpathBench,
    [switch]$RunRakPingBurst,
    [int]$RakPingCount = 400,
    [int]$RakPingTimeoutMs = 2500,
    [int]$RakPingBatchSize = 64,
    [int]$RakPingBatchDelayUs = 0,
    [switch]$KoreanProfile
)

$ErrorActionPreference = "Stop"

if (-not $AcceptLgpl) {
    throw "LGPL license acceptance is required. Re-run with -AcceptLgpl after you have accepted the LICENSE in this PMMP directory."
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$gateRoot = Join-Path $root "var/perf/gates/$stamp"
New-Item -ItemType Directory -Force -Path $gateRoot | Out-Null

$profileParams = @{
    Port = $Port
}
if ($KoreanProfile) {
    $profileParams.Korean = $true
}

$profileDir = & (Join-Path $PSScriptRoot "create-400-wild-profile.ps1") @profileParams
$manifestPath = Join-Path $gateRoot "runtime-manifest.json"
& (Join-Path $PSScriptRoot "collect-runtime-manifest.ps1") -OutputFile $manifestPath | Out-Null

$runName = "fast-gate-$stamp"
$baselineParams = @{
    AcceptLgpl = $true
    Port = $Port
    DurationSeconds = $DurationSeconds
    RunName = $runName
    ProfileDir = $profileDir
    RunChunkCacheProbe = $true
}
if ($RunRakPingBurst) {
    $baselineParams.RunRakPingBurst = $true
    $baselineParams.RakPingCount = $RakPingCount
    $baselineParams.RakPingTimeoutMs = $RakPingTimeoutMs
    $baselineParams.RakPingBatchSize = $RakPingBatchSize
    $baselineParams.RakPingBatchDelayUs = $RakPingBatchDelayUs
}
$baselineDir = & (Join-Path $PSScriptRoot "run-source-baseline.ps1") @baselineParams

$summaryPath = Join-Path $gateRoot "baseline-summary.json"
& (Join-Path $PSScriptRoot "summarize-baseline-runs.ps1") -Limit 1 -Json | Set-Content -LiteralPath $summaryPath -Encoding UTF8
$logRiskPath = Join-Path $gateRoot "log-risk-report.json"
& (Join-Path $PSScriptRoot "analyze-baseline-log.ps1") -RunDir $baselineDir -Json | Set-Content -LiteralPath $logRiskPath -Encoding UTF8
$configAuditPath = Join-Path $gateRoot "perf-config-audit.json"
& (Join-Path $PSScriptRoot "audit-perf-config.ps1") | Set-Content -LiteralPath $configAuditPath -Encoding UTF8
$chunkBudgetPath = Join-Path $gateRoot "chunk-budget.json"
& (Join-Path $PSScriptRoot "estimate-chunk-budget.ps1") -Players 400 -ViewDistance 4 -ChunksPerTick 2 -TickRate 20 -MovingPlayersRatio 0.25 | Set-Content -LiteralPath $chunkBudgetPath -Encoding UTF8
$pluginAuditPath = Join-Path $gateRoot "plugin-hotpath-report.json"
& (Join-Path $PSScriptRoot "audit-plugin-hotpaths.ps1") | Set-Content -LiteralPath $pluginAuditPath -Encoding UTF8
$hotpathBenchPath = Join-Path $gateRoot "hotpath-bench.json"
if ($RunHotpathBench) {
    & (Join-Path $root "bin/php/php.exe") (Join-Path $PSScriptRoot "bench-hotpaths.php") --iterations=2000 --radius=4 | Set-Content -LiteralPath $hotpathBenchPath -Encoding UTF8
}

$phpstanExit = $null
$phpstanOutputPath = Join-Path $gateRoot "phpstan.txt"
if (-not $SkipPhpStan) {
    $drive = "P:"
    $mapped = $false
    $existing = & subst
    if (($existing -join "`n") -notmatch "^P:\\") {
        & subst $drive $root
        $mapped = $true
    }

    try {
        $php = "P:\bin\php\php.exe"
        $phpstan = "P:\vendor\bin\phpstan"
        $config = "P:\phpstan.neon.dist"
        $files = @(
            "P:\src\Server.php",
            "P:\src\scheduler\AsyncPool.php",
            "P:\src\network\mcpe\StandardPacketBroadcaster.php",
            "P:\src\network\mcpe\InventoryManager.php",
            "P:\src\network\mcpe\compression\CompressBatchPromise.php",
            "P:\src\network\mcpe\NetworkBroadcastUtils.php",
            "P:\src\network\mcpe\StandardEntityEventBroadcaster.php",
            "P:\src\network\mcpe\handler\InGamePacketHandler.php",
            "P:\src\network\mcpe\handler\ResourcePacksPacketHandler.php",
            "P:\src\network\mcpe\cache\CraftingDataCache.php",
            "P:\src\network\mcpe\cache\ChunkCache.php",
            "P:\src\network\mcpe\convert\BlockStateDictionary.php",
            "P:\src\player\ChunkSelector.php",
            "P:\src\network\mcpe\serializer\ChunkSerializer.php",
            "P:\src\network\mcpe\ChunkRequestTask.php",
            "P:\src\world\format\Chunk.php",
            "P:\src\world\format\SubChunk.php",
            "P:\src\world\format\io\FastChunkSerializer.php",
            "P:\src\world\format\io\leveldb\LevelDB.php",
            "P:\src\world\World.php",
            "P:\src\world\Explosion.php",
            "P:\src\entity\AttributeMap.php",
            "P:\src\entity\Entity.php",
            "P:\src\entity\effect\EffectCollection.php",
            "P:\src\entity\Human.php",
            "P:\src\entity\Living.php",
            "P:\src\entity\Squid.php",
            "P:\src\entity\projectile\Arrow.php",
            "P:\src\entity\projectile\Projectile.php",
            "P:\src\entity\projectile\SplashPotion.php",
            "P:\src\entity\object\FallingBlock.php",
            "P:\src\entity\object\ExperienceOrb.php",
            "P:\src\entity\object\ItemEntity.php",
            "P:\src\entity\object\AreaEffectCloud.php",
            "P:\src\entity\object\FireworkRocket.php",
            "P:\src\entity\object\Painting.php",
            "P:\src\entity\utils\ExperienceUtils.php",
            "P:\src\inventory\BaseInventory.php",
            "P:\src\inventory\CreativeInventory.php",
            "P:\src\inventory\PlayerOffHandInventory.php",
            "P:\src\inventory\SimpleInventory.php",
            "P:\src\player\Player.php",
            "P:\src\player\SurvivalBlockBreakHandler.php",
            "P:\src\network\mcpe\convert\ItemTranslator.php",
            "P:\src\world\format\io\data\BedrockWorldData.php",
            "P:\src\world\format\io\region\RegionLocationTableEntry.php",
            "P:\src\world\generator\FlatGeneratorOptions.php",
            "P:\src\world\generator\Gaussian.php",
            "P:\src\world\generator\PopulationTask.php",
            "P:\vendor\pocketmine\bedrock-protocol\src\PacketPool.php",
            "P:\vendor\pocketmine\bedrock-protocol\src\serializer\PacketBatch.php",
            "P:\tools\bench-hotpaths.php",
            "P:\tools\rak-ping-burst.php"
        )
        Push-Location "P:\"
        try {
            & $php "-dmemory_limit=512M" $phpstan analyse -c $config @files --no-progress --error-format=raw > $phpstanOutputPath 2>&1
            $phpstanExit = $LASTEXITCODE
        } finally {
            Pop-Location
        }
    } finally {
        if ($mapped) {
            & subst $drive /D
        }
    }
}

$baselineSummary = Get-Content -LiteralPath (Join-Path $baselineDir "run-summary.json") -Raw | ConvertFrom-Json
$logRisk = Get-Content -LiteralPath $logRiskPath -Raw | ConvertFrom-Json
$chunkCacheStats = if ($logRisk.chunk_cache -ne $null) { $logRisk.chunk_cache } else { $null }
$chunkCacheProbe = if ($logRisk.chunk_cache_probe -ne $null) { $logRisk.chunk_cache_probe } else { $null }
$chunkBudgetPressure = if ($logRisk.chunk_budget_pressure -ne $null) { $logRisk.chunk_budget_pressure } else { $null }
$chunkPopulationStats = if ($logRisk.chunk_population_stats -ne $null) { $logRisk.chunk_population_stats } else { $null }
$configAudit = Get-Content -LiteralPath $configAuditPath -Raw | ConvertFrom-Json
$chunkBudget = Get-Content -LiteralPath $chunkBudgetPath -Raw | ConvertFrom-Json
$pluginAudit = Get-Content -LiteralPath $pluginAuditPath -Raw | ConvertFrom-Json
$hotpathBench = if (Test-Path -LiteralPath $hotpathBenchPath) { Get-Content -LiteralPath $hotpathBenchPath -Raw | ConvertFrom-Json } else { $null }
$gateExit = 0
if (-not [bool]$baselineSummary.ready) {
    $gateExit = 2
}
if ([int]$baselineSummary.fatal_log_matches -gt 0) {
    $gateExit = 3
}
if ($phpstanExit -ne $null -and $phpstanExit -ne 0) {
    $gateExit = 4
}
if ($configAudit.verdict -eq "fail") {
    $gateExit = 5
}
if ($logRisk.risk_level -eq "fail") {
    $gateExit = 6
}
if ($RunRakPingBurst -and $baselineSummary.rak_ping -ne $null -and [double]$baselineSummary.rak_ping.loss_percent -gt 10.0) {
    $gateExit = 7
}

$result = [pscustomobject]@{
    gate_name = $stamp
    gate_root = $gateRoot
    profile_dir = $profileDir
    baseline_dir = $baselineDir
    ready = [bool]$baselineSummary.ready
    ready_seconds = $baselineSummary.ready_seconds
    fatal_log_matches = $baselineSummary.fatal_log_matches
    process_samples = $baselineSummary.process.sample_count
    max_working_set_mb = $baselineSummary.process.max_working_set_mb
    max_private_mb = $baselineSummary.process.max_private_mb
    max_threads = $baselineSummary.process.max_threads
    max_handles = $baselineSummary.process.max_handles
    rak_ping_sent = if ($baselineSummary.rak_ping -ne $null) { $baselineSummary.rak_ping.sent } else { $null }
    rak_ping_received = if ($baselineSummary.rak_ping -ne $null) { $baselineSummary.rak_ping.received } else { $null }
    rak_ping_loss_percent = if ($baselineSummary.rak_ping -ne $null) { $baselineSummary.rak_ping.loss_percent } else { $null }
    rak_ping_latency_avg_ms = if ($baselineSummary.rak_ping -ne $null) { $baselineSummary.rak_ping.latency_ms_avg } else { $null }
    phpstan_exit = $phpstanExit
    log_risk = $logRisk.risk_level
    chunk_cache_reports = if ($chunkCacheStats -ne $null) { $chunkCacheStats.reports } else { $null }
    chunk_cache_hits = if ($chunkCacheStats -ne $null) { $chunkCacheStats.hits } else { $null }
    chunk_cache_misses = if ($chunkCacheStats -ne $null) { $chunkCacheStats.misses } else { $null }
    chunk_cache_prefetch_attempts = if ($chunkCacheStats -ne $null) { $chunkCacheStats.prefetch_attempts } else { $null }
    chunk_cache_prefetch_started = if ($chunkCacheStats -ne $null) { $chunkCacheStats.prefetch_started } else { $null }
    chunk_cache_prefetch_skipped_cached = if ($chunkCacheStats -ne $null) { $chunkCacheStats.prefetch_skipped_cached } else { $null }
    chunk_cache_prefetch_skipped_unloaded = if ($chunkCacheStats -ne $null) { $chunkCacheStats.prefetch_skipped_unloaded } else { $null }
    chunk_cache_prefetch_promise_hits = if ($chunkCacheStats -ne $null) { $chunkCacheStats.prefetch_promise_hits } else { $null }
    chunk_cache_prefetch_packet_hits = if ($chunkCacheStats -ne $null) { $chunkCacheStats.prefetch_packet_hits } else { $null }
    chunk_cache_probe_reports = if ($chunkCacheProbe -ne $null) { $chunkCacheProbe.reports } else { $null }
    chunk_cache_probe_ok = if ($chunkCacheProbe -ne $null) { $chunkCacheProbe.ok } else { $null }
    chunk_cache_probe_failed = if ($chunkCacheProbe -ne $null) { $chunkCacheProbe.failed } else { $null }
    chunk_cache_probe_targets = if ($chunkCacheProbe -ne $null) { $chunkCacheProbe.targets } else { $null }
    chunk_cache_probe_prefetch_started = if ($chunkCacheProbe -ne $null) { $chunkCacheProbe.prefetch_started_probe } else { $null }
    chunk_cache_probe_promise_requests = if ($chunkCacheProbe -ne $null) { $chunkCacheProbe.promise_requests_probe } else { $null }
    chunk_cache_probe_packet_requests = if ($chunkCacheProbe -ne $null) { $chunkCacheProbe.packet_requests_probe } else { $null }
    chunk_cache_probe_stat_prefetch_attempts = if ($chunkCacheProbe -ne $null) { $chunkCacheProbe.prefetch_attempts } else { $null }
    chunk_cache_probe_stat_prefetch_started = if ($chunkCacheProbe -ne $null) { $chunkCacheProbe.prefetch_started } else { $null }
    chunk_cache_probe_stat_prefetch_promise_hits = if ($chunkCacheProbe -ne $null) { $chunkCacheProbe.prefetch_promise_hits } else { $null }
    chunk_cache_probe_stat_prefetch_packet_hits = if ($chunkCacheProbe -ne $null) { $chunkCacheProbe.prefetch_packet_hits } else { $null }
    chunk_cache_probe_stat_hits = if ($chunkCacheProbe -ne $null) { $chunkCacheProbe.hits } else { $null }
    chunk_cache_probe_stat_misses = if ($chunkCacheProbe -ne $null) { $chunkCacheProbe.misses } else { $null }
    chunk_budget_pressure_reports = if ($chunkBudgetPressure -ne $null) { $chunkBudgetPressure.reports } else { $null }
    chunk_budget_pressure_scale_total = if ($chunkBudgetPressure -ne $null) { $chunkBudgetPressure.scale_total } else { $null }
    chunk_budget_pressure_scale_min = if ($chunkBudgetPressure -ne $null) { $chunkBudgetPressure.scale_min } else { $null }
    chunk_budget_pressure_scale_max = if ($chunkBudgetPressure -ne $null) { $chunkBudgetPressure.scale_max } else { $null }
    chunk_budget_pressure_pending_total = if ($chunkBudgetPressure -ne $null) { $chunkBudgetPressure.pending_total } else { $null }
    chunk_budget_pressure_async_backlog_total = if ($chunkBudgetPressure -ne $null) { $chunkBudgetPressure.async_backlog_total } else { $null }
    chunk_budget_pressure_population_prefetch_started_total = if ($chunkBudgetPressure -ne $null) { $chunkBudgetPressure.population_prefetch_started_total } else { $null }
    chunk_budget_pressure_population_prefetch_resolved_total = if ($chunkBudgetPressure -ne $null) { $chunkBudgetPressure.population_prefetch_resolved_total } else { $null }
    chunk_budget_pressure_population_prefetch_stale_total = if ($chunkBudgetPressure -ne $null) { $chunkBudgetPressure.population_prefetch_stale_total } else { $null }
    chunk_budget_pressure_population_prefetch_active_total = if ($chunkBudgetPressure -ne $null) { $chunkBudgetPressure.population_prefetch_active_total } else { $null }
    chunk_population_reports = if ($chunkPopulationStats -ne $null) { $chunkPopulationStats.reports } else { $null }
    chunk_population_requests_total = if ($chunkPopulationStats -ne $null) { $chunkPopulationStats.requests_total } else { $null }
    chunk_population_shared_hits_total = if ($chunkPopulationStats -ne $null) { $chunkPopulationStats.shared_hits_total } else { $null }
    chunk_population_queued_total = if ($chunkPopulationStats -ne $null) { $chunkPopulationStats.queued_total } else { $null }
    chunk_population_queue_duplicates_total = if ($chunkPopulationStats -ne $null) { $chunkPopulationStats.queue_duplicates_total } else { $null }
    chunk_population_started_total = if ($chunkPopulationStats -ne $null) { $chunkPopulationStats.started_total } else { $null }
    chunk_population_resolved_total = if ($chunkPopulationStats -ne $null) { $chunkPopulationStats.resolved_total } else { $null }
    chunk_population_rejected_total = if ($chunkPopulationStats -ne $null) { $chunkPopulationStats.rejected_total } else { $null }
    chunk_population_active_total = if ($chunkPopulationStats -ne $null) { $chunkPopulationStats.active_total } else { $null }
    chunk_population_pending_total = if ($chunkPopulationStats -ne $null) { $chunkPopulationStats.pending_total } else { $null }
    chunk_population_queued_unique_total = if ($chunkPopulationStats -ne $null) { $chunkPopulationStats.queued_unique_total } else { $null }
    config_audit = $configAudit.verdict
    chunk_budget = $chunkBudget.verdict
    plugin_audit = $pluginAudit.verdict
    chunk_selector_chunks_per_second = if ($hotpathBench -ne $null) { $hotpathBench.chunk_selector.chunks_per_second } else { $null }
    chunk_prefetch_priority_selections_per_second = if ($hotpathBench -ne $null -and $hotpathBench.chunk_prefetch_priority -ne $null) { $hotpathBench.chunk_prefetch_priority.selections_per_second } else { $null }
    chunk_prefetch_priority_baseline_front_selected = if ($hotpathBench -ne $null -and $hotpathBench.chunk_prefetch_priority -ne $null) { $hotpathBench.chunk_prefetch_priority.baseline_front_selected } else { $null }
    chunk_prefetch_priority_biased_front_selected = if ($hotpathBench -ne $null -and $hotpathBench.chunk_prefetch_priority -ne $null) { $hotpathBench.chunk_prefetch_priority.biased_front_selected } else { $null }
    chunk_prefetch_priority_biased_total_selected = if ($hotpathBench -ne $null -and $hotpathBench.chunk_prefetch_priority -ne $null) { $hotpathBench.chunk_prefetch_priority.biased_total_selected } else { $null }
    varint_cases_per_second = if ($hotpathBench -ne $null) { $hotpathBench.varint_lengths.cases_per_second } else { $null }
    item_translator_conversions_per_second = if ($hotpathBench -ne $null) { $hotpathBench.item_translator.conversions_per_second } else { $null }
    simple_inventory_adds_per_second = if ($hotpathBench -ne $null -and $hotpathBench.simple_inventory_add -ne $null) { $hotpathBench.simple_inventory_add.item_adds_per_second } else { $null }
    packet_batch_raw_batches_per_second = if ($hotpathBench -ne $null -and $hotpathBench.packet_batch_raw -ne $null) { $hotpathBench.packet_batch_raw.packet_batch_batches_per_second } else { $null }
    packet_batch_raw_native_loaded = if ($hotpathBench -ne $null -and $hotpathBench.packet_batch_raw -ne $null) { $hotpathBench.packet_batch_raw.native_extension_loaded } else { $null }
    packet_encoding_packets_per_second = if ($hotpathBench -ne $null -and $hotpathBench.packet_encoding -ne $null) { $hotpathBench.packet_encoding.packets_per_second } else { $null }
    packet_decoding_packets_per_second = if ($hotpathBench -ne $null -and $hotpathBench.packet_decoding -ne $null) { $hotpathBench.packet_decoding.packets_per_second } else { $null }
    packet_decoding_generator_packets_per_second = if ($hotpathBench -ne $null -and $hotpathBench.packet_decoding -ne $null) { $hotpathBench.packet_decoding.generator_packets_per_second } else { $null }
    packet_decoding_callback_packets_per_second = if ($hotpathBench -ne $null -and $hotpathBench.packet_decoding -ne $null) { $hotpathBench.packet_decoding.callback_packets_per_second } else { $null }
    packet_decoding_native_string_packets_per_second = if ($hotpathBench -ne $null -and $hotpathBench.packet_decoding -ne $null) { $hotpathBench.packet_decoding.native_string_packets_per_second } else { $null }
    packet_decoding_native_loaded = if ($hotpathBench -ne $null -and $hotpathBench.packet_decoding -ne $null) { $hotpathBench.packet_decoding.native_extension_loaded } else { $null }
    packet_pool_lookups_per_second = if ($hotpathBench -ne $null -and $hotpathBench.packet_pool_lookup -ne $null) { $hotpathBench.packet_pool_lookup.lookups_per_second } else { $null }
    block_update_packets_per_second = if ($hotpathBench -ne $null -and $hotpathBench.block_update_packets -ne $null) { $hotpathBench.block_update_packets.packets_per_second } else { $null }
    block_state_data_lookups_per_second = if ($hotpathBench -ne $null -and $hotpathBench.block_update_packets -ne $null) { $hotpathBench.block_update_packets.state_data_lookups_per_second } else { $null }
    nearby_entity_array_entities_per_second = if ($hotpathBench -ne $null -and $hotpathBench.nearby_entity_iteration -ne $null) { $hotpathBench.nearby_entity_iteration.array_entities_per_second } else { $null }
    nearby_entity_callback_entities_per_second = if ($hotpathBench -ne $null -and $hotpathBench.nearby_entity_iteration -ne $null) { $hotpathBench.nearby_entity_iteration.callback_entities_per_second } else { $null }
    nearby_entity_boolean_queries_per_second = if ($hotpathBench -ne $null -and $hotpathBench.nearby_entity_iteration -ne $null) { $hotpathBench.nearby_entity_iteration.boolean_queries_per_second } else { $null }
    subchunk_serialization_per_second = if ($hotpathBench -ne $null -and $hotpathBench.subchunk_serialization -ne $null) { $hotpathBench.subchunk_serialization.subchunks_per_second } else { $null }
    full_chunk_serialization_per_second = if ($hotpathBench -ne $null -and $hotpathBench.full_chunk_serialization -ne $null) { $hotpathBench.full_chunk_serialization.chunks_per_second } else { $null }
    full_chunk_serialization_native_loaded = if ($hotpathBench -ne $null -and $hotpathBench.full_chunk_serialization -ne $null) { $hotpathBench.full_chunk_serialization.native_extension_loaded } else { $null }
    fast_chunk_serializer_serialize_per_second = if ($hotpathBench -ne $null -and $hotpathBench.fast_chunk_serializer -ne $null) { $hotpathBench.fast_chunk_serializer.serialize_chunks_per_second } else { $null }
    fast_chunk_serializer_deserialize_per_second = if ($hotpathBench -ne $null -and $hotpathBench.fast_chunk_serializer -ne $null) { $hotpathBench.fast_chunk_serializer.deserialize_chunks_per_second } else { $null }
    fast_chunk_serializer_native_pack_loaded = if ($hotpathBench -ne $null -and $hotpathBench.fast_chunk_serializer -ne $null) { $hotpathBench.fast_chunk_serializer.native_pack_loaded } else { $null }
    fast_chunk_serializer_native_unpack_loaded = if ($hotpathBench -ne $null -and $hotpathBench.fast_chunk_serializer -ne $null) { $hotpathBench.fast_chunk_serializer.native_unpack_loaded } else { $null }
    compression_batches_per_second = if ($hotpathBench -ne $null -and $hotpathBench.compression -ne $null) { $hotpathBench.compression.batches_per_second } else { $null }
    mining_progress_updates_per_second = if ($hotpathBench -ne $null -and $hotpathBench.mining_progress -ne $null) { $hotpathBench.mining_progress.updates_per_second } else { $null }
    movement_process_updates_per_second = if ($hotpathBench -ne $null -and $hotpathBench.movement_process -ne $null) { $hotpathBench.movement_process.updates_per_second } else { $null }
    chunk_pressure_snapshots_per_second = if ($hotpathBench -ne $null -and $hotpathBench.chunk_pressure_snapshot -ne $null) { $hotpathBench.chunk_pressure_snapshot.snapshots_per_second } else { $null }
    chunk_pressure_pending_accumulator = if ($hotpathBench -ne $null -and $hotpathBench.chunk_pressure_snapshot -ne $null) { $hotpathBench.chunk_pressure_snapshot.pending_accumulator } else { $null }
    global_chunk_budget_decisions_per_second = if ($hotpathBench -ne $null -and $hotpathBench.global_chunk_budget -ne $null) { $hotpathBench.global_chunk_budget.decisions_per_second } else { $null }
    global_chunk_budget_scale_accumulator = if ($hotpathBench -ne $null -and $hotpathBench.global_chunk_budget -ne $null) { $hotpathBench.global_chunk_budget.scale_accumulator } else { $null }
    population_prefetch_selection_candidates_per_second = if ($hotpathBench -ne $null -and $hotpathBench.population_prefetch_selection -ne $null) { $hotpathBench.population_prefetch_selection.candidates_per_second } else { $null }
    population_prefetch_selection_candidates = if ($hotpathBench -ne $null -and $hotpathBench.population_prefetch_selection -ne $null) { $hotpathBench.population_prefetch_selection.candidates } else { $null }
    population_prefetch_selection_active_skips = if ($hotpathBench -ne $null -and $hotpathBench.population_prefetch_selection -ne $null) { $hotpathBench.population_prefetch_selection.active_skips } else { $null }
    population_prefetch_selection_stale_completions = if ($hotpathBench -ne $null -and $hotpathBench.population_prefetch_selection -ne $null) { $hotpathBench.population_prefetch_selection.stale_completions } else { $null }
    chunk_population_coalescing_requests_per_second = if ($hotpathBench -ne $null -and $hotpathBench.chunk_population_coalescing -ne $null) { $hotpathBench.chunk_population_coalescing.requests_per_second } else { $null }
    chunk_population_coalescing_requests = if ($hotpathBench -ne $null -and $hotpathBench.chunk_population_coalescing -ne $null) { $hotpathBench.chunk_population_coalescing.requests } else { $null }
    chunk_population_coalescing_unique_requests = if ($hotpathBench -ne $null -and $hotpathBench.chunk_population_coalescing -ne $null) { $hotpathBench.chunk_population_coalescing.unique_requests } else { $null }
    chunk_population_coalescing_shared_hits = if ($hotpathBench -ne $null -and $hotpathBench.chunk_population_coalescing -ne $null) { $hotpathBench.chunk_population_coalescing.shared_hits } else { $null }
    exit_code = $gateExit
}

$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $gateRoot "gate-summary.json") -Encoding UTF8
$result | ConvertTo-Json -Depth 4
exit $gateExit
