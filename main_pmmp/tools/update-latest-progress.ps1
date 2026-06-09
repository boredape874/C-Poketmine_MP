param(
    [string]$ProgressPath = "..\plan_md\PMMP_latest_progress_2026-06-07.md",
    [string]$CompareJsonPath = $null
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$progressFile = Resolve-Path (Join-Path $rootPath $ProgressPath)
$progressFilePath = $progressFile.Path
$gateRoot = Join-Path $rootPath "var/perf/gates"

if(-not (Test-Path -LiteralPath $gateRoot)){
    throw "No gate directory found at $gateRoot"
}

$latestGate = Get-ChildItem -LiteralPath $gateRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if($latestGate -eq $null){
    throw "No gate run directories found at $gateRoot"
}

$summaryPath = Join-Path $latestGate.FullName "gate-summary.json"
if(-not (Test-Path -LiteralPath $summaryPath)){
    throw "Latest gate does not contain gate-summary.json: $($latestGate.FullName)"
}

$summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
$codeTick = [char]96
function Format-CodeValue($Value){
    if($null -eq $Value){
        return "${codeTick}null${codeTick}"
    }
    return "$codeTick$Value$codeTick"
}

$gateName = Format-CodeValue $summary.gate_name
$readySeconds = Format-CodeValue $summary.ready_seconds
$fatalLogMatches = Format-CodeValue $summary.fatal_log_matches
$phpStanExit = Format-CodeValue $summary.phpstan_exit
$chunkSelector = Format-CodeValue $summary.chunk_selector_chunks_per_second
$varintCases = Format-CodeValue $summary.varint_cases_per_second
$itemTranslator = Format-CodeValue $summary.item_translator_conversions_per_second
$simpleInventory = Format-CodeValue $summary.simple_inventory_adds_per_second
$packetEncoding = Format-CodeValue $summary.packet_encoding_packets_per_second
$packetDecoding = Format-CodeValue $summary.packet_decoding_packets_per_second
$packetPoolLookup = Format-CodeValue $summary.packet_pool_lookups_per_second
$blockUpdatePackets = Format-CodeValue $summary.block_update_packets_per_second
$blockStateDataLookups = Format-CodeValue $summary.block_state_data_lookups_per_second
$nearbyEntityArray = Format-CodeValue $summary.nearby_entity_array_entities_per_second
$nearbyEntityCallback = Format-CodeValue $summary.nearby_entity_callback_entities_per_second
$nearbyEntityBoolean = Format-CodeValue $summary.nearby_entity_boolean_queries_per_second
$subchunkSerialization = Format-CodeValue $summary.subchunk_serialization_per_second
$compressionBatches = Format-CodeValue $summary.compression_batches_per_second
$miningProgress = Format-CodeValue $summary.mining_progress_updates_per_second
$movementProcess = Format-CodeValue $summary.movement_process_updates_per_second
$compareVerdict = "unknown"
$compareBase = "unknown"
if(-not [string]::IsNullOrWhiteSpace($CompareJsonPath) -and (Test-Path -LiteralPath $CompareJsonPath)){
    $compare = Get-Content -LiteralPath $CompareJsonPath -Raw | ConvertFrom-Json
    $compareVerdict = $compare.verdict
    $compareBase = $compare.base.run_name
}

$content = Get-Content -LiteralPath $progressFile -Raw

$latestGateBlock = @"
## Latest gate

- gate: $gateName
- ready: $($summary.ready)
- ready seconds: $readySeconds
- fatal log matches: $fatalLogMatches
- PHPStan exit: $phpStanExit
- config audit: $($summary.config_audit)
- chunk budget: $($summary.chunk_budget)
- plugin audit: $($summary.plugin_audit)
- compare verdict vs $(Format-CodeValue $compareBase): $compareVerdict
"@

$hotpathBlock = @"
## Hotpath bench

- chunk selector chunks/sec: $chunkSelector
- varint cases/sec: $varintCases
- item translator conversions/sec: $itemTranslator
- simple inventory adds/sec: $simpleInventory
- packet encoding packets/sec: $packetEncoding
- packet decoding packets/sec: $packetDecoding
- packet pool lookups/sec: $packetPoolLookup
- block update packets/sec: $blockUpdatePackets
- block state data lookups/sec: $blockStateDataLookups
- nearby entity array entities/sec: $nearbyEntityArray
- nearby entity callback entities/sec: $nearbyEntityCallback
- nearby entity boolean queries/sec: $nearbyEntityBoolean
- subchunk serialization/sec: $subchunkSerialization
- compression batches/sec: $compressionBatches
- mining progress updates/sec: $miningProgress
- movement process updates/sec: $movementProcess
"@

$content = [regex]::Replace($content, "(?s)## Latest gate\r?\n.*?(?=\r?\n## Hotpath bench)", $latestGateBlock.TrimEnd() + "`r`n`r`n")
$content = [regex]::Replace($content, "(?s)## Hotpath bench\r?\n.*?(?=\r?\n## Core changes added in this step)", $hotpathBlock.TrimEnd() + "`r`n`r`n")

Set-Content -LiteralPath $progressFilePath -Encoding UTF8 -Value $content

[pscustomobject]@{
    progress = $progressFilePath
    latest_gate = $summary.gate_name
    compare_base = $compareBase
    compare_verdict = $compareVerdict
} | ConvertTo-Json -Depth 4
