# PMMP parallel merge protocol

Use this when multiple AI sessions or subagents work on the PMMP performance lanes at the same time.

## Branch/work scope

Each lane should keep changes scoped:

- Lane A: network packet throughput
- Lane B: world/chunk/entity density
- Lane C: player/inventory/interaction
- Lane D: translation and serialization caches
- Lane E: tooling/gates/evidence
- Lane F: native extension
- Lane G: plugin audit

Avoid mixing unrelated lanes in one patch unless the dependency is obvious.

## Required notes from each lane

Every lane handoff must include:

- files changed
- public API compatibility statement
- validation command used
- latest gate name if available
- PHPStan target list updates
- any skipped validation and why

## Conflict handling

Preferred merge order:

1. Lane E tooling changes
2. Lane B world/entity/chunk changes
3. Lane A network changes
4. Lane C player/inventory changes
5. Lane D cache changes
6. Lane F native changes
7. Lane G plugin changes

Reason:

- Tooling first improves evidence collection.
- World/network/player changes overlap most with benchmarks and should be validated after tooling.
- Native/plugin changes are more environment-dependent.

## Shared files to watch

These files are likely to conflict:

- `main_pmmp/tools/run-fast-gates.ps1`
- `main_pmmp/tools/bench-hotpaths.php`
- `main_pmmp/tools/export-ai-handoff.ps1`
- `plan_md/PMMP_latest_progress_2026-06-07.md`
- `main_pmmp/src/world/World.php`
- `main_pmmp/src/player/Player.php`

For these files, preserve all lane additions unless they are clearly duplicate or stale.

## Minimum validation after merge

When shell works:

```powershell
cd C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\continue-fast-progress.ps1
```

If this fails:

1. Check `var/perf/gates/<latest>/phpstan.txt`.
2. Check `var/perf/baseline/<latest>/server.log`.
3. Fix only the failing lane's change if possible.
4. Rerun the same command.

## Do not merge blindly

Do not merge changes that:

- remove LGPL/license headers
- change public plugin APIs without a compatibility shim
- alter event call order without a written reason
- add native extension requirements without PHP fallback
- make fast gate impossible to run
- hide warnings by changing gates instead of fixing code
