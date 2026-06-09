param(
    [int]$Port = 19132,
    [int]$DurationSeconds = 60,
    [string]$RunName = "",
    [string]$ProfileDir = "",
    [switch]$RunRakPingBurst,
    [int]$RakPingCount = 64,
    [int]$RakPingTimeoutMs = 1500,
    [int]$RakPingBatchSize = 64,
    [int]$RakPingBatchDelayUs = 0,
    [switch]$RunChunkCacheProbe,
    [switch]$AcceptLgpl
)

$ErrorActionPreference = "Stop"

if (-not $AcceptLgpl) {
    throw "LGPL license acceptance is required. Re-run with -AcceptLgpl after you have accepted the LICENSE in this PMMP directory."
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$stamp = if ($RunName -ne "") { $RunName } else { Get-Date -Format "yyyyMMdd-HHmmss" }
$runRoot = Join-Path $root "var/perf/baseline/$stamp"
$dataDir = Join-Path $runRoot "data"
$pluginsDir = Join-Path $runRoot "plugins"

New-Item -ItemType Directory -Force -Path $runRoot, $dataDir, $pluginsDir | Out-Null

if ($RunChunkCacheProbe) {
    $probeDir = Join-Path $pluginsDir "ChunkCacheProbe"
    $probeSrcDir = Join-Path $probeDir "src/PMMPPerf/ChunkCacheProbe"
    New-Item -ItemType Directory -Force -Path $probeSrcDir | Out-Null
@'
name: ChunkCacheProbe
main: PMMPPerf\ChunkCacheProbe\Main
src-namespace-prefix: PMMPPerf\ChunkCacheProbe
version: 0.1.0
api: 5.0.0
load: POSTWORLD
'@ | Set-Content -LiteralPath (Join-Path $probeDir "plugin.yml") -Encoding ASCII
@'
<?php declare(strict_types=1);

namespace PMMPPerf\ChunkCacheProbe;

use pocketmine\network\mcpe\cache\ChunkCache;
use pocketmine\network\mcpe\compression\CompressBatchPromise;
use pocketmine\network\mcpe\compression\ZlibCompressor;
use pocketmine\plugin\PluginBase;
use pocketmine\promise\Promise;
use pocketmine\scheduler\ClosureTask;
use pocketmine\world\World;
use function count;
use function is_string;
use function json_encode;
use const JSON_THROW_ON_ERROR;

/**
 * @main PMMPPerf\ChunkCacheProbe\Main
 * @api 5.0.0
 * @version 0.1.0
 * @name ChunkCacheProbe
 * @load POSTWORLD
 */
class Main extends PluginBase{
	protected function onEnable() : void{
		$this->getScheduler()->scheduleDelayedTask(new ClosureTask(function() : void{
			$this->startProbe();
		}), 40);
	}

	private function startProbe() : void{
		$world = $this->getServer()->getWorldManager()->getDefaultWorld();
		if($world === null){
			$this->getLogger()->warning('PMMP_CHUNK_CACHE_PROBE {"ok":false,"reason":"no_default_world"}');
			return;
		}
		$spawn = $world->getSpawnLocation();
		$baseX = $spawn->getFloorX() >> 4;
		$baseZ = $spawn->getFloorZ() >> 4;
		$targets = [
			[$baseX, $baseZ],
			[$baseX + 1, $baseZ],
			[$baseX, $baseZ + 1],
			[$baseX + 1, $baseZ + 1],
		];
		$promises = [];
		foreach($targets as [$chunkX, $chunkZ]){
			$promises[] = $world->requestChunkPopulation($chunkX, $chunkZ, null);
		}
		Promise::all($promises)->onCompletion(
			function() use ($world, $targets) : void{
				$this->runProbe($world, $targets);
			},
			function() : void{
				$this->getLogger()->warning('PMMP_CHUNK_CACHE_PROBE {"ok":false,"reason":"population_failed"}');
			}
		);
	}

	/**
	 * @param array<int, array{int, int}> $targets
	 */
	private function runProbe(World $world, array $targets) : void{
		$cache = ChunkCache::getInstance($world, new ZlibCompressor(ZlibCompressor::DEFAULT_LEVEL, ZlibCompressor::DEFAULT_THRESHOLD, ZlibCompressor::DEFAULT_MAX_DECOMPRESSION_SIZE));
		$prefetchStarted = 0;
		$promiseRequests = 0;
		foreach($targets as [$chunkX, $chunkZ]){
			if($cache->prefetchIfLoaded($chunkX, $chunkZ)){
				++$prefetchStarted;
			}
		}
		foreach($targets as [$chunkX, $chunkZ]){
			if($cache->request($chunkX, $chunkZ) instanceof CompressBatchPromise){
				++$promiseRequests;
			}
		}
		$this->getScheduler()->scheduleDelayedTask(new ClosureTask(function() use ($world, $cache, $targets, $prefetchStarted, $promiseRequests) : void{
			$packetRequests = 0;
			foreach($targets as [$chunkX, $chunkZ]){
				if(is_string($cache->request($chunkX, $chunkZ))){
					++$packetRequests;
				}
			}
			$stats = $cache->getStats();
			$budgetPressure = $this->getServer()->getChunkSendBudgetPressure();
			$populationStats = $world->getChunkPopulationStats();
			$this->getLogger()->info('PMMP_CHUNK_CACHE_PROBE ' . json_encode([
				'ok' => true,
				'targets' => count($targets),
				'prefetch_started_probe' => $prefetchStarted,
				'promise_requests_probe' => $promiseRequests,
				'packet_requests_probe' => $packetRequests,
				'stats' => $stats,
			], JSON_THROW_ON_ERROR));
			$this->getLogger()->info('PMMP_CHUNK_BUDGET_PRESSURE ' . json_encode($budgetPressure, JSON_THROW_ON_ERROR));
			$this->getLogger()->info('PMMP_CHUNK_POPULATION_STATS ' . json_encode($populationStats, JSON_THROW_ON_ERROR));
		}), 80);
	}
}
'@ | Set-Content -LiteralPath (Join-Path $probeSrcDir "Main.php") -Encoding ASCII
    Copy-Item -LiteralPath (Join-Path $probeSrcDir "Main.php") -Destination (Join-Path $pluginsDir "ChunkCacheProbe.php") -Force
}

if ($ProfileDir -ne "") {
    $resolvedProfile = Resolve-Path $ProfileDir
    foreach ($fileName in @("server.properties", "pocketmine.yml")) {
        $profileFile = Join-Path $resolvedProfile $fileName
        if (Test-Path -LiteralPath $profileFile) {
            Copy-Item -LiteralPath $profileFile -Destination (Join-Path $dataDir $fileName) -Force
        }
    }
}

$serverProperties = Join-Path $dataDir "server.properties"
if (-not (Test-Path -LiteralPath $serverProperties)) {
@"
motd=PMMP Perf Baseline
server-port=$Port
server-portv6=0
enable-ipv6=false
white-list=false
max-players=20
gamemode=survival
force-gamemode=false
hardcore=false
pvp=true
difficulty=1
level-name=world
level-seed=
level-type=DEFAULT
enable-query=true
auto-save=true
view-distance=4
xbox-auth=false
language=eng
"@ | Set-Content -LiteralPath $serverProperties -Encoding ASCII
}

$pocketmineYml = Join-Path $dataDir "pocketmine.yml"
if (-not (Test-Path -LiteralPath $pocketmineYml)) {
    $content = Get-Content -LiteralPath (Join-Path $root "resources/pocketmine.yml") -Raw
    $content = $content.Replace("  enable-dev-builds: false", "  enable-dev-builds: true")
    $content = $content.Replace("  enable-profiling: false", "  enable-profiling: true")
    $content = $content.Replace("  profile-report-trigger: 20", "  profile-report-trigger: 18")
    $content | Set-Content -LiteralPath $pocketmineYml -Encoding UTF8
}

$manifestPath = Join-Path $runRoot "manifest.json"
& (Join-Path $PSScriptRoot "collect-runtime-manifest.ps1") -OutputFile $manifestPath | Out-Null

$php = Join-Path $root "bin/php/php.exe"
$versionPath = Join-Path $runRoot "version.txt"
& $php (Join-Path $root "src/PocketMine.php") --version 2>&1 | Set-Content -LiteralPath $versionPath -Encoding UTF8

$stdoutPath = Join-Path $runRoot "stdout.log"
$stderrPath = Join-Path $runRoot "stderr.log"
$summaryPath = Join-Path $runRoot "run-summary.json"
$commandPath = Join-Path $runRoot "command.txt"
$processSamplesPath = Join-Path $runRoot "process-samples.csv"
$rakPingPath = Join-Path $runRoot "rak-ping-burst.json"

$args = @(
    (Join-Path $root "src/PocketMine.php"),
    "--no-wizard",
    "--disable-ansi",
    "--data=$dataDir",
    "--plugins=$pluginsDir"
)

($php + " " + ($args -join " ")) | Set-Content -LiteralPath $commandPath -Encoding UTF8

$start = Get-Date
$process = Start-Process -FilePath $php -ArgumentList $args -WorkingDirectory $root -NoNewWindow -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
$ready = $false
$readyAt = $null
$rakPingDone = $false
$processSamples = New-Object System.Collections.Generic.List[object]
"timestamp,pid,cpu_seconds,working_set_mb,private_mb,threads,handles" | Set-Content -LiteralPath $processSamplesPath -Encoding ASCII

function Add-SharedAsciiLine([string]$Path, [string]$Line)
{
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($Line + "`r`n")
    for($attempt = 0; $attempt -lt 5; ++$attempt){
        try{
            $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
            try{
                $stream.Seek(0, [System.IO.SeekOrigin]::End) | Out-Null
                $stream.Write($bytes, 0, $bytes.Length)
                return
            }finally{
                $stream.Dispose()
            }
        }catch [System.IO.IOException]{
            Start-Sleep -Milliseconds 50
        }
    }

    throw "Failed to append process sample to $Path"
}

try {
    $deadline = (Get-Date).AddSeconds($DurationSeconds)
    while ((Get-Date) -lt $deadline -and -not $process.HasExited) {
        Start-Sleep -Seconds 2
        $sampleProcess = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
        if ($null -ne $sampleProcess) {
            $sample = [pscustomobject]@{
                timestamp = (Get-Date).ToString("o")
                pid = $sampleProcess.Id
                cpu_seconds = [math]::Round($sampleProcess.CPU, 3)
                working_set_mb = [math]::Round($sampleProcess.WorkingSet64 / 1MB, 3)
                private_mb = [math]::Round($sampleProcess.PrivateMemorySize64 / 1MB, 3)
                threads = $sampleProcess.Threads.Count
                handles = $sampleProcess.HandleCount
            }
            $processSamples.Add($sample) | Out-Null
            Add-SharedAsciiLine $processSamplesPath "$($sample.timestamp),$($sample.pid),$($sample.cpu_seconds),$($sample.working_set_mb),$($sample.private_mb),$($sample.threads),$($sample.handles)"
        }
        $serverLog = Join-Path $dataDir "server.log"
        if (-not $ready -and (Test-Path -LiteralPath $serverLog)) {
            $tail = Get-Content -LiteralPath $serverLog -Tail 60 -ErrorAction SilentlyContinue
            if (($tail -join "`n") -match "Done|Server started|Minecraft network interface|0\.0\.0\.0:$Port") {
                $ready = $true
                $readyAt = Get-Date
            }
        }
        if ($ready -and $RunRakPingBurst -and -not $rakPingDone) {
            & $php (Join-Path $PSScriptRoot "rak-ping-burst.php") --host=127.0.0.1 --port=$Port --count=$RakPingCount --timeout-ms=$RakPingTimeoutMs --batch-size=$RakPingBatchSize --batch-delay-us=$RakPingBatchDelayUs | Set-Content -LiteralPath $rakPingPath -Encoding UTF8
            $rakPingDone = $true
        }
    }
} finally {
    if (-not $process.HasExited) {
        $process.CloseMainWindow() | Out-Null
        Start-Sleep -Seconds 3
    }
    if (-not $process.HasExited) {
        $process.Kill()
    }
    $process.WaitForExit()
}

$end = Get-Date
$serverLogPath = Join-Path $dataDir "server.log"
$serverLog = if (Test-Path -LiteralPath $serverLogPath) { Get-Content -LiteralPath $serverLogPath -Raw } else { "" }

$fatalPattern = "Fatal error|CRITICAL|Uncaught|segmentation fault|segfault|Worker .* crashed"
$processSummary = [ordered]@{
    sample_count = $processSamples.Count
    max_working_set_mb = if ($processSamples.Count -gt 0) { ($processSamples | Measure-Object -Property working_set_mb -Maximum).Maximum } else { $null }
    max_private_mb = if ($processSamples.Count -gt 0) { ($processSamples | Measure-Object -Property private_mb -Maximum).Maximum } else { $null }
    max_threads = if ($processSamples.Count -gt 0) { ($processSamples | Measure-Object -Property threads -Maximum).Maximum } else { $null }
    max_handles = if ($processSamples.Count -gt 0) { ($processSamples | Measure-Object -Property handles -Maximum).Maximum } else { $null }
    csv = $processSamplesPath
}
$rakPingSummary = if (Test-Path -LiteralPath $rakPingPath) { Get-Content -LiteralPath $rakPingPath -Raw | ConvertFrom-Json } else { $null }
$summary = [ordered]@{
    run_name = $stamp
    run_root = $runRoot
    port = $Port
    duration_seconds = $DurationSeconds
    started_at = $start.ToString("o")
    ended_at = $end.ToString("o")
    ready = $ready
    ready_seconds = if ($readyAt -ne $null) { [math]::Round(($readyAt - $start).TotalSeconds, 3) } else { $null }
    exit_code = $process.ExitCode
    fatal_log_matches = ([regex]::Matches($serverLog, $fatalPattern, "IgnoreCase")).Count
    process = $processSummary
    rak_ping = $rakPingSummary
}

$summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Output $runRoot
