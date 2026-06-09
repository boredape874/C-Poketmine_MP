# PMMP subagent runs

This file records delegated AI/subagent work for the PMMP performance project.

## Active runs

### Worker E: tooling/evidence

- Agent nickname: `Turing`
- Agent id: `019ea0ca-0e18-7600-b5b0-442a3d10ab4a`
- Scope:
  - `main_pmmp/tools/run-fast-gates.ps1`
  - `main_pmmp/tools/continue-fast-progress.ps1`
  - `main_pmmp/tools/update-latest-progress.ps1`
  - `main_pmmp/tools/export-ai-handoff.ps1`
  - `main_pmmp/tools/bench-hotpaths.php`
  - docs if needed
- Task:
  - make fast gate result verification easier
  - handle missing optional bench fields robustly
  - add compact markdown gate summary if practical
  - keep JSON output machine-readable
- Status: shutdown after repeated wait timeouts
- Result:
  - no completed output received
  - keep existing local tooling patches as source of truth

### Explorer B: world/chunk/entity density

- Agent nickname: `Confucius`
- Agent id: `019ea0ca-3d60-7fe2-9dff-46f3b2609fa4`
- Scope:
  - `main_pmmp/src/world/World.php`
  - `main_pmmp/src/entity/*`
  - `main_pmmp/src/player/Player.php`
  - `main_pmmp/src/network/mcpe/serializer/ChunkSerializer.php`
- Task:
  - inspect low-risk world/chunk/entity hotpath candidates
  - no file edits
  - return ranked candidate list with patch shapes
- Status: completed
- Result:
  - recommended direct chunk entity visitor helper
  - recommended player chunk entity visitor path
  - recommended `World::getNearestEntity()` scalar/object-allocation audit
  - recommended `Entity::sendSpawnPacket()` attribute conversion loop
  - recommended `AttributeMap::needSend()` direct loop
- Applied locally:
  - `main_pmmp/src/entity/AttributeMap.php`: `needSend()` now uses a direct loop instead of `array_filter()`.
  - `main_pmmp/tools/run-fast-gates.ps1`: added `AttributeMap.php` to PHPStan target list.

### Explorer C: player/inventory/interaction

- Agent nickname: `Schrodinger`
- Agent id: `019ea0cb-d8c2-7c92-88e0-9a073911e19e`
- Scope:
  - `main_pmmp/src/player/Player.php`
  - `main_pmmp/src/player/SurvivalBlockBreakHandler.php`
  - `main_pmmp/src/inventory/SimpleInventory.php`
  - `main_pmmp/src/inventory/BaseInventory.php`
  - `main_pmmp/src/entity/object/ItemEntity.php`
  - `main_pmmp/src/entity/Human.php`
- Task:
  - inspect low-risk player/inventory hotpath candidates
  - no file edits
  - return ranked candidate list with patch shapes
- Status: completed
- Result:
  - recommended SurvivalBlockBreakHandler local caching
  - recommended death inventory clear direct slot loop
  - recommended BaseInventory direct viewer iteration
  - recommended ItemEntity merge array avoidance
  - recommended preserving SimpleInventory clone safety model
- Applied locally:
  - `main_pmmp/src/player/Player.php`: death inventory clear now uses a slot loop preserving slot keys.
  - `main_pmmp/src/inventory/BaseInventory.php`: internal content-change sync now iterates `$this->viewers` directly.
  - `main_pmmp/tools/run-fast-gates.ps1`: added `BaseInventory.php` to PHPStan target list.

### Worker C1: survival block break local caching

- Agent nickname: `Banach`
- Agent id: `019ea0d2-a14c-7f70-8bfd-f8f1f580cf19`
- Scope:
  - `main_pmmp/src/player/SurvivalBlockBreakHandler.php`
- Task:
  - cache `$player` and `$world` locally inside mining hotpath methods
  - preserve per-tick item/world behavior
- Status: shutdown after repeated wait timeouts
- Result:
  - no completed output received
  - Explorer C recommendations remain in backlog

### Worker B1: chunk entity visitor

- Agent nickname: `Hypatia`
- Agent id: `019ea0d2-ef1d-7322-a0bc-06d180c4011f`
- Scope:
  - `main_pmmp/src/world/World.php`
  - `main_pmmp/src/player/Player.php`
  - `main_pmmp/tools/run-fast-gates.ps1` if target updates are needed
- Task:
  - add API-preserving chunk entity visitor
  - replace low-risk visitor-only `getChunkEntities()` loops
  - preserve public `getChunkEntities()` API
- Status: shutdown after repeated wait timeouts
- Result:
  - no completed output received
  - Explorer B recommendations remain in backlog

## Completed runs

2026-06-07 KST
Agent: Fermat
Scope:
- `main_pmmp/src/entity/Entity.php`
- `main_pmmp/src/entity/AttributeMap.php`
Changed files:
- none by agent
Validation:
- read-only context extraction
Result:
- confirmed `AttributeMap::needSend()` already direct loop
- identified stale `array_filter` import
- provided exact `Entity::sendSpawnPacket()` `array_map()` patch shape
Follow-up:
- local integration applied to `Entity.php` and `AttributeMap.php`

2026-06-07 KST
Agent: Parfit
Scope:
- `main_pmmp/src/entity/object/ItemEntity.php`
Changed files:
- none by agent
Validation:
- read-only context extraction
Result:
- confirmed `ItemEntity` already uses `World::forEachNearbyEntity()`
- provided exact merge scan patch to avoid allocating candidate array when no nearby merge candidate exists
Follow-up:
- local integration applied to `ItemEntity.php`

Append completed outputs here before merging or assigning follow-up work.

```text
YYYY-MM-DD HH:mm KST
Agent:
Scope:
Changed files:
Validation:
Result:
Follow-up:
```
