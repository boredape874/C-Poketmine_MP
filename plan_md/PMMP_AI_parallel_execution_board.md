# PMMP AI parallel execution board

Purpose: split the high-performance PMMP work into lanes that multiple AI sessions or subagents can run independently without waiting for one another.

## Ground rules

- Work inside `main_pmmp`.
- Do not change public PMMP API unless the lane explicitly calls for a compatibility shim.
- Prefer PHP hotpath wins before native extension work.
- After touching PHP, run PHPStan on modified files.
- After a meaningful batch, run `tools/continue-fast-progress.ps1` when shell execution works.
- If Codex shell fails with `windows sandbox: spawn setup refresh`, see `plan_md/CODEX_windows_sandbox_issue_2026-06-07.md`.

## One-command validation

```powershell
cd C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\continue-fast-progress.ps1
```

This runs fast gate, hotpath bench, baseline compare, progress update, and handoff export.

## Lane A: Network packet throughput

Goal: reduce packet encoding, batching, compression, and broadcast overhead.

Primary files:

- `src/network/mcpe/StandardPacketBroadcaster.php`
- `src/network/mcpe/NetworkBroadcastUtils.php`
- `src/network/mcpe/NetworkSession.php`
- `src/Server.php`
- `vendor/pocketmine/bedrock-protocol/src/serializer/PacketBatch.php`
- `tools/bench-hotpaths.php`

Current implemented areas:

- raw batch length reuse
- single packet raw batch helper
- network session send-buffer length reuse
- compression threshold/batch length reuse

Next targets:

1. Add packet encode/decode fixture cases for common gameplay packets.
2. Audit repeated `encode()` calls in entity/player broadcast paths.
3. Add bench counters for shared broadcast batches vs per-session direct sends.
4. Consider packet payload object pooling only if it does not alter public API.

Deliverables:

- PHP patch
- bench fixture update when useful
- PHPStan target update in `tools/run-fast-gates.ps1`
- short note in `plan_md/PMMP_latest_progress_2026-06-07.md`

## Lane B: World, chunks, and entity density

Goal: make wild survival with many players/entities cheaper per tick.

Primary files:

- `src/world/World.php`
- `src/world/Explosion.php`
- `src/player/Player.php`
- `src/player/ChunkSelector.php`
- `src/entity/*`
- `src/network/mcpe/serializer/ChunkSerializer.php`

Current implemented areas:

- no-array nearby/colliding entity iteration helpers
- block update packet creation improvements
- tile lookup avoidance
- chunk serialization biome map reuse
- chunk save entity/tile NBT direct loops
- scalar movement/distance checks

Next targets:

1. Audit remaining `array_map`, `array_filter`, `array_merge`, and `array_values` in hot tick/save paths.
2. Add dedicated bench fixtures for nearby entity iteration and chunk save NBT list building.
3. Audit `getChunkEntities()` callers and replace with direct bucket iteration only when result arrays are not part of API semantics.
4. Review chunk unload/save paths for repeated listener/entity lookups.

Deliverables:

- PHP patch
- targeted PHPStan
- fast gate when shell works

## Lane C: Player interaction and inventory

Goal: reduce overhead from 400 players mining, moving, fighting, picking up items, and using inventories.

Primary files:

- `src/player/Player.php`
- `src/player/SurvivalBlockBreakHandler.php`
- `src/inventory/SimpleInventory.php`
- `src/entity/object/ItemEntity.php`
- `src/entity/Human.php`

Current implemented areas:

- movement clone avoidance
- scalar movement deltas
- `SimpleInventory::addItem()` direct slot path
- item pickup inventory reference caching
- human drops direct loops
- survival block break scalar distance check

Next targets:

1. Audit attack/use item flows for repeated `getItemInHand()` and `getWorld()` calls.
2. Add hotpath bench for player break/update and item pickup simulation.
3. Review armor/offhand/main inventory loops for avoidable cloning.
4. Keep event behavior exactly compatible.

Deliverables:

- PHP patch
- PHPStan target update
- progress note

## Lane D: Translation and serialization caches

Goal: cache expensive mapping/translation work safely.

Primary files:

- `src/network/mcpe/convert/ItemTranslator.php`
- `src/network/mcpe/convert/BlockTranslator.php`
- `src/network/mcpe/serializer/ChunkSerializer.php`
- `src/world/format/*`

Current implemented areas:

- item network ID cache keyed by item state ID
- block network state data cache
- subchunk dictionary lazy path
- biome legacy-to-string map reuse

Next targets:

1. Look for other pure mapping functions called in packet/chunk hotpaths.
2. Add cache invalidation only if mapping can change after bootstrap.
3. Add microbench fixtures for each new cache.
4. Avoid caching mutable object instances unless they are immutable by contract.

Deliverables:

- PHP patch
- bench fixture
- PHPStan target update

## Lane E: Tooling, gates, and evidence

Goal: make progress measurable and easy to resume.

Primary files:

- `tools/run-fast-gates.ps1`
- `tools/continue-fast-progress.ps1`
- `tools/update-latest-progress.ps1`
- `tools/write-gate-summary-markdown.ps1`
- `tools/hotpath-thresholds.json`
- `tools/export-ai-handoff.ps1`
- `tools/bench-hotpaths.php`
- `plan_md/PMMP_latest_progress_2026-06-07.md`

Current implemented areas:

- fast gate profile for 400-player wild-server assumptions
- runtime manifest collection
- hotpath bench export
- baseline compare
- AI handoff export
- Codex shell diagnostics

Next targets:

1. Add pass/warn/fail thresholds for each hotpath bench counter.
2. Store compare output under each gate directory.
3. Add a compact markdown summary generated from gate summary.
4. Make tool scripts robust to missing previous baselines.

Deliverables:

- PowerShell patch
- progress note
- generated files only when shell works

## Lane F: Native extension lane

Goal: optional C/C++ acceleration without forcing API breakage.

Primary files:

- `native/pmmp_perf_ext/*`
- `tools/check-native-extension-env.ps1`
- `plan_md/PMMP_native_extension_lane.md`

Current status:

- PoC source exists.
- Current shell previously reported PHP `8.2.30 zts Windows`.
- Missing build tools in shell: `cl.exe`, `nmake.exe`, `phpize`.

Next targets:

1. Install or expose matching Visual Studio Build Tools and PHP build toolchain.
2. Build PoC extension.
3. Wire extension behind runtime feature detection.
4. Benchmark native helper vs PHP fallback before expanding scope.

Deliverables:

- build log
- extension artifact
- PHP fallback path retained

## Lane G: Plugin and server pack audit

Goal: prevent plugins/resource behavior from undoing PMMP core gains.

Primary files:

- `plugins/` when real plugins are present
- `tools/audit-plugin-hotpaths.ps1`
- `plan_md/*`

Next targets:

1. Add real plugins into `main_pmmp/plugins`.
2. Run plugin hotpath audit.
3. Flag synchronous disk/database/network work in event handlers.
4. Flag repeated per-player loops in frequent events.
5. Produce fix list ranked by tick impact.

Deliverables:

- plugin audit markdown
- patch candidates per plugin

## Priority order for fastest progress

1. Lane E: keep evidence pipeline working.
2. Lane B: world/entity/chunk hotpaths.
3. Lane A: network broadcast and packet serialization.
4. Lane C: player interaction/inventory.
5. Lane D: translation/serialization caches.
6. Lane G: plugin audit after plugins are present.
7. Lane F: native extension only after PHP baseline is strong.

## Handoff checklist for every lane

- State files changed.
- State why behavior/API compatibility is preserved.
- Add modified PHP files to `tools/run-fast-gates.ps1` PHPStan target list.
- Update `plan_md/PMMP_latest_progress_2026-06-07.md`.
- Run `tools/continue-fast-progress.ps1` when shell works.

## Ready-to-use AI prompts

The lane prompts are in `plan_md/ai_tasks`:

- `LANE_A_network_packet_throughput.md`
- `LANE_B_world_chunk_entity_density.md`
- `LANE_C_player_inventory_interaction.md`
- `LANE_D_translation_serialization_caches.md`
- `LANE_E_tooling_gates_evidence.md`
- `LANE_F_native_extension.md`
- `LANE_G_plugin_server_pack_audit.md`

Use `plan_md/PMMP_parallel_merge_protocol.md` when combining lane outputs.
Use `plan_md/PMMP_implementation_backlog.md` for priority order inside each lane.
Use `plan_md/PMMP_lane_status_board.md` to track current lane status and merge readiness.
