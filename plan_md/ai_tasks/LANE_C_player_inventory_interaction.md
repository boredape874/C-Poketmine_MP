# Lane C prompt: player, inventory, and interaction hotpaths

You are working in `C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp`.

Goal: reduce overhead from 400 players mining, fighting, using items, picking up drops, and interacting with inventories.

Primary files:

- `src/player/Player.php`
- `src/player/SurvivalBlockBreakHandler.php`
- `src/inventory/SimpleInventory.php`
- `src/entity/object/ItemEntity.php`
- `src/entity/Human.php`

Current implemented areas:

- player movement clone avoidance
- scalar movement/distance checks
- direct `SimpleInventory::addItem()` path
- item pickup inventory reference caching
- human drops direct loops

Task:

1. Audit attack/use-item/mining paths for repeated `getItemInHand()`, `getWorld()`, `getViewers()`, and unnecessary temporary objects.
2. Keep all events and plugin-visible behavior identical.
3. Prefer local variable caching only where it cannot become stale inside plugin event calls.
4. Add focused hotpath bench fixtures if practical.
5. Update `tools/run-fast-gates.ps1` PHPStan target list.

Validation:

```powershell
cd C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\continue-fast-progress.ps1
```

Deliverables:

- PHP patch
- compatibility note
- progress document update
