# Lane D prompt: translation and serialization caches

You are working in `C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp`.

Goal: reduce repeated pure mapping, translation, and serialization work in PMMP network/chunk hotpaths while preserving plugin API behavior.

Read first:

- `plan_md/PMMP_latest_progress_2026-06-07.md`
- `plan_md/PMMP_AI_parallel_execution_board.md`
- `plan_md/PMMP_implementation_backlog.md`

Primary files:

- `src/network/mcpe/convert/ItemTranslator.php`
- `src/network/mcpe/convert/BlockTranslator.php`
- `src/network/mcpe/serializer/ChunkSerializer.php`
- `src/world/format/*`
- `tools/bench-hotpaths.php`

Current implemented areas:

- item network ID cache keyed by item state ID
- block network state data cache
- subchunk block state dictionary lazy path
- biome legacy-to-string map reuse

Task:

1. Search for pure mapping functions in packet/chunk hotpaths.
2. Cache only stable immutable mapping results.
3. Do not cache mutable `Item`, `Block`, packet, or NBT instances unless immutable by contract.
4. Add a hotpath bench fixture for each new cache when practical.
5. Add modified PHP files to `tools/run-fast-gates.ps1`.

Validation:

```powershell
cd C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\continue-fast-progress.ps1
```

Deliverables:

- PHP patch
- benchmark fixture update if useful
- short note explaining cache correctness and invalidation assumptions
