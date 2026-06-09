param(
    [int]$Players = 400,
    [int]$ViewDistance = 4,
    [int]$ChunksPerTick = 2,
    [int]$TickRate = 20,
    [double]$MovingPlayersRatio = 0.25
)

$ErrorActionPreference = "Stop"

$chunksPerPlayerView = (2 * $ViewDistance + 1) * (2 * $ViewDistance + 1)
$initialJoinChunks = $Players * $chunksPerPlayerView
$sendCapacityPerSecond = $Players * $ChunksPerTick * $TickRate
$fullInitialDrainSeconds = if ($sendCapacityPerSecond -gt 0) { [math]::Round($initialJoinChunks / $sendCapacityPerSecond, 3) } else { $null }
$movingPlayers = [int][math]::Ceiling($Players * $MovingPlayersRatio)
$estimatedNewChunksPerMoveStep = [math]::Max(1, 2 * $ViewDistance + 1)
$movingBurstChunks = $movingPlayers * $estimatedNewChunksPerMoveStep
$movingBurstDrainSeconds = if ($sendCapacityPerSecond -gt 0) { [math]::Round($movingBurstChunks / $sendCapacityPerSecond, 3) } else { $null }

$verdict = if ($fullInitialDrainSeconds -ne $null -and $fullInitialDrainSeconds -gt 8) { "warn" } else { "pass" }
$result = [pscustomobject]@{
    players = $Players
    view_distance = $ViewDistance
    chunks_per_tick = $ChunksPerTick
    tick_rate = $TickRate
    chunks_per_player_view = $chunksPerPlayerView
    initial_join_chunks = $initialJoinChunks
    send_capacity_chunks_per_second = $sendCapacityPerSecond
    full_initial_drain_seconds = $fullInitialDrainSeconds
    moving_players_ratio = $MovingPlayersRatio
    moving_players = $movingPlayers
    estimated_moving_burst_chunks = $movingBurstChunks
    moving_burst_drain_seconds = $movingBurstDrainSeconds
    verdict = $verdict
}

$outRoot = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")) "var/perf/chunk-budget"
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $outRoot "chunk-budget.json") -Encoding UTF8
$result | ConvertTo-Json -Depth 4
