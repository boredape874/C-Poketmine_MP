# Lane G prompt: plugin and server pack audit

You are working in `C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp`.

Goal: make sure plugins, packs, and operational scripts do not erase PMMP core performance gains.

Read first:

- `plan_md/PMMP_latest_progress_2026-06-07.md`
- `plan_md/PMMP_AI_parallel_execution_board.md`
- `plan_md/PMMP_implementation_backlog.md`

Primary files:

- `plugins/` when real plugins are present
- `tools/audit-plugin-hotpaths.ps1`
- `plan_md/*`

Current status:

- Plugin audit tooling exists.
- Real production plugins may not yet be present under `main_pmmp/plugins`.

Task:

1. If real plugins exist, audit frequent event handlers and scheduler tasks.
2. Flag sync disk/database/network I/O in hot events.
3. Flag per-player/per-entity loops in movement, interact, inventory, block break/place, damage, and join/quit flows.
4. Rank findings by tick impact.
5. Do not rewrite plugin behavior without a focused patch plan.

Validation:

```powershell
cd C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\audit-plugin-hotpaths.ps1 -Markdown
```

Deliverables:

- plugin audit markdown
- ranked fix list
- patch candidates only when plugin ownership and behavior are clear
