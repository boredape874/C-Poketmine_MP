# PMMP implementation backlog

This backlog is ordered for fast movement toward a high-density single PMMP survival server target.

## P0: Keep validation and handoff working

### P0-1: Run one-command progress validation

Files:

- `main_pmmp/tools/continue-fast-progress.ps1`
- `main_pmmp/tools/update-latest-progress.ps1`
- `main_pmmp/tools/export-ai-handoff.ps1`

Action:

```powershell
cd C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\continue-fast-progress.ps1
```

Expected output:

- tooling preflight JSON
- pending PHPStan JSON
- pending PHPStan raw output under `var/perf/pending-phpstan/<stamp>/phpstan.txt`
- fast gate JSON
- compare summary JSON
- gate `summary.md`
- refreshed `plan_md/PMMP_latest_progress_2026-06-07.md`
- refreshed `var/perf/ai-handoff/handoff.md`

Risk: low.

If pending PHPStan fails, `continue-fast-progress.ps1` intentionally skips the full fast gate. Fix the files listed in `pending_phpstan.output` first.

`run-pending-phpstan.ps1` can be run standalone for a process exit code, or called from automation with `-NoExitCode` so the parent can parse the JSON result before stopping.

If tooling preflight fails, fix the PowerShell script listed in `tooling_preflight.scripts` before running PHPStan or the fast gate.
`run-tooling-preflight.ps1` can be run standalone for an exit code, or called from automation with `-NoExitCode`.

Gate `summary.md` includes compare warning reasons and hotpath threshold warnings for obvious bench regressions.
Hotpath thresholds live in `main_pmmp/tools/hotpath-thresholds.json`.

## P1: World/entity/chunk density

### P1-1: Add nearby entity iteration bench

Files:

- `main_pmmp/tools/bench-hotpaths.php`
- `main_pmmp/tools/run-fast-gates.ps1`
- `main_pmmp/src/world/World.php`

Action:

- Add a fixture that creates a small world-like entity bucket set or a lightweight stand-in around `World::forEachNearbyEntity()` behavior.
- Record operations/sec for:
  - result-array nearby entity path
  - callback nearby entity path
  - boolean nearby entity path

Expected effect:

- Makes the no-array entity iteration changes measurable.

Risk: low if bench-only.

### P1-2: Finish direct-loop save path audit

Files:

- `main_pmmp/src/world/World.php`
- `main_pmmp/src/world/format/*`
- `main_pmmp/src/entity/Human.php`

Action:

- Find remaining hot save/unload paths using:
  - `array_map`
  - `array_filter`
  - `array_values`
  - `array_merge`
- Replace only where result order and keys are clearly compatible.

Expected effect:

- Lower GC pressure during autosave and chunk unload.

Risk: medium because save semantics matter.

Validation:

- PHPStan on changed files.
- Fast gate.
- Manual review of saved entity/tile list order.

### P1-3: Audit `getChunkEntities()` call sites

Files:

- `main_pmmp/src/world/World.php`
- `main_pmmp/src/player/Player.php`
- `main_pmmp/src/entity/*`

Action:

- Keep public `getChunkEntities()` unchanged.
- Replace internal call sites with direct bucket iteration only when no caller needs a returned array.

Expected effect:

- Avoids array returns and extra lookups in repeated chunk/entity operations.

Risk: medium.

## P2: Network packet throughput

### P2-1: Common packet encode fixture bench

Files:

- `main_pmmp/tools/bench-hotpaths.php`
- `main_pmmp/src/network/mcpe/StandardPacketBroadcaster.php`
- `main_pmmp/vendor/pocketmine/bedrock-protocol/src/serializer/PacketBatch.php`

Action:

- Add fixture cases for common packets:
  - movement
  - block update
  - entity metadata
  - inventory slot/container update if available without broad setup
- Compare:
  - packet encode only
  - raw batch encode
  - raw batch encode with known lengths

Expected effect:

- Makes packet changes measurable and prevents optimizing only synthetic byte strings.

Risk: low for bench-only.

### P2-2: Broadcast path encode reuse audit

Files:

- `main_pmmp/src/entity/Entity.php`
- `main_pmmp/src/player/Player.php`
- `main_pmmp/src/network/mcpe/NetworkBroadcastUtils.php`
- `main_pmmp/src/network/mcpe/StandardPacketBroadcaster.php`

Action:

- Check high-frequency animation, movement, sound, and metadata broadcasts.
- Avoid repeated packet arrays or repeated object-id calls.
- Preserve plugin-visible event behavior.

Expected effect:

- Lower per-viewer broadcast overhead.

Risk: medium.

## P3: Player and inventory hotpaths

### P3-1: Mining/update bench fixture

Files:

- `main_pmmp/tools/bench-hotpaths.php`
- `main_pmmp/src/player/SurvivalBlockBreakHandler.php`
- `main_pmmp/src/player/Player.php`

Action:

- Add a microbench around scalar range checks and break progress update shape.
- Avoid requiring a real connected player if setup is too heavy; use a narrow fixture or skip until practical.

Expected effect:

- Makes player mining hotpath work measurable.

Risk: low for bench-only.

### P3-2: Inventory clone audit

Files:

- `main_pmmp/src/inventory/SimpleInventory.php`
- `main_pmmp/src/inventory/BaseInventory.php`
- `main_pmmp/src/entity/object/ItemEntity.php`

Action:

- Find repeated item clones in add/canAdd paths.
- Keep mutation semantics identical.
- Avoid changing public inventory behavior.

Expected effect:

- Lower item pickup/drop pressure.

Risk: medium.

## P4: Translation and serialization caches

### P4-1: Pure mapping cache audit

Files:

- `main_pmmp/src/network/mcpe/convert/ItemTranslator.php`
- `main_pmmp/src/network/mcpe/convert/BlockTranslator.php`
- `main_pmmp/src/network/mcpe/serializer/ChunkSerializer.php`

Action:

- Only cache pure mappings whose inputs are stable after bootstrap.
- Do not cache mutable packet, item, block, or NBT objects unless immutable by contract.

Expected effect:

- Lower repeated conversion cost.

Risk: medium.

## P5: Native extension

### P5-1: Build environment

Files:

- `main_pmmp/tools/check-native-extension-env.ps1`
- `main_pmmp/native/pmmp_perf_ext/*`

Action:

- Run native env check.
- Install/expose matching PHP build toolchain outside PMMP source if needed.
- Build PoC only after toolchain matches PHP `8.2.30 zts Windows`.

Expected effect:

- Unlock optional C helpers.

Risk: high if toolchain mismatches; keep optional.

## Current fast command

Use this after any implementation batch:

```powershell
cd C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\continue-fast-progress.ps1
```

If shell fails with `windows sandbox: spawn setup refresh`, stop shell retries and follow `plan_md/CODEX_windows_sandbox_issue_2026-06-07.md`.
