param(
    [int]$Iterations = 300,
    [int]$Samples = 3,
    [double]$MinPacketBatchBatchesPerSecond = 1000000,
    [double]$MinPacketBatchVsPhpRatio = 1.5,
    [double]$MinNativeDecodePacketsPerSecond = 650000,
    [double]$MinFullChunkChunksPerSecond = 50000,
    [double]$MinFastChunkSerializeChunksPerSecond = 30000,
    [switch]$NoExitCode
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$evidenceDir = Join-Path $rootPath "var/perf/native-performance-gate"
$latestEvidencePath = Join-Path $evidenceDir "staged-native-performance-gate-last.json"
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null

if($Samples -lt 1){
    throw "Samples must be greater than or equal to 1"
}

function New-GateSample([object]$Bench, [int]$Index){
    $packetBatchRate = [double]$Bench.packet_batch_raw.packet_batch_batches_per_second
    $packetBatchReferenceRate = [double]$Bench.packet_batch_raw.php_reference_batches_per_second
    $packetBatchRatio = if($packetBatchReferenceRate -gt 0){ $packetBatchRate / $packetBatchReferenceRate }else{ 0.0 }
    $decodeRate = [double]$Bench.packet_decoding.native_string_packets_per_second
    $fullChunkRate = [double]$Bench.full_chunk_serialization.chunks_per_second
    $fastChunkSerializeRate = [double]$Bench.fast_chunk_serializer.serialize_chunks_per_second

    $failures = @()
    if($Bench.native_loaded -ne $true){
        $failures += "staged native extension was not loaded"
    }
    if($packetBatchRate -lt $MinPacketBatchBatchesPerSecond){
        $failures += "packet batch rate $packetBatchRate below $MinPacketBatchBatchesPerSecond"
    }
    if($packetBatchRatio -lt $MinPacketBatchVsPhpRatio){
        $failures += "packet batch native/PHP ratio $packetBatchRatio below $MinPacketBatchVsPhpRatio"
    }
    if($decodeRate -lt $MinNativeDecodePacketsPerSecond){
        $failures += "native packet decode rate $decodeRate below $MinNativeDecodePacketsPerSecond"
    }
    if($fullChunkRate -lt $MinFullChunkChunksPerSecond){
        $failures += "full chunk serialization rate $fullChunkRate below $MinFullChunkChunksPerSecond"
    }
    if($fastChunkSerializeRate -lt $MinFastChunkSerializeChunksPerSecond){
        $failures += "fast chunk serialize rate $fastChunkSerializeRate below $MinFastChunkSerializeChunksPerSecond"
    }

    [pscustomobject]@{
        sample = $Index
        passed = $failures.Count -eq 0
        metrics = [pscustomobject]@{
            packet_batch_batches_per_second = $packetBatchRate
            packet_batch_php_reference_batches_per_second = $packetBatchReferenceRate
            packet_batch_vs_php_ratio = $packetBatchRatio
            native_decode_packets_per_second = $decodeRate
            full_chunk_chunks_per_second = $fullChunkRate
            fast_chunk_serialize_chunks_per_second = $fastChunkSerializeRate
        }
        failures = $failures
        bench = $Bench
    }
}

$sampleResults = New-Object System.Collections.Generic.List[object]
for($i = 1; $i -le $Samples; ++$i){
    $bench = & (Join-Path $PSScriptRoot "bench-staged-native-hotpaths.ps1") -Iterations $Iterations | ConvertFrom-Json
    $sample = New-GateSample $bench $i
    $sampleResults.Add($sample) | Out-Null
}

$firstSample = $sampleResults[0]
$bestMetrics = [pscustomobject]@{
    packet_batch_batches_per_second = [double]($sampleResults | ForEach-Object { $_.metrics.packet_batch_batches_per_second } | Measure-Object -Maximum).Maximum
    packet_batch_php_reference_batches_per_second = [double]($sampleResults | ForEach-Object { $_.metrics.packet_batch_php_reference_batches_per_second } | Measure-Object -Maximum).Maximum
    packet_batch_vs_php_ratio = [double]($sampleResults | ForEach-Object { $_.metrics.packet_batch_vs_php_ratio } | Measure-Object -Maximum).Maximum
    native_decode_packets_per_second = [double]($sampleResults | ForEach-Object { $_.metrics.native_decode_packets_per_second } | Measure-Object -Maximum).Maximum
    full_chunk_chunks_per_second = [double]($sampleResults | ForEach-Object { $_.metrics.full_chunk_chunks_per_second } | Measure-Object -Maximum).Maximum
    fast_chunk_serialize_chunks_per_second = [double]($sampleResults | ForEach-Object { $_.metrics.fast_chunk_serialize_chunks_per_second } | Measure-Object -Maximum).Maximum
}
$failures = @()
if($firstSample.bench.native_loaded -ne $true){
    $failures += "staged native extension was not loaded"
}
if($bestMetrics.packet_batch_batches_per_second -lt $MinPacketBatchBatchesPerSecond){
    $failures += "best packet batch rate $($bestMetrics.packet_batch_batches_per_second) below $MinPacketBatchBatchesPerSecond"
}
if($bestMetrics.packet_batch_vs_php_ratio -lt $MinPacketBatchVsPhpRatio){
    $failures += "best packet batch native/PHP ratio $($bestMetrics.packet_batch_vs_php_ratio) below $MinPacketBatchVsPhpRatio"
}
if($bestMetrics.native_decode_packets_per_second -lt $MinNativeDecodePacketsPerSecond){
    $failures += "best native packet decode rate $($bestMetrics.native_decode_packets_per_second) below $MinNativeDecodePacketsPerSecond"
}
if($bestMetrics.full_chunk_chunks_per_second -lt $MinFullChunkChunksPerSecond){
    $failures += "best full chunk serialization rate $($bestMetrics.full_chunk_chunks_per_second) below $MinFullChunkChunksPerSecond"
}
if($bestMetrics.fast_chunk_serialize_chunks_per_second -lt $MinFastChunkSerializeChunksPerSecond){
    $failures += "best fast chunk serialize rate $($bestMetrics.fast_chunk_serialize_chunks_per_second) below $MinFastChunkSerializeChunksPerSecond"
}
$passed = $failures.Count -eq 0
$result = [pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    passed = $passed
    root = $rootPath
    staged_dll = $firstSample.bench.staged_dll
    staged_sha256 = $firstSample.bench.staged_sha256
    iterations = $Iterations
    samples_requested = $Samples
    samples_run = $sampleResults.Count
    metric_policy = "best_of_samples"
    thresholds = [pscustomobject]@{
        min_packet_batch_batches_per_second = $MinPacketBatchBatchesPerSecond
        min_packet_batch_vs_php_ratio = $MinPacketBatchVsPhpRatio
        min_native_decode_packets_per_second = $MinNativeDecodePacketsPerSecond
        min_full_chunk_chunks_per_second = $MinFullChunkChunksPerSecond
        min_fast_chunk_serialize_chunks_per_second = $MinFastChunkSerializeChunksPerSecond
    }
    metrics = $bestMetrics
    failures = $failures
    sample_results = $sampleResults.ToArray()
    bench = $firstSample.bench
}
$json = $result | ConvertTo-Json -Depth 10
$json | Set-Content -LiteralPath $latestEvidencePath -Encoding UTF8
$json

if(-not $passed -and -not $NoExitCode){
    exit 12
}
