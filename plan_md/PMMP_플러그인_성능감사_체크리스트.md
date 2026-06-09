# PMMP 플러그인 성능감사 체크리스트

Updated: 2026-06-09 KST

## Current status

The current production evidence is an explicit vanilla/no-production-plugin deployment. That clears the plugin blocker only while `main_pmmp/plugins` stays empty. When real plugins are added, this checklist becomes mandatory before claiming production readiness for that server pack.

## Critical patterns

| Risk | Search target | Required fix |
|---|---|---|
| Global player loops | `getOnlinePlayers()`, repeated `foreach` over all players | Narrow by world, area, team, subscription, or dirty set |
| Tick-time blocking I/O | `file_get_contents`, `file_put_contents`, `curl_exec`, `mysqli`, `PDO` | Move to async worker/process or batched write-behind queue |
| Packet event abuse | `DataPacketReceiveEvent`, `DataPacketSendEvent` | Filter packet IDs early or replace with higher-level PMMP events |
| Per-tick UI spam | `sendActionBarMessage`, `sendTip`, scoreboard/form refresh | Send only when value changes and cap update frequency |
| Forced chunk load | `loadChunk`, synchronous `getChunk` assumptions | Preload, cache, or defer; never scan wide areas on the main tick |
| Repeated parsing | `json_decode`, NBT read/write in event paths | Cache parsed data and invalidate on change |
| Large array copies | `array_merge`, `array_values`, `array_filter` in hot paths | Use keyed lookup or direct loops |
| Strong player refs | long-lived `Player` object arrays/properties | Store UUID/name/runtime ID and clean up on quit |

## Fast scan

```powershell
rg -n "getOnlinePlayers|DataPacketReceiveEvent|DataPacketSendEvent|file_get_contents|file_put_contents|curl_exec|mysqli|PDO|save\\(|sendActionBar|sendTip|sendPopup|loadChunk|getChunk|json_decode|array_merge|array_values|array_filter" .\main_pmmp\plugins -g "*.php"
```

## Production acceptance

- No main-thread file, DB, or network I/O in frequent events or scheduler tasks.
- No unbounded all-player, all-world, all-chunk, or all-entity scans.
- No packet-level event hooks unless they are narrowly filtered and measured.
- No per-tick scoreboard/actionbar/form refresh unless values changed.
- Plugin PHPStan or equivalent static validation passes for modified plugin files.
- Plugin load/join smoke test passes with the same PMMP build and native DLL used for production evidence.

## Audit result template

```text
File:
Risk:
Severity:
Evidence:
Runtime impact:
Fix:
Validation:
```
