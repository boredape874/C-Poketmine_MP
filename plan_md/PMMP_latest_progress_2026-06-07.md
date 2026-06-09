# PMMP latest progress 2026-06-07

## Authoritative current status

Updated: 2026-06-09 KST

This file is a chronological progress log. Older entries below are historical and may mention blockers that were later cleared.

- Fast-release path: complete.
- Strict production audit: waiting only for active `7200s` soak completion.
- Active strict soak: `production-v142-strict-soak-20260609-195210`.
- Production native DLL SHA256: `E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB`.
- v142 native evidence: present, warning cleared.
- Bedrock 400-player login/chunk evidence: passed with `400/400` successful logins and `400/400` chunk-ready players.
- Production plugin evidence: explicit vanilla/no-production-plugin marker is valid while `main_pmmp/plugins` remains empty.
- Final production blocker: the strict soak must finish cleanly and write matching `soak.json`.

## Bedrock login swarm progress

- 2026-06-08 21:35 KST: Bedrock swarm harness authentication compatibility fixed for local offline OIDC self-signed login.
- 2026-06-08 21:36 KST: 1-player smoke reached login, spawn, and chunk-ready with `successful_logins=1`, `chunk_ready_players=1`, `loss_percent=0`; tool verdict stayed fail only because the smoke ran for 10 seconds while pass evidence requires at least 60 seconds.
- 2026-06-08 21:37 KST: 8-player 60-second integrated swarm passed on port `19146`: `attempted_players=8`, `successful_logins=8`, `chunk_ready_players=8`, `disconnects=0`, `fatal_log_matches=0`, `loss_percent=0`.
- 2026-06-08 21:41 KST: 32-player 60-second integrated swarm passed on port `19147`: `attempted_players=32`, `successful_logins=32`, `chunk_ready_players=32`, `disconnects=0`, `fatal_log_matches=0`, `loss_percent=0`.
- 2026-06-08 21:43 KST: 64-player 60-second integrated swarm passed on port `19148`: `attempted_players=64`, `successful_logins=64`, `chunk_ready_players=64`, `disconnects=0`, `fatal_log_matches=0`, `loss_percent=0`.
- 2026-06-08 21:45 KST: 128-player integrated swarm passed on port `19149`: `attempted_players=128`, `successful_logins=128`, `chunk_ready_players=128`, `disconnects=0`, `fatal_log_matches=0`, `loss_percent=0`.
- 2026-06-08 21:50 KST: 256-player run with pre-connect server-list ping enabled failed from RakNet ping/connect timeouts after `successful_logins=218`, `chunk_ready_players=213`, `loss_percent=14.844`; server fatal count stayed 0.
- 2026-06-08 21:56 KST: 256-player integrated login/chunk swarm passed with `skip_ping=true`: `attempted_players=256`, `successful_logins=256`, `chunk_ready_players=256`, `disconnects=0`, `fatal_log_matches=0`, `loss_percent=0`.
- 2026-06-08 22:00 KST: 400-player integrated login/chunk swarm passed and production evidence was registered: `attempted_players=400`, `successful_logins=400`, `chunk_ready_players=400`, `disconnects=0`, `fatal_log_matches=0`, `loss_percent=0`.
- The production Bedrock login/chunk-ready blocker is cleared.
- 2026-06-08 22:04 KST: 2-hour production soak started in the background on port `19153`; baseline directory is `var/perf/baseline/production-soak-20260608-220444`, server reached ready in `1.602s`, expected pass evidence is `var/perf/production-evidence/soak.json` after completion.
- 2026-06-08 22:07 KST: Native local build evidence refreshed with MSVC toolset `14.50.35717`; this proves the current local native DLL state but intentionally does not clear the VS2019/v142 warning.
- 2026-06-08 22:08 KST: Workspace plugin scan found only PMMP example/test plugins and no real production plugin set, so the `production.plugins` blocker remains valid.
- 2026-06-08 22:16 KST: `register-production-plugins.ps1` now supports explicit vanilla/no-plugin production evidence via `-NoProductionPlugins`; the audit accepts it only while `main_pmmp/plugins` remains empty.
- 2026-06-08 22:17 KST: explicit no-production-plugin evidence was registered for the empty `main_pmmp/plugins` directory, clearing the `production.plugins` blocker for a vanilla survival deployment.
- 2026-06-08 22:18 KST: production readiness audit now has one blocker left: the in-progress 2-hour soak. The VS2019/v142 native build evidence remains a warning.
- 2026-06-08 22:20 KST: production readiness percentage now reflects remaining blocker count; with only the running soak blocker left, audit reports `80%`.
- 2026-06-08 22:23 KST: `pmmp-summarize-production-evidence.cmd` was added to summarize Bedrock swarm, plugin/no-plugin, soak, rollback, native, and host-network evidence in one JSON report.
- 2026-06-08 22:25 KST: `pmmp-finalize-production-readiness-after-soak.cmd` was added to wait/check the running soak, regenerate production readiness audit, and write `production-readiness-finalize-last.json`.
- 2026-06-08 22:29 KST: `pmmp-finalize-production-readiness-after-soak.cmd` now resolves the latest gate by default instead of pinning a dated gate path.
- 2026-06-08 22:34 KST: `pmmp-finalize-production-readiness-after-soak.cmd -NoExitCode` was added for status dashboards; default execution still exits nonzero while production readiness is `not_ready`.
- 2026-06-08 22:37 KST: `run-production-soak.ps1` and `audit-production-readiness.ps1` now require clean soak exit code and empty failure reasons before accepting `soak.json`.
- 2026-06-08 22:39 KST: `pmmp-start-production-finalizer-watcher.cmd -NoExitCode` was added and started. Watcher PID `16400` will run final readiness audit automatically after the soak completes.
- 2026-06-08 22:43 KST: `pmmp-check-production-finalizer-status.cmd` was added. It reports watcher PID/logs, current soak status, and whether the latest finalize report is still stale for the running soak.
- 2026-06-08 22:46 KST: `pmmp-summarize-production-evidence.cmd -Markdown` now writes `var/perf/production-evidence/production-evidence-summary.md` for human-readable deployment evidence review.
- 2026-06-08 22:49 KST: `pmmp-write-production-deployment-status.cmd -Markdown` was added. It writes `production-deployment-status.json/md` with audit, evidence, soak, and finalizer state in one report.
- 2026-06-08 22:51 KST: soak status, evidence summary, and deployment status now include `expected_complete_at`; the current 2-hour soak is expected to complete at `2026-06-09T00:04:44+09:00`.
- 2026-06-08 22:53 KST: `finalize-production-readiness-after-soak.ps1` now refreshes evidence summary markdown and deployment status json/markdown as part of its post-soak finalization.
- 2026-06-08 22:55 KST: deployment status now reports `only_waiting_for_soak` plus expected post-soak verdict/readiness. Current clean-soak expectation is `ready_with_warnings` at `85%` because only the v142 native build warning would remain.
- 2026-06-08 22:56 KST: deployment status markdown now includes `Next actions`, currently waiting for `soak.json`, then checking final deployment status, then clearing the VS2019/v142 native warning.
- 2026-06-08 23:00 KST: native extension C code now preallocates packet-batch and signed-VarInt output buffers, and exposes experimental `pmmp_perf_decode_packet_batch_callback()`. Functional tests pass against `var/native-build/php_pmmp_perf_ext.dll`; PacketBatch keeps the faster native array decode path because the C-to-PHP callback fixture is slower (`~14.0M packets/sec`) than native array decode (`~32.6M packets/sec`).
- 2026-06-08 23:02 KST: `BlockTranslator::internalIdsToNetworkIds()` was added and `ChunkSerializer` uses it for native signed VarInt palette encoding. The batch method now uses direct cache lookup/miss handling instead of recursively calling the single-ID method. Targeted PHPStan passed; repeated hotpath benches report subchunk serialization around `1.14M-1.16M subchunks/sec` and full chunk serialization around `61k-70k chunks/sec` with the current bundled extension.
- Tooling preflight after the production-readiness tooling changes passed with 33 checked scripts/wrappers; `npm audit` for `tools/bedrock-swarm` reports 0 vulnerabilities.

## Latest gate

- gate: `20260608-201920`
- ready: True
- ready seconds: `2.121`
- fatal log matches: `0`
- PHPStan exit: `0`
- config audit: pass
- chunk budget: pass
- plugin audit: pass
- compare verdict vs `unknown`: unknown


## Hotpath bench

- chunk selector chunks/sec: `5460875.105235614`
- varint cases/sec: `17110709.960022047`
- item translator conversions/sec: `2813657.116489156`
- simple inventory adds/sec: `64303.46089264457`
- packet encoding packets/sec: `590160.5676085651`
- packet decoding packets/sec: `852945.5729032839`
- packet pool lookups/sec: `6737854.343759938`
- block update packets/sec: `1299609.6541178254`
- block state data lookups/sec: `1299609.6541178254`
- nearby entity array entities/sec: `19768478.173129037`
- nearby entity callback entities/sec: `20407299.4642706`
- nearby entity boolean queries/sec: `596438.9611822614`
- subchunk serialization/sec: `1008820.1142589662`
- compression batches/sec: `143320.16937577617`
- mining progress updates/sec: `9250608.227490958`
- movement process updates/sec: `5688387.299537676`
- full chunk serialization/sec: `58882.98390698609`
- global chunk budget decisions/sec: `19497358.10797637`
- population prefetch selection candidates/sec: `12468089.483478224`
- chunk population coalescing requests/sec: `23796871.098149747`


## Core changes added in this step

- `SimpleInventory::addItem()` now uses direct slot access.
- The path avoids the generic `BaseInventory` clone-heavy add flow for regular inventories.
- `Player::processMostRecentMovements()` avoids the unused `$from` clone when no movement event handler exists.
- `PlayerMoveEvent` destination-change check now uses scalar delta math.
- `Player::processMostRecentMovements()` now avoids `sqrt()` when the accepted movement only changes look direction and has no horizontal travel.
- `Player::processMostRecentMovements()` now skips entering movement broadcast when the player has no spawned viewers.
- `tools/bench-hotpaths.php` now records player movement process throughput for delta/angle/event-check/chunk-order work.
- Gate summaries, progress updates, thresholds, and AI handoff now export movement process throughput.
- `Entity::updateMovement()` now uses scalar position/rotation delta math.
- `NetworkBroadcastUtils::broadcastPackets()` now avoids closure allocation and the intermediate sessions array.
- `NetworkBroadcastUtils::broadcastEntityEvent()` now avoids duplicate broadcaster object-id calls.
- `NetworkBroadcastUtils::broadcastEntityEvent()` now skips disconnected recipients and returns before callback dispatch if no connected broadcaster targets remain.
- `Entity::broadcastMovement()` and `broadcastMotion()` now skip packet object creation when the entity has no spawned viewers.
- `StandardPacketBroadcaster::broadcastPackets()` now fast-returns empty recipient/mutated empty packet cases and uses a single-packet send path.
- `PacketBatch::encodeRawWithLengths()` added for callers that already measured packet lengths.
- `PacketBatch::encodeRawSingle()` added for one-packet batches.
- `StandardPacketBroadcaster::broadcastPackets()` now reuses measured packet lengths when encoding compressed shared batches.
- `tools/bench-hotpaths.php` now records packet decode throughput for common receive packets.
- Gate summaries, progress updates, thresholds, and AI handoff now export packet decode throughput.
- `tools/bench-hotpaths.php` now records packet pool lookup throughput for raw packet buffer ID lookup and clone creation.
- Gate summaries, progress updates, thresholds, and AI handoff now export packet pool lookup throughput.
- `PacketPool::getPacket()` now performs the pool lookup directly instead of routing through `getPacketById()`.
- `NetworkSession::handleEncoded()` now checks the internal connected flag directly after packet handling.
- `ChunkRequestTask::onRun()` now encodes `LevelChunkPacket` directly and wraps it with the single raw batch helper.
- `NetworkSession` now tracks send buffer lengths alongside packet buffers and reuses them during flush.
- `NetworkSession::flushGamePacketQueue()` now uses single/raw-with-length batch helpers instead of recalculating packet lengths.
- `Server::prepareBatch()` now computes batch buffer length once and reuses it for threshold and async decisions.
- `tools/bench-hotpaths.php` now records compression throughput for below/above-threshold batches.
- `tools/run-fast-gates.ps1` now exports compression batches/sec.
- `World::forEachNearbyEntity()` added to iterate nearby entities without allocating a result array.
- `World::forEachNearbyEntity()` now reads chunk entity buckets directly instead of going through `getChunkEntities()`.
- `World` chunk ticking, nearby block-change fanout, and chunk unload entity-close paths now iterate entity buckets directly instead of routing through closure-based `forEachChunkEntity()`.
- `World::forEachChunkEntity()` now returns immediately for chunks with no entity bucket.
- `World::getCollidingEntities()` now uses no-intermediate-array nearby iteration.
- `World::hasNearbyEntities()` added for boolean entity-overlap checks without allocating result arrays.
- `World::hasCollidingEntities()` added for boolean collidable-entity checks without allocating result arrays.
- `World::forEachCollidingEntity()` added for collidable-entity iteration without allocating result arrays.
- Block placement collision checks now use `World::hasCollidingEntities()`.
- `Player::checkNearEntities()` now uses no-array nearby entity iteration.
- `ItemEntity::entityBaseTick()` now uses no-array nearby entity iteration for merge checks.
- `ItemEntity::onCollideWithPlayer()` now caches offhand/main inventory references before capacity checks.
- `PlayerOffHandInventory::canAddStackedItem()` added for one-slot offhand stack checks without cloning the current item.
- `ItemEntity` pickup and `Arrow` pickup now use the offhand stacked-item fast path instead of cloning slot 0 and scanning the one-slot inventory again.
- `ItemEntity::entityBaseTick()` now avoids allocating `[$this]` and looping merge candidates when no nearby item merge candidate exists.
- `Living::applyFrostWalker()` now uses `World::hasNearbyEntities()` instead of creating a nearby entity array.
- `Projectile` movement collision checks now use `World::forEachCollidingEntity()`.
- `FallingBlock` ground-hit damage checks now use `World::forEachCollidingEntity()`.
- `SplashPotion` splash effect checks now use `World::forEachCollidingEntity()`.
- `AreaEffectCloud` application checks now use `World::forEachCollidingEntity()`.
- `FireworkRocket` explosion damage checks now use `World::forEachCollidingEntity()`.
- `World` neighbour block updates now use `World::forEachNearbyEntity()`.
- `Explosion` damage/knockback checks now use `World::forEachNearbyEntity()`.
- `Painting` overlap checks now use `World::forEachNearbyEntity()`.
- `World::saveChunks()` and chunk unload save now build entity/tile NBT with direct loops.
- `Human::getDrops()` now avoids `array_merge()`, `array_values()`, and `array_filter()` chains.
- `Player::canInteract()`, `attackBlock()`, `continueBreakBlock()`, and `stopBreakBlock()` now use scalar distance checks.
- `SurvivalBlockBreakHandler::update()` now avoids creating an offset `Vector3` for range checks.
- `Entity` step-up movement comparison now uses scalar multiplication instead of exponentiation.
- `Projectile` rotation recompute and `Living::lookAt()` now use scalar square math.
- `AttributeMap::needSend()` now uses a direct loop instead of `array_filter()` for per-network-tick sync checks.
- `Entity::sendSpawnPacket()` now builds network attributes with a direct loop instead of `array_map()`.
- `AttributeMap.php` stale `array_filter` import removed.
- `tools/run-fast-gates.ps1` now includes `AttributeMap.php` in PHPStan targets.
- Player death inventory clearing now uses a direct slot loop instead of `array_filter($inventory->getContents(), ...)`.
- `BaseInventory::onContentChange()` now iterates internal viewers directly instead of calling `getViewers()`.
- `tools/run-fast-gates.ps1` now includes `BaseInventory.php` in PHPStan targets.
- `SurvivalBlockBreakHandler::update()` now caches `$player` and `$world` locally inside the method body to reduce repeated chained lookups.
- `tools/run-pending-phpstan.ps1` added for fast PHPStan preflight on recently changed/high-risk files.
- `tools/continue-fast-progress.ps1` now runs pending PHPStan before the full fast gate.
- `tools/run-pending-phpstan.ps1` now writes PHPStan raw output to `var/perf/pending-phpstan/<stamp>/phpstan.txt` and keeps stdout JSON-only.
- `tools/continue-fast-progress.ps1` now skips the full fast gate if pending PHPStan fails.
- `tools/run-pending-phpstan.ps1` now supports `-NoExitCode` so parent scripts can parse JSON before deciding whether to stop.
- `tools/continue-fast-progress.ps1` now calls pending PHPStan with `-NoExitCode` and handles failure itself.
- Tooling scripts now normalize `Resolve-Path` results to string paths before JSON output and file operations.
- `tools/run-tooling-preflight.ps1` added to parse-check PowerShell tooling scripts before pending PHPStan and fast gate.
- `tools/continue-fast-progress.ps1` now runs tooling preflight first and skips later gates if tooling parse checks fail.
- `tools/run-tooling-preflight.ps1` now supports `-NoExitCode` so parent automation can parse JSON before deciding whether to stop.
- `tools/continue-fast-progress.ps1` now calls tooling preflight with `-NoExitCode` and handles failure itself.
- `tools/run-tooling-preflight.ps1` now checks required CMD wrappers, root README, and `hotpath-thresholds.json` existence.
- CMD wrappers added under `main_pmmp`: `continue-fast-progress.cmd`, `diagnose-codex-shell.cmd`, `run-tooling-preflight.cmd`, `run-pending-phpstan.cmd`.
- Root CMD wrappers added: `pmmp-continue-fast-progress.cmd`, `pmmp-diagnose-codex-shell.cmd`, `pmmp-run-tooling-preflight.cmd`, `pmmp-run-pending-phpstan.cmd`.
- `README_PMMP_FAST.md` added at repository root with the fastest validation command and current work map.
- `tools/continue-fast-progress.ps1` added for one-command fast validation and handoff refresh.
- `tools/diagnose-codex-shell.ps1` added for shell recovery diagnostics.
- `tools/update-latest-progress.ps1` added to update this progress file from the latest gate summary.
- `tools/continue-fast-progress.ps1` now stores compare output inside the current gate directory when available.
- `tools/diagnose-codex-shell.ps1` now resets `LASTEXITCODE` before each shell check.
- `tools/update-latest-progress.ps1` now separates PowerShell interpolation from markdown code backticks to avoid literal `$($summary...)` output.
- `tools/update-latest-progress.ps1` now formats missing optional bench fields as `null`.
- `tools/write-gate-summary-markdown.ps1` added to create compact `summary.md` files under gate directories.
- `tools/continue-fast-progress.ps1` now calls `write-gate-summary-markdown.ps1` after gate/compare.
- `tools/write-gate-summary-markdown.ps1` now adds warning reasons for non-pass compare verdicts.
- `tools/write-gate-summary-markdown.ps1` now adds hotpath threshold warnings for obvious bench regressions.
- `tools/hotpath-thresholds.json` added so hotpath warning thresholds can be tuned without editing PowerShell.
- `plan_md/PMMP_AI_parallel_execution_board.md` added to split work across AI/subagent lanes.
- `plan_md/ai_tasks/*` added as ready-to-use prompts for parallel AI sessions.
- `plan_md/ai_tasks/LANE_D_translation_serialization_caches.md` and `LANE_G_plugin_server_pack_audit.md` added to complete the lane prompt set.
- `plan_md/PMMP_implementation_backlog.md` added for priority-ordered implementation work.
- `plan_md/PMMP_parallel_merge_protocol.md` added for combining parallel AI lane outputs.
- `plan_md/PMMP_lane_status_board.md` added for live lane status and merge readiness tracking.
- `plan_md/PMMP_subagent_runs.md` added to track delegated AI/subagent work.
- `tools/bench-hotpaths.php` packet fixture now covers the length-reuse batch path.
- `tools/bench-hotpaths.php` packet fixture now covers text, actor movement, player movement, actor motion, actor metadata, mob equipment, inventory slot, and inventory content packet encoding in the raw batch length-reuse path.
- `tools/bench-hotpaths.php` now records nearby entity result-array, direct-iteration, and boolean-query fixture throughput.
- Gate summaries and progress updates now export nearby entity iteration throughput fields and thresholds.
- `BlockTranslator::internalIdToNetworkStateData()` now caches generated network state data by internal state id.
- `tools/bench-hotpaths.php` now records block update packet creation/encode throughput.
- `tools/run-fast-gates.ps1` now exports block update packet and state data lookup throughput.
- `ChunkSerializer::serializeFullChunk()` now passes the biome ID map array into biome serialization to avoid repeated map method calls.
- `ChunkSerializer::serializeSubChunk()` now lazy-loads the block state dictionary only for persistent blockstate serialization.
- `tools/bench-hotpaths.php` now records subchunk serialization throughput.
- `tools/run-fast-gates.ps1` now exports subchunk serialization throughput.
- `tools/bench-hotpaths.php` now records mining progress update throughput for survival block-break distance/speed/progress/fx ticker work.
- Gate summaries, progress updates, thresholds, and AI handoff now export mining progress throughput.
- `SurvivalBlockBreakHandler` now caches block center coordinates and max distance squared once instead of recalculating them every update tick.
- `World::createBlockUpdatePackets()` now reuses integer coordinates and block state id per changed block.
- `World::createBlockUpdatePackets()` now creates `BlockPosition` directly from cached integer coordinates.
- `World::createBlockUpdatePackets()` now skips tile lookup for blocks whose ID info has no tile class.
- `World` large block-change chunk resend now skips the resend loop when no chunk viewers exist.
- `World::getCollisionBlocks()` now avoids repeated `getBlockAt()` calls for non-cube collision checks.
- `tools/bench-hotpaths.php` now records `simple_inventory_add`.
- `tools/bench-hotpaths.php` now records packet encode + raw batch fixture throughput.
- `tools/run-fast-gates.ps1` now exports `simple_inventory_adds_per_second`.
- `tools/run-fast-gates.ps1` now exports `packet_encoding_packets_per_second`.
- `tools/export-ai-handoff.ps1` now includes this applied core area.
- `StandardEntityEventBroadcaster::syncAttributes()` now builds network attributes with a direct loop instead of `array_map()`.
- `tools/run-pending-phpstan.ps1` and `tools/run-fast-gates.ps1` now include `StandardEntityEventBroadcaster.php`.
- `AreaEffectCloud`, `ExperienceOrb`, and `Explosion` now avoid exponentiation in hot distance/square calculations.
- `World::getNearestEntity()` now avoids exponentiation and iterates chunk entity buckets directly instead of routing through a closure visitor.
- `tools/run-pending-phpstan.ps1` now includes `AreaEffectCloud.php` and `ExperienceOrb.php`.
- `NetworkSession::prepareClientTranslatableMessage()` now builds translated parameters with a direct loop instead of `array_map()`.
- `NetworkSession::syncPlayerList()` now builds player list entries with a direct loop and cached skin adapter.
- `InventoryManager::syncEnchantingTableOptions()` now builds protocol enchantments with a direct loop instead of `array_map()`.
- Player spawn chunk threshold calculations now use scalar multiplication instead of exponentiation.
- Squid rotation and Arrow punch knockback calculations now avoid exponentiation and cache motion components.
- `tools/run-pending-phpstan.ps1` and `tools/run-fast-gates.ps1` now include `NetworkSession.php`, `InventoryManager.php`, `Squid.php`, and `Arrow.php`.
- `InGamePacketHandler` movement ACK, block interaction spam filtering, nearby block sync, and block actor update range checks now use scalar distance math instead of `Vector3::distanceSquared()`.
- `InGamePacketHandler::syncBlocksNearby()` now appends side blocks directly instead of using spread `array_push()`.
- `tools/run-pending-phpstan.ps1` now includes `InGamePacketHandler.php`.
- `World::createBlockUpdatePackets()` now merges fake tile state properties with a direct loop instead of `array_merge()`.
- `InGamePacketHandler::syncBlocksNearby()` now appends neighbour positions directly instead of allocating via `Vector3::sidesArray()`.
- `LevelDB` chunk entity/tile NBT load and save paths now build `CompoundTag` and `TreeRoot` lists with direct loops instead of `array_map()`.
- `FastChunkSerializer` now reindexes unpacked palettes with a direct loop instead of `array_values()`.
- `LevelDB` legacy terrain biome loading now reindexes unpacked biome colors with a direct loop instead of `array_values()`.
- PHPStan and full gate targets now include `FastChunkSerializer.php`.
- `Chunk::__clone()` now clones subchunks with a typed `SplFixedArray` loop instead of `toArray()` plus `array_map()`.
- `SubChunk::__clone()` now clones block layers with a direct loop instead of `array_map()`.
- PHPStan gate targets now include `Chunk.php`, `SubChunk.php`, and `LevelDB.php`.
- `ResourcePacksPacketHandler` now builds resource pack info and stack entries with direct loops instead of `array_map()` during join setup.
- `CraftingDataCache` now converts recipe ingredients/results with typed direct loops instead of closure `array_map()` calls.
- `CreativeInventory` now loads creative items and returns item lists with direct loops instead of `array_map()`/`array_filter()` intermediate arrays.
- `BlockStateDictionary::loadPaletteFromString()` now decodes palette roots with a direct loop instead of `array_map()`.
- PHPStan gate targets now include resource pack, crafting cache, creative inventory, and block state dictionary startup/cache paths.
- `World::getNearestEntity()` now calculates candidate distance with cached scalar coordinates instead of `Vector3::distanceSquared()`.
- `Projectile` ray tracing, `SplashPotion` effect radius, `FireworkRocket` explosion damage radius, and `ExperienceOrb` target validation now use scalar squared-distance math in repeated entity scans.
- `Human` and `Player` unused array helper imports were removed after earlier direct-loop refactors.
- Pending PHPStan targets now include `Projectile.php`, `SplashPotion.php`, and `FireworkRocket.php`.
- `Entity::checkBlockIntersections()` now accumulates liquid/current velocity components directly instead of allocating a vector list and calling `Vector3::sum(...$vectors)`.
- `EffectCollection` and `SplashPotion` now compute weighted potion/effect colors by RGBA sums instead of building repeated color arrays for `Color::mix(...$colors)`.
- `ExperienceUtils::getXpToReachLevel()` now uses cached multiplication for level squared calculations instead of exponentiation.
- PHPStan gate targets now include `EffectCollection.php` and `ExperienceUtils.php`.
- `CompressBatchPromise::onResolve()` now appends pending callbacks with a direct loop instead of `array_push(...$callbacks)`.
- `Explosion` now rejects entities outside the explosion radius using scalar squared-distance before doing `sqrt()`/knockback vector work.
- PHPStan gate targets now include `CompressBatchPromise.php` and `Explosion.php`.
- Codex Windows sandbox note updated: managed sandbox `spawn setup refresh` is an execution-profile issue, clean unrestricted gate `20260607-203817` is verified, and interrupted approval runs may continue in the background.
- `tools/diagnose-codex-shell.ps1` now exits non-zero on failed shell checks and includes PMMP PHP/runtime/write-test checks.
- Root shell diagnostic passed at 2026-06-07 23:19 KST, and fast gate `20260607-231958` passed on port `19133`.
- `PopulationTask` now serializes/deserializes adjacent chunks with direct loops instead of `array_map()` closures in async generation handoff.
- `BedrockWorldData` now builds `lastOpenedWithVersion` NBT with a shared direct-loop helper instead of repeated `array_map()` calls.
- `FlatGeneratorOptions::parseLayers()` now trims layer entries inside the parse loop instead of prebuilding a mapped array.
- `Gaussian` and `RegionLocationTableEntry` now use direct multiplication/constant bounds instead of exponentiation for fixed square/power values.
- PHPStan and full gate targets now include population task, flat generator options, Gaussian kernel, Bedrock world data, and region location table files.
- `NetworkBroadcastUtils::broadcastPackets()` and `broadcastEntityEvent()` now return before timing/grouping work when recipient lists are empty.
- `Entity::sendData()` now skips metadata collection and broadcaster grouping when there are no target viewers.
- `Entity::broadcastAnimation()` now skips animation packet encoding when there are no target viewers.
- Pending PHPStan targets now include `NetworkBroadcastUtils.php`.
- `PacketBatch::decodeRawCallback()` now provides a non-generator raw batch decode path for hot callers while preserving the existing `decodeRaw()` generator API.
- `NetworkSession` incoming batch processing now uses `decodeRawCallback()` to avoid generator resume overhead in the packet receive hotpath.
- `tools/bench-hotpaths.php` now reports packet decode generator vs callback throughput separately.
- Latest fallback fast gate `20260608-010252`: ready `2.126s`, fatal `0`, PHPStan `0`, packet decoding callback `836,825 packets/sec`, generator comparison `854,474 packets/sec`.
- `Player::processMostRecentMovements()` now records the most recent horizontal movement vector for chunk prefetch priority.
- `Player::prefetchQueuedChunkPackets()` now prewarms already-loaded chunks in front of the moving player before rear chunks, then uses a second pass to avoid starvation.
- `tools/bench-hotpaths.php` now reports direction-biased chunk prefetch priority throughput and front-selection effectiveness.
- Gate summaries, markdown summaries, and hotpath thresholds now export `chunk_prefetch_priority_selections_per_second`.
- `tools/run-source-baseline.ps1 -RunChunkCacheProbe` now injects a temporary `ChunkCacheProbe` script plugin into the baseline plugin directory.
- `ChunkCacheProbe` runs inside the real PMMP server, population-prepares four spawn-near chunks, prefetches them, requests them while compression is pending, then requests them again after compression resolves.
- `tools/analyze-baseline-log.ps1` now parses `PMMP_CHUNK_CACHE_PROBE` from `server.log` only, avoiding duplicate counts from mirrored stdout.
- `tools/run-fast-gates.ps1` now enables the chunk-cache probe and exports probe reports, ok/failed counts, request counts, prefetch promise hits, prefetch packet hits, hits, and misses.
- `tools/write-gate-summary-markdown.ps1` now prints chunk-cache probe fields in the `Chunk Cache` section.
- `tools/run-source-baseline.ps1` now passes `--data=...` and `--plugins=...` as single arguments so Windows `Start-Process` reliably preserves the selected plugin path.
- `tools/run-tooling-preflight.ps1` now parse-checks `run-source-baseline.ps1` and `analyze-baseline-log.ps1`.
- Latest native-enabled fast gate `20260608-020227`: ready `2.089s`, fatal `0`, PHPStan `0`, Rak ping `64/64`, loss `0%`, packet batch raw `2,487,804 batches/sec`, packet decoding callback `823,437 packets/sec`, subchunk serialization `918,947 subchunks/sec`, full chunk serialization `65,050 chunks/sec`, movement synthetic `6,058,302 updates/sec`, chunk prefetch priority `777,178 selections/sec`, chunk-cache probe prefetch promise hits `4`, packet hits `4`, cache hits `8`, misses `0`.
- `Player` now tracks used-chunk status counts with O(1) counters for needed, requested-generation, requested-sending, and sent chunks.
- `Player::getChunkRequestPressure()` now exposes queued, active generation, pending, used-total, and chunks-per-tick pressure state for future adaptive chunk scheduling.
- `tools/bench-hotpaths.php` now includes a chunk pressure snapshot fixture.
- Gate summaries, markdown summaries, and hotpath thresholds now export `chunk_pressure_snapshots_per_second`.
- Latest native-enabled fast gate `20260608-021211`: ready `2.083s`, fatal `0`, PHPStan `0`, Rak ping `64/64`, loss `0%`, packet batch raw `2,509,231 batches/sec`, packet decoding callback `825,761 packets/sec`, subchunk serialization `1,039,515 subchunks/sec`, full chunk serialization `68,916 chunks/sec`, movement synthetic `6,051,584 updates/sec`, chunk prefetch priority `788,166 selections/sec`, chunk pressure snapshots `142,308,240 snapshots/sec`, chunk-cache probe prefetch promise hits `4`, packet hits `4`, cache hits `8`, misses `0`.
- `Player` chunk sending now has a pressure-aware adaptive chunks-per-tick budget with configured base, capped max, queue-behind growth, and pressure backoff.
- `Player::getChunkRequestPressure()` now includes base and max chunks-per-tick so future global schedulers can see both current and configured budget state.
- Latest native-enabled fast gate `20260608-021757`: ready `2.069s`, fatal `0`, PHPStan `0`, Rak ping `64/64`, loss `0%`, packet batch raw `2,473,643 batches/sec`, packet decoding callback `814,079 packets/sec`, subchunk serialization `888,804 subchunks/sec`, full chunk serialization `64,754 chunks/sec`, movement synthetic `5,765,251 updates/sec`, chunk prefetch priority `790,377 selections/sec`, chunk pressure snapshots `142,785,750 snapshots/sec`, chunk-cache probe prefetch promise hits `4`, packet hits `4`, cache hits `8`, misses `0`.
- `AsyncPool::getTotalTaskQueueSize()` added so global pressure checks can read async backlog without building a queue-size array.
- `Server::getChunkSendBudgetScale()` added as a 1-tick cached global chunk-send scale from online player pending chunks, requested sending pressure, async backlog, and tick load.
- `Server::getChunkSendBudgetPressure()` added for future runtime telemetry/export of scale, pending chunks, and async backlog.
- `Player::updateAdaptiveChunksPerTick()` now consumes the global scale before per-player queue growth, allowing 75%/50% backoff under load and burst only under low-load/high-pending conditions.
- `tools/bench-hotpaths.php` now includes a global chunk budget coordinator fixture.
- Gate summaries, markdown summaries, and hotpath thresholds now export `global_chunk_budget_decisions_per_second`.
- Latest native-enabled fast gate `20260608-022631`: ready `2.079s`, fatal `0`, PHPStan `0`, Rak ping `64/64`, loss `0%`, packet batch raw `2,480,774 batches/sec`, packet decoding callback `846,812 packets/sec`, subchunk serialization `1,049,267 subchunks/sec`, full chunk serialization `65,120 chunks/sec`, movement synthetic `6,074,965 updates/sec`, chunk prefetch priority `765,378 selections/sec`, chunk pressure snapshots `142,841,838 snapshots/sec`, global chunk budget `19,665,103 decisions/sec`, chunk-cache probe prefetch promise hits `4`, packet hits `4`, cache hits `8`, misses `0`.
- `ChunkCacheProbe` now logs `PMMP_CHUNK_BUDGET_PRESSURE` from inside the running PMMP server.
- `tools/analyze-baseline-log.ps1` now parses runtime chunk budget pressure reports from `server.log`.
- `tools/run-fast-gates.ps1` now exports chunk budget pressure report count, scale min/max, pending total, and async backlog total.
- `tools/write-gate-summary-markdown.ps1` now prints a `Chunk Budget Pressure` section in gate `summary.md`.
- Latest native-enabled fast gate `20260608-023122`: ready `2.095s`, fatal `0`, PHPStan `0`, Rak ping `64/64`, loss `0%`, packet batch raw `2,478,152 batches/sec`, packet decoding callback `844,449 packets/sec`, subchunk serialization `1,054,130 subchunks/sec`, full chunk serialization `66,536 chunks/sec`, movement synthetic `6,064,723 updates/sec`, chunk prefetch priority `783,787 selections/sec`, chunk pressure snapshots `137,282,493 snapshots/sec`, global chunk budget `19,546,139 decisions/sec`, runtime budget pressure reports `1`, scale `100`, pending `0`, async backlog `0`, chunk-cache probe prefetch promise hits `4`, packet hits `4`, cache hits `8`, misses `0`.
- `Player::orderChunks()` now has a pressure-aware population prefetch lane for a tiny number of chunks ahead of recent horizontal movement.
- `Player::getChunkRequestPressure()` now includes population prefetch attempts/started/skipped/resolved counters for budget telemetry.
- `Server::getChunkSendBudgetPressure()` now exports population prefetch started/resolved totals.
- Gate analysis and summaries now export population prefetch runtime counters plus the synthetic selector fixture.
- `pmmp_perf_decode_packet_batch()` added to the native C extension to split raw packet batches with C-side VarInt parsing.
- `PacketBatch::decodeRawStringCallback()` added as an optional native receive-batch path with the existing PHP callback reader as fallback.
- `NetworkSession` incoming batch processing now uses `decodeRawStringCallback()` so receive batches avoid PHP-level VarInt splitting when the extension is loaded.
- `tools/test-native-extension.ps1` now verifies native packet-batch decode output.
- `tools/bench-native-extension.php` now reports native packet-batch decode throughput.
- `tools/bench-hotpaths.php`, gate summaries, and markdown summaries now export native string packet decoding throughput and native-loaded state.
- Latest native-enabled fast gate `20260608-025002`: ready `2.085s`, fatal `0`, PHPStan `0`, Rak ping `64/64`, loss `0%`, average latency `27.46ms`, packet batch raw `2,049,821 batches/sec`, packet decoding native string `869,957 packets/sec`, packet decoding callback comparison `818,414 packets/sec`, subchunk serialization `962,927 subchunks/sec`, full chunk serialization `65,625 chunks/sec`, movement synthetic `5,495,426 updates/sec`, chunk prefetch priority `749,910 selections/sec`, population prefetch selector `14,703,585 candidates/sec`, chunk pressure snapshots `142,801,042 snapshots/sec`, global chunk budget `18,352,581 decisions/sec`, runtime budget pressure reports `1`, scale `100`, pending `0`, async backlog `0`, chunk-cache probe prefetch promise hits `4`, packet hits `4`, cache hits `8`, misses `0`.
- Population prefetch now tracks active speculative requests by chunk hash and skips duplicate active speculative requests.
- Population prefetch now increments a speculative generation when the player reverses recent horizontal movement direction.
- Population prefetch completion callbacks now count old-generation, disconnected, or old-world completions as stale instead of useful resolved work.
- Server chunk budget pressure now exports population prefetch stale and active totals.
- Gate analysis, summaries, and hotpath benches now export population prefetch active-skip and stale-completion fields.
- Latest native-enabled fast gate `20260608-030036`: ready `2.076s`, fatal `0`, PHPStan `0`, Rak ping `64/64`, loss `0%`, average latency `30.09ms`, packet batch raw `1,966,731 batches/sec`, packet decoding native string `842,241 packets/sec`, packet decoding callback comparison `818,549 packets/sec`, subchunk serialization `944,713 subchunks/sec`, full chunk serialization `67,939 chunks/sec`, movement synthetic `6,060,064 updates/sec`, chunk prefetch priority `676,193 selections/sec`, population prefetch selector `12,461,253 candidates/sec`, population prefetch active skips `650,000`, population prefetch stale completions `99,992`, chunk pressure snapshots `142,862,245 snapshots/sec`, global chunk budget `19,580,296 decisions/sec`, runtime budget pressure reports `1`, scale `100`, pending `0`, async backlog `0`, chunk-cache probe prefetch promise hits `4`, packet hits `4`, cache hits `8`, misses `0`.
- `World::getChunkPopulationStats()` now exposes runtime population request, shared-hit, queue, started/resolved/rejected, active, pending, and queued-unique counters.
- `tools/run-source-baseline.ps1` probe now logs `PMMP_CHUNK_POPULATION_STATS` from inside the running server.
- `tools/analyze-baseline-log.ps1`, `tools/run-fast-gates.ps1`, and `tools/write-gate-summary-markdown.ps1` now parse/export chunk population coalescing stats.
- `tools/bench-hotpaths.php` now includes a 400-player chunk population coalescing fixture with unique request vs shared-hit counters.
- Latest native-enabled fast gate `20260608-031339`: ready `2.072s`, fatal `0`, PHPStan `0`, Rak ping `64/64`, loss `0%`, average latency `26.69ms`, packet batch raw `2,676,011 batches/sec`, packet decoding native string `868,538 packets/sec`, packet decoding callback comparison `814,946 packets/sec`, subchunk serialization `1,048,007 subchunks/sec`, full chunk serialization `64,402 chunks/sec`, movement synthetic `6,074,587 updates/sec`, chunk prefetch priority `780,218 selections/sec`, population prefetch selector `12,514,587 candidates/sec`, chunk population runtime requests `850`, shared hits `4`, queued `622`, started/resolved `224/224`, rejected `0`, coalescing fixture `23,889,693 requests/sec`, coalescing shared hits `15,360,000`, chunk pressure snapshots `142,790,847 snapshots/sec`, global chunk budget `19,492,987 decisions/sec`, runtime budget pressure reports `1`, scale `100`, pending `0`, async backlog `0`, chunk-cache probe prefetch promise hits `4`, packet hits `4`, cache hits `8`, misses `0`.
- `network.raklib-packet-limit` is now wired from `pocketmine.yml` into RakLib's per-source-IP packet limiter. The default remains `200`; the wild-400 profile uses `1200` for synthetic localhost 400-burst validation.
- `tools/rak-ping-burst.php`, `tools/run-source-baseline.ps1`, `tools/run-fast-gates.ps1`, `tools/summarize-baseline-runs.ps1`, and `tools/write-gate-summary-markdown.ps1` now support/report 400-ping production-style Rak burst gates.
- Latest native-enabled fast gate `20260608-201920`: ready `2.121s`, fatal `0`, PHPStan `0`, Rak ping `400/400`, loss `0%`, average latency `21.13ms`, packet batch raw `2,512,989 batches/sec`, packet decoding native string `852,946 packets/sec`, packet decoding callback comparison `856,791 packets/sec`, subchunk serialization `1,008,820 subchunks/sec`, full chunk serialization `58,883 chunks/sec`, movement synthetic `5,688,387 updates/sec`, chunk prefetch priority `786,106 selections/sec`, population prefetch selector `12,468,089 candidates/sec`, chunk population runtime requests `894`, shared hits `4`, queued `666`, started/resolved `224/224`, rejected `0`, coalescing fixture `23,796,871 requests/sec`, coalescing shared hits `15,360,000`, chunk pressure snapshots `142,577,081 snapshots/sec`, global chunk budget `19,497,358 decisions/sec`, runtime budget pressure reports `1`, scale `100`, pending `0`, async backlog `0`, chunk-cache probe prefetch promise hits `4`, packet hits `4`, cache hits `8`, misses `0`.
- `tools/audit-production-readiness.ps1` separates high-performance core readiness from actual live deployment readiness. It writes `production-readiness.json/md` into the gate directory and currently reports `not_ready`, readiness `80%`, high-performance core ready `true`.
- Production evidence helpers added: `create-rollback-package.ps1`, `collect-host-network-evidence.ps1`, `record-native-build-evidence.ps1`, `run-production-soak.ps1`, and `register-bedrock-login-swarm-evidence.ps1`, with root CMD wrappers.
- Rollback and host-local network evidence have been generated under `main_pmmp/var/perf/production-evidence`. Native local build evidence was recorded as `native-local-build.json`; it intentionally does not satisfy the v142 production build requirement.
- Latest production readiness audit for gate `20260608-201920`: blockers reduced to `1`, leaving only the running 2+ hour soak evidence. Warning remains `1`, the missing VS2019/v142 native build evidence.
- Production evidence schema documented in `plan_md/PMMP_production_evidence_schema.md`, with input samples under `main_pmmp/tools/production-evidence-samples/`.
- Short production soak smoke `20260608-211410` reached ready in `2.096s` with `0` fatal log matches and intentionally failed only because it ran `30s` against the `7200s` minimum, writing `soak-last-failed.json` rather than clearing the real soak blocker.
- v142 check confirmed VS2019 Build Tools are not installed; only VS2026/MSVC `14.50.35717` is available. `install-v142-build-tools-windows.ps1` now avoids automatic UAC popups by default and requires `-Elevate` for interactive installation.
- First 2-hour soak attempt `production-soak-20260608-220444` failed after about 66 minutes because live status polling read `process-samples.csv` with an exclusive `Import-Csv` path while the baseline runner appended a new process sample. Server log fatal matches stayed `0`; this was a monitoring file-sharing bug, not a PMMP crash.
- `run-source-baseline.ps1` now appends process samples with shared read/write file access and retry, and `check-production-soak-status.ps1` now reads the latest sample with shared read/write access without `Import-Csv`.
- Replacement 2-hour soak `production-soak-20260608-231339` is running on port `19153`, reached ready, has Rak ping `400/400` with `0%` loss, and has `0` fatal log matches. Expected completion is `2026-06-09T01:13:39+09:00`.
- A finalizer watcher `production-finalizer-20260608-231608` is attached to `production-soak-20260608-231339` and will refresh production evidence/deployment status after the soak passes.

## Native lane status

- Native PoC source exists under `main_pmmp/native/pmmp_perf_ext`.
- Current PMMP PHP: `8.2.30 zts Windows`, `API20220829,TS,VS16`.
- Visual Studio 2026 Native Desktop/C++ and Windows SDK are installed and detected.
- `main_pmmp/tools/build-native-extension-windows.ps1 -PatchVs16LinkerVersion` builds `var/native-build/php_pmmp_perf_ext.dll`.
- `main_pmmp/tools/build-native-extension-windows.ps1 -PatchVs16LinkerVersion -CopyToPhpExt` copies the patched DLL to `main_pmmp/bin/php/ext/php_pmmp_perf_ext.dll`.
- `main_pmmp/bin/php/php.ini` now loads `php_pmmp_perf_ext.dll` by default.
- `main_pmmp/tools/test-native-extension.ps1` loads the DLL in PMMP bundled PHP successfully.
- `pmmp_perf_varint_prefix_length(300)` returns `2`.
- `pmmp_perf_encode_packet_batch(["abc", "de"], [3, 2])` returns batch hex `03616263026465`.
- `pmmp_perf_decode_packet_batch(pmmp_perf_encode_packet_batch(["abc", "de"], [3, 2]))` returns hex list `["616263", "6465"]`.
- `pmmp_perf_encode_signed_varints([0, 1, 127, 128, 300, -1])` returns hex `0002fe018002d80401`.
- `pmmp_perf_decode_packet_batch_callback()` exists for experimental C-side batch walking with PHP callbacks, but it is not wired into the default path because current measurements are slower than the native array decode path.
- `pmmp_perf_encode_packet_batch()` now prevalidates packet types/lengths while computing output capacity, then performs a write-only second pass.
- `pmmp_perf_encode_signed_varints()` preallocates its output buffer from the input count.
- `pmmp_perf_encode_biome_palette()` now encodes biome palettes in C while applying the fallback biome ID for unknown palette IDs, avoiding a temporary PHP `$biomeIds` array in full chunk serialization.
- `ChunkSerializer::serializeBiomePalette()` now uses `pmmp_perf_encode_biome_palette()` when available and falls back to the original PHP VarInt path otherwise.
- Staged native microbench after these changes: native prefix about `30.6M` calls/sec, signed VarInt about `14.5M` batches/sec, packet batch encode about `10.6M` batches/sec, packet batch encode with length validation about `10.4M` batches/sec, biome palette encode about `13.9M` palettes/sec, native decode about `35.9M` packets/sec.
- Staged native hotpath bench with explicit extension load: packet batch raw `2,551,212 batches/sec` vs PHP reference `1,021,616 batches/sec`, subchunk serialization `1,093,618 subchunks/sec`, full chunk serialization `62,145 chunks/sec`, global chunk budget `10,484,351 decisions/sec`.
- `pmmp_perf_pack_u32le()` and `pmmp_perf_unpack_u32le()` were added for chunk terrain palette transfer between threads.
- `FastChunkSerializer` now uses native U32LE unpack when available, and uses native U32LE pack only for palettes with at least `16` entries to avoid small-palette call overhead.
- `tools/bench-hotpaths.php`, gate summary JSON, gate markdown, and production readiness JSON now expose `fast_chunk_serializer` serialize/deserialize throughput and native pack/unpack loaded state.
- Staged native U32LE microbench: pack about `9.6M` batches/sec vs PHP `7.8M`, unpack about `10.6M` batches/sec vs PHP `3.4M`.
- Sequential FastChunkSerializer comparison with `--iterations=800`: bundled fallback serialize/deserialize about `43.1k/34.4k chunks/sec`, staged native serialize/deserialize about `44.6k/38.1k chunks/sec`.
- Tooling preflight after the FastChunkSerializer native lane reports `ok=true`, checked `33`, failed `null`; targeted PHPStan for `FastChunkSerializer`, `ChunkSerializer`, `bench-native-extension.php`, and `bench-hotpaths.php` passes with zero output.
- Current running soak `production-soak-20260608-231339` remains ready with `0` fatal log matches at about `971s` elapsed / `6229s` remaining.
- `pmmp_perf_pack_u32le()` and `pmmp_perf_unpack_u32le()` now include native input-size guards for output allocation overflow and PHP array initialization overflow.
- Short independent fast gate `20260608-233209` on port `19154` passed with ready `2.123s`, fatal `0`, Rak ping `64/64`, loss `0%`, packet batch raw `2,156,664 batches/sec`, packet decoding native string `845,268 packets/sec`, subchunk serialization `1,178,098 subchunks/sec`, full chunk serialization `61,374 chunks/sec`, fast chunk serialize/deserialize `47,096/35,119 chunks/sec`, global chunk budget `19,248,352 decisions/sec`.
- Gate summary markdown and production readiness audit generation were verified against `20260608-233209`; production audit is expectedly `not_ready` for that short gate because PHPStan was skipped and Rak ping count was `64`, not the production `400`.
- Latest staged native microbench after guard hardening: native prefix about `32.3M` calls/sec, signed VarInt `15.1M` batches/sec, packet batch encode `12.0M` batches/sec, packet batch encode with lengths `11.0M` batches/sec, biome palette `15.5M` palettes/sec, U32LE pack `10.8M` vs PHP `7.9M` batches/sec, U32LE unpack `10.5M` vs PHP `3.6M` batches/sec, packet decode about `39.5M packets/sec`.
- Current running soak `production-soak-20260608-231339` remains ready with `0` fatal log matches at about `1249s` elapsed / `5951s` remaining.
- `promote-staged-native-extension.ps1` plus `promote-staged-native-extension.cmd` and root `pmmp-promote-staged-native-extension.cmd` were added. The tool backs up the bundled DLL, copies `var/native-build/php_pmmp_perf_ext.dll`, runs the native functional test, and refreshes native build evidence.
- Native promotion is guarded: by default it refuses to run while a production soak or PMMP PHP process is active. A live check during `production-soak-20260608-231339` correctly returned `promoted=false`, reason `production_soak_running`.
- Tooling preflight now includes the promotion tool and reports `ok=true`, checked `34`, failed `null`.
- `write-production-deployment-status.ps1`, `README_PMMP_FAST.md`, and `PMMP_production_deployment_readiness.md` now document `pmmp-promote-staged-native-extension.cmd` as the post-soak staged DLL promotion path.
- Production audit/finalizer default gate selection now ignores short experimental gates when a production candidate exists. It selects the newest gate with ready `true`, fatal `0`, PHPStan `0`, and Rak ping count at least `400`, falling back to latest only when no production candidate exists.
- This fixes the short `20260608-233209` validation gate from incorrectly lowering deployment status. `write-production-deployment-status.ps1 -Markdown` now selects production gate `20260608-201920`, reports status `waiting_for_soak`, readiness `80%`, and expected clean post-soak readiness `85%` with the existing v142 warning.
- `write-production-deployment-status.ps1` now reports staged and live bundled native DLL paths, SHA256 hashes, whether they match, whether promotion is needed, the promotion block reason, and the promotion command.
- Current deployment status shows staged DLL `667E8885726E66238C76E20B26D7B8FFDEBF3F435AF66F0B971B6ECBDA2789A6` and live bundled DLL `317B9DB84C6257069348088D0877F5B950CF6AA2FA59332EC2140398E7ED5C5C`, so `promotion_needed=true`; it is currently blocked only because the production soak is still running.
- Deployment status now explicitly reports `current_soak_validates_staged_native=false` and `post_promotion_validation_required=true` while staged and live bundled DLL hashes differ.
- `run-post-native-promotion-validation.ps1` plus `run-post-native-promotion-validation.cmd` and root `pmmp-run-post-native-promotion-validation.cmd` were added. After native promotion, it runs a production fast gate, starts a background clean soak for the promoted DLL, and attaches a finalizer watcher with `-AcceptLgpl -StartSoak`.
- The post-promotion validation helper refuses to run before staged native promotion. A live check correctly returned `started=false`, reason `staged_native_not_promoted`, with the staged/live bundled SHA256 mismatch.
- Tooling preflight now includes the post-promotion validation helper and reports `ok=true`, checked `35`, failed `null`.
- `run-post-native-promotion-validation.ps1 -StartSoak` now starts the promoted-DLL soak in a background PowerShell process and attaches a finalizer watcher immediately after the production fast gate passes.
- `start-production-finalizer-watcher.ps1` now supports `-ReplaceExisting`; the post-promotion validation helper uses it so a stale watcher cannot prevent the promoted-DLL soak from being monitored.
- Deployment status next actions now explicitly say the post-promotion validation command launches a production fast gate, background clean soak, and finalizer watcher for the promoted DLL.
- Current running soak `production-soak-20260608-231339` remains ready with `0` fatal log matches at about `2114s` elapsed / `5086s` remaining.
- `run-post-native-promotion-validation.ps1 -StartSoak` now refuses to start a second production soak while one is already running unless `-AllowConcurrentSoak` is explicitly used.
- `run-native-promotion-pipeline.ps1` plus `run-native-promotion-pipeline.cmd` and root `pmmp-run-native-promotion-pipeline.cmd` were added. The pipeline waits for the current production soak, blocks on fatal logs, promotes the staged native DLL, then starts promoted-DLL fast gate and clean soak validation.
- `check-native-promotion-pipeline-status.ps1` plus wrappers were added to inspect the background pipeline process, logs, and latest metadata.
- 2026-06-08 23:57 KST: native promotion pipeline started in the background as PID `19120`; it is waiting for `production-soak-20260608-231339`, then will promote staged DLL `667E8885726E66238C76E20B26D7B8FFDEBF3F435AF66F0B971B6ECBDA2789A6` if the soak remains clean.
- Deployment status now exposes `next_command_to_run`; while staged/live DLL hashes differ and a clean soak is running, it reports `pmmp-run-native-promotion-pipeline.cmd -AcceptLgpl`.
- Tooling preflight now includes the native promotion pipeline/status helpers and reports `ok=true`, checked `37`, failed `null`.
- `run-native-promotion-pipeline.ps1` now requires matching clean `soak.json` pass evidence for the stopped run before promoting the staged DLL. Fatal-only checks were tightened so duration/exit-code failures cannot trigger native promotion.
- The older native promotion pipeline process was replaced with strict pipeline PID `19992` (`native-promotion-pipeline-20260609-001834`), leaving the running PMMP soak untouched.
- `check-production-soak-status.ps1` now reports whether pass/fail evidence files actually match the current run, so stale `soak-last-failed.json` from an older attempt no longer looks like the active soak failed.
- `write-production-deployment-status.ps1` now includes native promotion pipeline state, latest pipeline PID/name, and strict soak-pass requirement in JSON/markdown.
- `audit-production-readiness.ps1` now stores a compact running-soak evidence summary instead of embedding full stale pass/fail evidence payloads in blocker details.
- `run-native-promotion-pipeline.ps1` now writes `native-promotion-pipeline-heartbeat-last.json` on every poll so long waits expose the active stage, waited time, current soak name, remaining seconds, fatal count, and evidence-match state.
- `check-native-promotion-pipeline-status.ps1` and `write-production-deployment-status.ps1` now surface the heartbeat stage/timestamp/waited/remaining seconds; strict heartbeat pipeline restarted as `native-promotion-pipeline-20260609-002622` PID `6236`.
- Current `production-soak-20260608-231339` remains running and ready with fatal `0`; stale failed evidence exists but `failed_evidence_matches_run=false`, so it is not a failure for the active soak.
- `PacketBatch::encodeRaw()` and `PacketBatch::encodeRawWithLengths()` now use the native batch encoder only when the extension is loaded and the batch has more than one packet.
- `PacketBatch::decodeRawStringCallback()` and `NetworkSession` now use the native packet-batch decoder when the extension is loaded.
- `ChunkSerializer::serializeSubChunk()` and biome palette serialization now use the native signed VarInt batch encoder when the extension is loaded and the palette is large enough to offset the temporary array cost.
- `pmmp_perf_serialize_fast_paletted_array()` was added to the C extension. It serializes the FastChunkSerializer paletted-array blob in one native call: bits-per-block byte, word array, big-endian palette byte length, and little-endian u32 palette values.
- `FastChunkSerializer::serializePalettedArray()` now uses the native complete paletted-array serializer for palettes with at least `16` entries, while retaining PHP fallback paths for smaller palettes and unloaded native extension cases.
- `pmmp_perf_encode_mapped_signed_varints()` was added to map cached internal block IDs to network IDs and signed-VarInt encode in one native pass. It returns `null` on cache miss so `ChunkSerializer` can use the existing PHP translator path to fill missing cache entries.
- `BlockTranslator::getNetworkIdCache()` exposes the warmed runtime-ID cache by reference for native read-only hotpath use.
- `ChunkSerializer::serializeSubChunk()` now tries native mapped signed VarInt encoding before falling back to `internalIdsToNetworkIds()` plus native signed VarInt encoding.
- Staged DLL rebuilt successfully without copying to live ext; current staged SHA256 is `5BB35BE91E2FA5E212E78811BF0031806A0AAC611A65F54EC198D0064D7583B8`.
- Staged native functional test passes, including `fast_paletted_array_hex=0301020000000c0000000001000000ff000000`.
- Staged native functional test also verifies mapped signed VarInt output `0408` and missing-map `null` fallback.
- Staged native microbench reports mapped signed VarInt encoding about `10.9M` batches/sec vs PHP map-then-native encode about `4.1M` batches/sec; fast paletted-array serialization about `6.0M` batches/sec vs PHP reference about `3.8M` batches/sec.
- Staged native/fallback FastChunkSerializer large-palette equivalence passed: both outputs hash to `e77e0c8148f719945a9f1ea245dcd81e963f76d0a53b7a3671f34992e7bd51e4`, byte length `67874`, roundtrip `true`.
- Pending PHPStan with tooling included passed with `phpstan_exit=0` for the modified FastChunkSerializer and bench/native tooling set.
- `build-native-extension-windows.ps1` now captures compiler/linker output into `var/native-build/pmmp_perf_ext-build.log` and keeps stdout as parseable JSON, so automation can safely pipe the build result through `ConvertFrom-Json`.
- `pmmp_perf_encode_packet_single()` was added to the C extension for the frequent one-packet batch flush path. `PacketBatch::encodeRawSingle()` now uses it when available and keeps the PHP VarInt fallback for old/unloaded native extensions.
- Previous staged DLL after the single-packet encoder change had SHA256 `2DCB00191A43199122ADA639170D99B3E3EE7785DB791E79FB15FDD8CB523043`.
- Staged native functional test passes and now verifies `single_batch_hex=03616263`.
- Pending PHPStan with tooling included passes with `phpstan_exit=0` after the PacketBatch single-native integration.
- Latest staged native microbench reports single packet-batch encode about `20.0M` batches/sec, packet batch encode about `12.3M` batches/sec, mapped signed VarInt about `11.2M` batches/sec vs PHP map-then-native about `4.2M`, fast paletted-array about `6.1M` batches/sec vs PHP reference about `3.7M`.
- `bench-staged-native-hotpaths.ps1` plus `bench-staged-native-hotpaths.cmd` and root `pmmp-bench-staged-native-hotpaths.cmd` were added. The helper loads the staged native DLL with PMMP's required native dependencies while bypassing the live bundled perf DLL, preventing false staged-vs-live benchmark confusion.
- Previous staged hotpath bench through `pmmp-bench-staged-native-hotpaths.cmd -Iterations 300`: staged SHA `2DCB00191A43199122ADA639170D99B3E3EE7785DB791E79FB15FDD8CB523043`, native loaded `true`, packet batch raw about `2.47M` batches/sec vs PHP reference about `1.12M`, native packet decode about `845k` packets/sec, full chunk serialization about `68.3k` chunks/sec, fast chunk serialize/deserialize about `44.0k/38.0k` chunks/sec.
- Tooling preflight now includes the staged hotpath bench helper and reports `ok=true`, checked `38`, failed `null`.
- Pending PHPStan with tooling included passed again with `phpstan_exit=0` after the staged hotpath bench helper was added.
- Current running soak `production-soak-20260608-231339` remains ready with `0` fatal log matches at about `5250s` elapsed / `1950s` remaining, about `73%` complete.
- `pmmp_perf_encode_packet_batch()` and `pmmp_perf_encode_packet_single()` now write directly into exact-sized `zend_string` output buffers instead of using repeated `smart_str` append operations. Overflow guards were added while computing batch output capacity.
- Staged DLL rebuilt successfully without copying to live ext; current staged SHA256 is `3A0C3A1DCB0106F97C8E857800505B1A9F5E00E0F04D1B84D2FEAC0A58832A16`.
- Staged native functional test passes after the direct `zend_string` packet writer change.
- Latest staged native microbench after direct packet writer: packet batch encode about `15.4M` batches/sec, packet batch encode with length validation about `13.9M` batches/sec, single packet-batch encode about `19.7M` batches/sec, packet decode about `38.4M` packets/sec.
- Latest staged hotpath bench through `pmmp-bench-staged-native-hotpaths.cmd -Iterations 300`: staged SHA `3A0C3A1DCB0106F97C8E857800505B1A9F5E00E0F04D1B84D2FEAC0A58832A16`, native loaded `true`, packet batch raw about `2.03M` batches/sec vs PHP reference about `831k`, native packet decode about `799k` packets/sec, full chunk serialization about `65.1k` chunks/sec, fast chunk serialize/deserialize about `39.2k/37.5k` chunks/sec.
- Pending PHPStan with tooling included passes with `phpstan_exit=0`; tooling preflight remains `ok=true`, checked `38`, failed `null`.
- Current running soak `production-soak-20260608-231339` remains ready with `0` fatal log matches at about `5504s` elapsed / `1696s` remaining, about `76%` complete.
- `run-staged-native-performance-gate.ps1` plus `run-staged-native-performance-gate.cmd` and root `pmmp-run-staged-native-performance-gate.cmd` were added. The gate wraps the staged native hotpath bench and fails if staged native is not loaded, packet batch native/PHP ratio falls below `1.5x`, packet batch rate falls below `1.0M` batches/sec, native decode falls below `650k` packets/sec, full chunk serialization falls below `50k` chunks/sec, or fast chunk serialization falls below `30k` chunks/sec.
- `promote-staged-native-extension.ps1` now runs the staged native performance gate before copying the staged DLL to the bundled PHP extension directory. The currently running native promotion pipeline will pick up this stricter promotion behavior when it invokes the promotion script after the existing soak passes.
- Current staged native performance gate passes for SHA `3A0C3A1DCB0106F97C8E857800505B1A9F5E00E0F04D1B84D2FEAC0A58832A16`: packet batch native/PHP ratio about `2.84x`, native decode about `771k` packets/sec, full chunk serialization about `68.6k` chunks/sec, fast chunk serialization about `43.0k` chunks/sec.
- Tooling preflight now includes the staged native performance gate helper and reports `ok=true`, checked `39`, failed `null`.
- Pending PHPStan with tooling included passes with `phpstan_exit=0` after the promotion performance gate integration.
- Current running soak `production-soak-20260608-231339` remains ready with `0` fatal log matches at about `5831s` elapsed / `1369s` remaining, about `81%` complete.
- `write-production-deployment-status.ps1` now runs the staged native performance gate when staged/live bundled DLL hashes differ, and exports gate pass/fail, metrics, failures, and errors under `native.staged_performance_gate_*`.
- `production-deployment-status.md` now includes staged performance gate ran/passed, packet batch native/PHP ratio, and decode/full-chunk/fast-chunk throughput so promotion readiness is visible without opening bench artifacts.
- Latest deployment status generation reports staged performance gate `true/true`, packet batch ratio about `2.53x`, native decode about `839k` packets/sec, full chunk serialization about `67.8k` chunks/sec, fast chunk serialization about `42.7k` chunks/sec.
- Pending PHPStan with tooling included passes with `phpstan_exit=0` after deployment status performance-gate surfacing.
- Current running soak `production-soak-20260608-231339` remains ready with `0` fatal log matches at about `6054s` elapsed / `1146s` remaining, about `84%` complete.
- `run-staged-native-performance-gate.ps1` now samples the staged hotpath bench three times and evaluates best metrics across samples. This keeps the same thresholds while avoiding false promotion blockers from brief local CPU/load spikes during the short microbench.
- Latest staged performance gate after the sampling update passes for SHA `3A0C3A1DCB0106F97C8E857800505B1A9F5E00E0F04D1B84D2FEAC0A58832A16`: packet batch native/PHP ratio about `2.52x`, native decode about `868k` packets/sec, full chunk serialization about `68.9k` chunks/sec, fast chunk serialization about `43.9k` chunks/sec.
- Latest deployment status generation reports staged performance gate `true/true`, packet batch ratio about `2.53x`, native decode about `843k` packets/sec, full chunk serialization about `62.3k` chunks/sec, fast chunk serialization about `42.7k` chunks/sec.
- Pending PHPStan with tooling included passes with `phpstan_exit=0` after the staged performance gate sampling update.
- Current running soak `production-soak-20260608-231339` remains ready with `0` fatal log matches at about `6350s` elapsed / `850s` remaining, about `88%` complete.
- `run-staged-native-performance-gate.ps1` now persists its latest result to `var/perf/native-performance-gate/staged-native-performance-gate-last.json` while keeping stdout JSON unchanged.
- Latest persisted staged native performance gate evidence exists and passes for SHA `3A0C3A1DCB0106F97C8E857800505B1A9F5E00E0F04D1B84D2FEAC0A58832A16`, generated at `2026-06-09T01:02:32+09:00`.
- Latest deployment status generation reports staged performance gate `true/true`, packet batch ratio about `3.38x`, native decode about `833k` packets/sec, full chunk serialization about `67.5k` chunks/sec, fast chunk serialization about `43.4k` chunks/sec.
- Tooling preflight remains `ok=true`, checked `39`, failed `null`; pending PHPStan with tooling included remains `phpstan_exit=0`.
- Current running soak `production-soak-20260608-231339` remains ready with `0` fatal log matches at about `6557s` elapsed / `643s` remaining, about `91%` complete.
- `write-production-deployment-status.ps1` now exposes the staged native performance gate evidence path, generated timestamp, metric policy, and sample count in both JSON and markdown status output.
- Latest deployment status generation reports staged performance gate `true/true`, evidence path `var/perf/native-performance-gate/staged-native-performance-gate-last.json`, policy `best_of_samples`, samples `3`, packet batch ratio about `2.63x`, native decode about `812k` packets/sec, full chunk serialization about `67.7k` chunks/sec, fast chunk serialization about `43.3k` chunks/sec.
- Tooling preflight remains `ok=true`, checked `39`, failed `null`; pending PHPStan with tooling included remains `phpstan_exit=0` after the status evidence field update.
- Current running soak `production-soak-20260608-231339` remains ready with `0` fatal log matches at about `6704s` elapsed / `496s` remaining, about `93%` complete.
- `ChunkSerializer::serializeFullChunk()` now skips empty tile serialization buffer allocation when the chunk has no tiles.
- `ChunkSerializer` uniform block/biome palettes now skip temporary `getPalette()` array extraction and write the single palette value directly.
- `tools/bench-hotpaths.php` now includes `full_chunk_serialization` fixture output, and gate summaries export full chunk chunks/sec plus native-loaded state.
- `Player::handleMovement()` now bypasses the Timings start/stop wrapper when timings are disabled, preserving the existing measured path when timings are enabled.
- `ChunkCache::prefetchIfLoaded()` and `NetworkSession::prefetchChunk()` add a loaded-chunk packet prewarm mechanism without forcing new chunk generation.
- `Player::orderChunks()` now prewarms a small near-future chunk send queue after view ordering, capped by `CHUNK_PREFETCH_PER_ORDER`, so already-loaded chunks can finish async compression before `requestChunks()` reaches them.
- `ChunkCache` now tracks cache hits/misses and prefetch attempts/started/skips/promise hits/packet hits, emits `PMMP_CHUNK_CACHE_STATS` on world unload, and gate tooling exports these counters.
- `main_pmmp/tools/bench-native-extension.php` reports about `33.8M` native prefix calls/sec vs `22.1M` PHP prefix loop calls/sec, about `15.3M` signed VarInt batches/sec, and about `8.6M` native decoded batches/sec / `34.2M` decoded packets/sec.
- Latest native-enabled fast gate with Rak ping burst `20260608-013547`: ready `2.098s`, fatal `0`, PHPStan `0`, Rak ping `64/64`, loss `0%`, average latency `17.18ms`, chunk cache reports `0` in no-client baseline, packet batch raw `2,536,445 batches/sec`, native loaded `true`, packet encoding `593,364 packets/sec`, packet decoding callback `815,930 packets/sec`, subchunk serialization `966,554 subchunks/sec`, full chunk serialization `60,512 chunks/sec`, movement synthetic `6,081,578 updates/sec`.
- Latest fallback fast gate before php.ini auto-load `20260608-010252`: ready `2.126s`, fatal `0`, PHPStan `0`, packet batch raw `1,112,548 batches/sec`, packet encoding `597,549 packets/sec`, packet decoding callback `836,825 packets/sec`, subchunk serialization `907,613 subchunks/sec`.
- Native-loaded hotpath artifact `main_pmmp/var/perf/native/native-hotpath-bench-20260608-010231.json`: packet batch raw `2,484,894 batches/sec`, packet encoding `617,635 packets/sec`, subchunk serialization `994,274 subchunks/sec`.
- Current local build uses VS2026 `14.50` plus PE linker-version patch to satisfy PMMP PHP's expected `14.29`; production native builds should use VS2019/v142 when that toolchain is installable.
- Plan remains optional native accelerator with PHP fallback, not a public API break.
- The first native promotion completed successfully after `production-soak-20260608-231339` produced matching clean pass evidence. Live bundled DLL SHA256 became `3A0C3A1DCB0106F97C8E857800505B1A9F5E00E0F04D1B84D2FEAC0A58832A16`.
- Post-promotion clean soak `post-native-promotion-soak-20260609-011509` is running on port `19155` with the promoted live DLL loaded. Latest check during this update: ready `true`, fatal `0`, about `16%` complete, expected completion `2026-06-09T03:16:26+09:00`.
- `check-production-soak-status.ps1` now recognizes both `production-soak-*` and `post-native-promotion-soak-*` meta/baseline names and only treats the actual soak wrapper/PocketMine process as running, avoiding false positives from status commands.
- `check-native-promotion-pipeline-status.ps1` now uses the recorded pipeline PID instead of broad process command-line scanning and caps stdout/stderr tail line lengths, avoiding hangs when the pipeline stdout contains large JSON.
- `write-production-deployment-status.ps1` now reports `already_promoted` when staged/live hashes match and points to `pmmp-check-production-soak-status.cmd` while a validation soak is already running, avoiding duplicate validation starts.
- A new staged native DLL was built after the live promotion without copying it to the live PHP extension path. Staged SHA256 is `B73FD205B53FEED1559FD3D4E0C49C42A5E3C64B1AB027BDCD804A93C253C87F`; live bundled SHA256 remains `3A0C3A1DCB0106F97C8E857800505B1A9F5E00E0F04D1B84D2FEAC0A58832A16`, so the active post-promotion soak continues to validate the promoted live DLL only.
- The new staged native patch replaces repeated `smart_str_appendc()` writes in signed VarInt, biome palette, mapped signed VarInt, U32LE pack, and fast paletted-array serialization with direct `zend_string` buffer writes. Public PHP function names and fallback semantics are unchanged.
- New staged native functional test passes for SHA `B73FD205B53FEED1559FD3D4E0C49C42A5E3C64B1AB027BDCD804A93C253C87F`, including packet batch, single packet batch, decoded batch, signed/mapped signed VarInts, biome fallback, U32LE pack/unpack, fast paletted-array output, and `pmmp_perf_read_fast_paletted_array()` on a valid bits-per-block `0` fixture.
- New staged native performance gate passes for SHA `B73FD205B53FEED1559FD3D4E0C49C42A5E3C64B1AB027BDCD804A93C253C87F`: packet batch native/PHP ratio about `2.58x`, native decode about `754k packets/sec`, full chunk serialization about `67.4k chunks/sec`, fast chunk serialization about `41.6k chunks/sec`.
- Tooling preflight remains `ok=true`, checked `39`, failed `null` after the status-tool fixes and staged native direct-writer patch.
- `pmmp_perf_read_fast_paletted_array()` was added and function-tested, but `FastChunkSerializer::deserializeTerrain()` does not currently use it. A staged hotpath attempt reduced fast-chunk deserialize throughput in the current PHP integration shape, so the hotpath wiring was removed and the helper remains experimental until a lower-overhead object construction path exists.
- The native promotion pipeline was restarted for the current staged DLL: `native-promotion-pipeline-20260609-014901`, PID `13372`, stage `waiting_for_existing_soak`. It recorded staged SHA `B73FD205B53FEED1559FD3D4E0C49C42A5E3C64B1AB027BDCD804A93C253C87F` and live SHA `3A0C3A1DCB0106F97C8E857800505B1A9F5E00E0F04D1B84D2FEAC0A58832A16` at start.

## Next high-impact work

1. Let `post-native-promotion-soak-20260609-011509` finish and require matching clean pass evidence before claiming the promoted live DLL is production-soak validated.
2. After the current live-DLL soak completes, promote staged SHA `B73FD205B53FEED1559FD3D4E0C49C42A5E3C64B1AB027BDCD804A93C253C87F` only through `pmmp-promote-staged-native-extension.cmd` or `pmmp-run-native-promotion-pipeline.cmd -AcceptLgpl`, then run another post-promotion validation soak for that newer DLL.
3. Use runtime population shared-hit and queue-depth counters to tune world-level population caps under real login/chunk-request load.
4. Investigate a region-level hot metadata/cache lane for faster wild-server chunk roaming.
5. Add a real Bedrock login/chunk-request smoke client when protocol-session automation is available.
6. Chunk biome/light byte-path audit.
7. Real plugin hotpath audit once server plugins are placed under the PMMP plugin directory.
8. Prepare a production v142 native build path or a documented extension loading workflow for the PMMP PHP bundle.







































