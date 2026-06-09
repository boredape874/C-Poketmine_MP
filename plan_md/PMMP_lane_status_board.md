# PMMP lane status board

Use this file as the live status board for parallel PMMP performance work. Update it after each lane produces a patch.

## Current global validation

Updated: 2026-06-09 KST.

| Field | Value |
| --- | --- |
| Fast-release status | Complete |
| Strict production status | `waiting_for_soak` |
| Active strict soak | `production-v142-strict-soak-20260609-195210` |
| Active strict soak state | running, ready `true`, fatal `0` |
| Active live/staged native DLL | `E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB` |
| Native build evidence | VS2019/v142 `14.29.30133`, `native-v142-build.json` exists |
| PHPStan | `0` on latest pending run |
| Tooling preflight | `ok=true`, checked `39` |
| Bedrock login/chunk swarm | `400/400`, chunk-ready `400/400`, disconnects `0`, loss `0%` |
| Remaining strict blocker | current 7200s soak must finish and write matching `soak.json` |
| Shell caveat | Resolved for current tooling; use bundled PMMP PHP, not global `php` |

## Lane status

| Lane | Status | Owner/session | Latest files touched | Latest validation | Merge readiness |
| --- | --- | --- | --- | --- | --- |
| A Network packet throughput | Implemented and fast-validated | Local integration | `StandardPacketBroadcaster`, `NetworkSession`, `PacketBatch`, native packet helpers | PHPStan `0`, fast gates, staged/live native tests | Done for fast-release; expand only after real traffic data |
| B World/chunk/entity density | Implemented and fast-validated | Local integration | `World`, `Entity`, collision/entity iteration, save loops | PHPStan `0`, fast gates | Done for fast-release; tune caps after strict soak/real roaming |
| C Player/inventory/interaction | Implemented and fast-validated | Local integration | `Player`, `BaseInventory`, `SurvivalBlockBreakHandler`, `ItemEntity` | PHPStan `0`, fast gates | Done for fast-release; plugin/event-heavy scenarios still need real plugin tests |
| D Translation/serialization caches | Implemented and fast-validated | Local integration | `BlockTranslator`, `ChunkSerializer`, native mapped VarInt/palette paths | PHPStan `0`, native performance gate pass | Done for fast-release |
| E Tooling/gates/evidence | Implemented | Local integration | `tools/*.ps1`, `*.cmd`, evidence docs | Tooling preflight `39/39`, deployment status works | Done; maintain as gates evolve |
| F Native extension | Implemented, promoted, v142 evidence present | Local integration | `native/pmmp_perf_ext`, build/test/promote/status scripts | v142 build pass, functional test pass, staged gate pass, live SHA `E646...77BB` | Done for current native lane; `read_fast_paletted_array` remains experimental |
| G Plugin audit | Waiting for real production plugins | Unassigned | `tools/audit-plugin-hotpaths.ps1`, production plugin marker | No real production plugins in `main_pmmp/plugins`; explicit no-plugin evidence exists | Not started for plugin servers; complete only for vanilla/no-plugin deployment |

## Done criteria per lane

### Lane A

- Packet/batch hotpath patch is applied.
- Bench fixture covers the changed path.
- Modified PHP files are in `tools/run-fast-gates.ps1`.
- `continue-fast-progress.ps1` passes or warning is explained.

### Lane B

- No-array/direct-loop changes preserve public array-returning APIs.
- Save/unload/tick behavior is unchanged by review.
- Modified PHP files are in `tools/run-fast-gates.ps1`.
- `continue-fast-progress.ps1` passes or warning is explained.

### Lane C

- Event call order is unchanged.
- Cached local references do not cross plugin event mutation boundaries unsafely.
- Modified PHP files are in `tools/run-fast-gates.ps1`.
- `continue-fast-progress.ps1` passes or warning is explained.

### Lane D

- New caches only store pure/stable mapping results.
- Mutable runtime objects are not cached unless immutable by contract.
- Bench fixture shows the mapping path.
- `continue-fast-progress.ps1` passes or warning is explained.

### Lane E

- PowerShell scripts parse.
- Missing baseline and missing optional field cases are handled.
- JSON output remains machine-readable.
- `continue-fast-progress.ps1` completes end to end.

### Lane F

- PHP build environment matches bundled PHP.
- Native extension loads only when available.
- PHP fallback remains mandatory.
- Native benchmark beats PHP fallback before more native work is added.

### Lane G

- Real plugin files exist under `main_pmmp/plugins`.
- Audit identifies sync disk/db/network work in hot events.
- Fix list is ranked by tick impact.

## Merge decision record

Append one entry per merge:

```text
YYYY-MM-DD HH:mm KST
Lane:
Files:
Validation:
Decision:
Notes:
```

2026-06-07 KST
Lane: B/C
Files:
- `main_pmmp/src/entity/AttributeMap.php`
- `main_pmmp/src/entity/Entity.php`
- `main_pmmp/src/player/Player.php`
- `main_pmmp/src/inventory/BaseInventory.php`
- `main_pmmp/src/player/SurvivalBlockBreakHandler.php`
- `main_pmmp/src/entity/object/ItemEntity.php`
- `main_pmmp/tools/run-fast-gates.ps1`
Validation: pending; Codex managed Windows sandbox still fails with `windows sandbox: spawn setup refresh`.
Decision: local integration applied, hold final readiness until PHPStan/fast gate.
Notes: changes are direct-loop replacements preserving return shapes and public API.

2026-06-07 KST
Lane: C
Files:
- `main_pmmp/src/entity/object/ItemEntity.php`
Validation: pending; Codex managed Windows sandbox still fails with `windows sandbox: spawn setup refresh`.
Decision: local integration applied, hold final readiness until PHPStan/fast gate.
Notes: merge scan now only creates merge candidate array after at least one nearby mergeable item is found.

2026-06-09 KST
Lane: A/B/C/D/E/F
Files:
- `main_pmmp/src/**`
- `main_pmmp/native/pmmp_perf_ext/**`
- `main_pmmp/tools/**`
- root `pmmp-*.cmd`
Validation:
- Tooling preflight `ok=true`, checked `39`.
- Pending PHPStan `0`.
- Native v142 build `14.29.30133`.
- Live/staged DLL SHA256 `E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB`.
- Bedrock login/chunk swarm `400/400`, loss `0%`.
- Active strict soak `production-v142-strict-soak-20260609-195210`, ready `true`, fatal `0`.
Decision: fast-release complete; strict production release waits only for active 7200s soak pass evidence.
Notes: Lane G remains dependent on real production plugins. Vanilla/no-plugin evidence exists.

## Fast recovery command

When shell works:

```powershell
cd C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-tooling-preflight.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-pending-phpstan.ps1 -IncludeTooling
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\continue-fast-progress.ps1
```

From the repository root, the short path is:

```bat
pmmp-continue-fast-progress.cmd
```
