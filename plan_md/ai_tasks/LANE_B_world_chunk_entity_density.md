# Lane B prompt: world, chunk, and entity density

You are working in `C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp`.

Goal: reduce per-tick and chunk/save overhead for many players/entities in wild survival.

Read first:

- `plan_md/PMMP_latest_progress_2026-06-07.md`
- `plan_md/PMMP_AI_parallel_execution_board.md`
- `plan_md/CODEX_windows_sandbox_issue_2026-06-07.md`

Primary files:

- `src/world/World.php`
- `src/world/Explosion.php`
- `src/player/ChunkSelector.php`
- `src/player/Player.php`
- `src/entity/*`
- `src/network/mcpe/serializer/ChunkSerializer.php`

Current implemented areas:

- `World::forEachNearbyEntity()`
- `World::forEachCollidingEntity()`
- `World::hasNearbyEntities()`
- `World::hasCollidingEntities()`
- direct chunk save NBT loops
- scalar movement/distance checks
- chunk serialization lookup reuse

Task:

1. Search for remaining hotpath result-array creation in tick/save/unload paths.
2. Replace `array_map`, `array_filter`, `array_values`, `array_merge` chains with direct loops only where semantics are identical.
3. Replace `** 2` in hot movement/distance paths with scalar multiplication.
4. Avoid changing methods whose return arrays are public API unless internal call sites can use a new helper.
5. Add modified PHP files to `tools/run-fast-gates.ps1`.

Validation when shell works:

```powershell
cd C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\continue-fast-progress.ps1
```

Deliverables:

- PHP patch
- short compatibility note
- progress document update
