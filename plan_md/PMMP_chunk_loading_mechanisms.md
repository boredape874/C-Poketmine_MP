# PMMP Chunk Loading Mechanisms

## Current implemented mechanism

### Loaded-chunk packet prewarm

Status: implemented.

Files:

- `main_pmmp/src/network/mcpe/cache/ChunkCache.php`
- `main_pmmp/src/network/mcpe/NetworkSession.php`
- `main_pmmp/src/player/Player.php`

Behavior:

- `ChunkCache::prefetchIfLoaded()` starts async packet preparation only when the chunk is already loaded and not already cached.
- `NetworkSession::prefetchChunk()` exposes this without leaking compressor/cache details into `Player`.
- `Player::orderChunks()` prewarms a small near-future load queue after chunk ordering.
- The prewarm budget is capped by `Player::CHUNK_PREFETCH_PER_ORDER` and `chunksPerTick * 2`.
- It does not force new generation or loading, so it avoids expanding sync chunk pressure.
- The prewarm pass uses the player's most recent horizontal movement vector to
  prioritize chunks in front of the player before chunks behind the player.
- A second pass still considers the remaining queued chunks, so standing still
  or turning does not permanently starve rear/side chunks.

Expected benefit:

- Players approaching chunks already loaded by another player or by spawn/world activity can receive prepared compressed chunk packets earlier.
- Overlapping player movement should convert some future chunk sends from async wait to cache hit or already-running promise attach.

Latest verification:

- Gate: `20260608-031339`
- Ready: `2.072s`
- Fatal logs: `0`
- PHPStan: `0`
- Rak ping: `64/64`, loss `0%`, average latency `26.69ms`
- Packet batch native encode loaded: `true`
- Packet batch native decode loaded: `true`
- Packet decoding native-string path: `868,538 packets/sec`
- Full chunk serialization: `64,402 chunks/sec`
- Direction-biased prefetch priority: `780,218 selections/sec`
- Population prefetch selector: `12,461,253 candidates/sec`
- Population prefetch synthetic active skips: `650,000`
- Population prefetch synthetic stale completions: `99,992`
- Chunk population coalescing fixture: `23,889,693 requests/sec`, shared hits
  `15,360,000` out of `16,000,000` synthetic requests.
- Per-player chunk pressure snapshot: `142,790,847 snapshots/sec`
- Global chunk budget decision fixture: `19,492,987 decisions/sec`
- Runtime chunk budget pressure: reports `1`, scale min/max `100/100`,
  pending total `0`, async backlog total `0`, population prefetch started `0`,
  population prefetch resolved `0`, stale `0`, active `0`.
- Direction-bias synthetic fixture: baseline front-selected `8,000`, biased
  front-selected `16,000`, biased total-selected `16,000`.
- Runtime chunk-cache probe: reports `1`, ok `1`, failed `0`, targets `4`,
  prefetch started `4`, promise requests `4`, packet requests `4`, prefetch
  promise hits `4`, prefetch packet hits `4`, cache hits `8`, misses `0`.
- Runtime chunk population stats: reports `1`, requests `850`, shared hits `4`,
  queued `622`, started/resolved `224/224`, rejected `0`, active/pending `0/0`.

## Current implemented instrumentation

Status: implemented.

Counters:

- `hits`
- `misses`
- `cached_entries`
- `prefetch_attempts`
- `prefetch_started`
- `prefetch_skipped_cached`
- `prefetch_skipped_unloaded`
- `prefetch_promise_hits`
- `prefetch_packet_hits`

Export path:

- `ChunkCache` emits `PMMP_CHUNK_CACHE_STATS` JSON on world unload.
- `run-source-baseline.ps1 -RunChunkCacheProbe` injects a temporary
  `ChunkCacheProbe` script plugin into the baseline plugin directory.
- `ChunkCacheProbe` runs inside the actual PMMP server, population-prepares four
  spawn-near chunks, calls `prefetchIfLoaded()`, requests the same chunks while
  compression is pending, then requests them again after compression resolves.
- `tools/analyze-baseline-log.ps1` parses and aggregates these records.
- `tools/run-fast-gates.ps1` exports them into `gate-summary.json`.
- `tools/write-gate-summary-markdown.ps1` prints them in the `Chunk Cache` section.

### Per-player chunk pressure counters

Status: implemented.

Files:

- `main_pmmp/src/player/Player.php`
- `main_pmmp/tools/bench-hotpaths.php`
- `main_pmmp/tools/run-fast-gates.ps1`
- `main_pmmp/tools/write-gate-summary-markdown.ps1`

Behavior:

- `Player` now keeps O(1) counters for used chunk states instead of requiring
  scans over the whole used-chunk map.
- `Player::getChunkRequestPressure()` returns queued, needed,
  requested-generation, active-generation, requested-sending, sent, pending,
  used-total, current chunks-per-tick, base chunks-per-tick, and max
  chunks-per-tick values.
- This is the foundation for adaptive chunk send/generation budgets: the server
  can inspect pressure cheaply every tick and adjust chunk throughput without
  adding per-player map scans.
- Fast gates export `chunk_pressure_snapshots_per_second` and
  `chunk_pressure_pending_accumulator`.

### Pressure-aware adaptive chunks-per-tick

Status: implemented.

Files:

- `main_pmmp/src/player/Player.php`

Behavior:

- Each player keeps a configured base chunk-send budget and a capped adaptive
  max budget.
- The budget rises gradually when the player's load queue is behind and active
  generation plus pending send pressure are low.
- The budget falls back toward the configured base when active generation or
  pending send pressure builds.
- This gives roaming players faster visible chunk progress when the server is
  idle without permanently raising chunk pressure for all players.

### Global adaptive chunk budget coordinator

Status: implemented.

Files:

- `main_pmmp/src/Server.php`
- `main_pmmp/src/scheduler/AsyncPool.php`
- `main_pmmp/src/player/Player.php`
- `main_pmmp/tools/bench-hotpaths.php`

Behavior:

- `AsyncPool::getTotalTaskQueueSize()` exposes async worker backlog without
  allocating the per-worker queue-size array.
- `Server::getChunkSendBudgetScale()` calculates a 1-tick cached global scale
  from online player chunk pressure, requested sending pressure, async backlog,
  and average tick use.
- `Server::getChunkSendBudgetPressure()` exposes the latest scale, total
  pending chunks, and async backlog for runtime telemetry.
- The scale backs players down to 75% or 50% under load and allows burst scale
  only when tick use is low, async backlog is empty, and pending chunk demand is
  high.
- `Player::updateAdaptiveChunksPerTick()` consumes that global scale before
  applying its per-player queue rules, so many players cannot independently
  raise chunk pressure during overload.

### Pressure-aware population prefetch lane

Status: implemented.

Files:

- `main_pmmp/src/player/Player.php`
- `main_pmmp/src/Server.php`
- `main_pmmp/tools/bench-hotpaths.php`
- `main_pmmp/tools/analyze-baseline-log.ps1`
- `main_pmmp/tools/run-fast-gates.ps1`
- `main_pmmp/tools/write-gate-summary-markdown.ps1`

Behavior:

- `Player::orderChunks()` now starts a tiny speculative population lane after
  loaded-chunk packet prewarm.
- The lane only targets chunks just ahead of recent horizontal player movement.
- It skips chunks already used or already queued for normal send work.
- It respects `Server::getChunkSendBudgetScale()` and refuses speculative work
  when global chunk pressure has already backed off below `100`.
- Started/resolved population prefetch counters are folded into runtime chunk
  budget pressure telemetry.
- Active speculative population requests are tracked by chunk hash so repeated
  order runs do not submit duplicate population requests for the same chunk.
- Recent horizontal movement direction changes advance a speculative generation
  counter. Completion callbacks from older generations or older worlds are
  counted as stale and ignored.
- The synthetic selector fixture currently measures about `12.5M` candidate
  decisions/sec on the latest gate while also reporting active-skip and
  stale-completion counts.

### Shared chunk population demand coalescing

Status: implemented/instrumented.

Files:

- `main_pmmp/src/world/World.php`
- `main_pmmp/tools/run-source-baseline.ps1`
- `main_pmmp/tools/analyze-baseline-log.ps1`
- `main_pmmp/tools/run-fast-gates.ps1`
- `main_pmmp/tools/write-gate-summary-markdown.ps1`
- `main_pmmp/tools/bench-hotpaths.php`

Behavior:

- Existing world-level chunk population promise sharing is now visible through
  `World::getChunkPopulationStats()`.
- The stats report total requests, shared hits, queued requests, queue
  duplicates, tasks started/resolved/rejected, active tasks, pending promises,
  and unique queued hashes.
- The fast gate `ChunkCacheProbe` logs `PMMP_CHUNK_POPULATION_STATS` from inside
  the running PMMP server before shutdown, avoiding reliance on unload logging.
- The synthetic 400-player coalescing fixture models many players requesting
  neighbouring chunks and reports unique requests vs shared hits.

## Next mechanism candidates

### 1. Prefetch instrumentation

Implemented. Automated fast gates now produce non-zero runtime probe counters
without requiring a full Bedrock login client.

### 2. Direction-aware chunk prefetch

Implemented for loaded-chunk packet prewarm. The actual visible chunk send order
still follows the existing queue semantics, but already-loaded chunks in front
of a moving player are compressed earlier than rear chunks.

Constraints:

- Keep vanilla-compatible view semantics.
- Do not starve near-radius chunks.
- Must be reversible when movement stops or direction changes.

### 3. Pressure-aware population prefetch budget

Implemented as a conservative first lane with duplicate active-request skipping
and stale generation tagging. Next work is world-level caps and real-client
pressure tuning before raising the speculative candidate count.

### 4. Shared chunk demand coalescing

Implemented/instrumented for world population requests. Next work is using the
observed shared-hit and queue-depth counters to tune world-level population
caps under a real login/chunk-request load test.

### 5. Native receive/decode lane

Implemented for raw packet-batch splitting. `NetworkSession` now uses a string
batch callback path that calls `pmmp_perf_decode_packet_batch()` when the native
extension is loaded and falls back to the existing PHP reader callback when not.

### 6. Chunk pipeline reorder/cancel lane

Use the movement vector and pressure counters to maintain a small reorderable
frontier of chunk work. Generation, population, serialization, and compression
should be allowed to skip stale rear/side work when a player sharply turns,
teleports, or changes world, while preserving already-visible chunk semantics.

### 7. Region-level hot cache lane

Investigate a region-local hot chunk metadata cache for wild servers where many
players roam through neighbouring chunks. The goal is to avoid repeatedly
touching provider/LevelDB and palette metadata for chunks that were recently
loaded, serialized, or requested by nearby players.

## Guardrails

- No public plugin API break.
- No forced generation from packet prewarm.
- No unbounded async task submission.
- Any new prefetch budget must have metrics before being raised.
- Gate must include server boot, PHPStan, hotpath bench, and Rak ping burst.
