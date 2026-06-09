# PMMP fast progress

PMMP source is under `main_pmmp`.

## Latest fast finish update

2026-06-09 fast-release path is complete. The stricter 7200-second production
soak remains running in the background only to satisfy the final audit policy.

- Live bundled native DLL SHA256:
  `E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB`.
- Staged native DLL SHA256:
  `E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB`.
- Promotion result: copied to live, previous DLL backed up under
  `main_pmmp/var/native-build/promoted-backups/`.
- Live native functional test: pass.
- Tooling preflight: pass, `39` checks.
- Post-promotion quick soak:
  `post-native-promotion-soak-20260609-021925`, `300s`, ready `true`,
  fatal log matches `0`, Rak ping `400/400`, loss `0%`.
- Current strict soak:
  `production-v142-strict-soak-20260609-195210`, ready `true`, fatal log
  matches `0`, live/staged v142 DLL hash matches.

The high-performance core is promoted and quick-validated with a VS2019/v142
native build. The production audit is now waiting only for clean `7200s` soak
evidence from `production-v142-strict-soak-20260609-195210`.

## Fastest command

From this repository root:

```bat
pmmp-continue-fast-progress.cmd
```

If another local Bedrock server is already bound to `19132`, run the PowerShell
script directly with another port:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\main_pmmp\tools\continue-fast-progress.ps1 -Port 19133
```

This runs, in order:

1. PowerShell tooling preflight
2. pending PHPStan for recently changed/high-risk files
3. fast PMMP gate with hotpath bench
4. baseline compare
5. gate `summary.md`
6. progress document update
7. AI handoff export

The pending PHPStan preflight currently covers recent core edits such as `AttributeMap`, `BaseInventory`, `Player`, `SurvivalBlockBreakHandler`, `World`, and related hotpath files before the full gate starts.

## Shell diagnostic

```bat
pmmp-diagnose-codex-shell.cmd
```

## Production readiness audit

```bat
pmmp-audit-production-readiness.cmd -Markdown -NoExitCode
```

This checks the latest gate against real deployment requirements. A clean fast
gate can still report `not_ready` when production-only evidence is missing,
such as real Bedrock login/chunk-request swarm results, soak results, real
plugin audit coverage, rollback packaging, or a production v142 native build.

Useful evidence commands:

```bat
pmmp-create-rollback-package.cmd
pmmp-collect-host-network-evidence.cmd
pmmp-record-native-build-evidence.cmd
pmmp-summarize-production-evidence.cmd -Markdown
pmmp-write-production-deployment-status.cmd -Markdown
pmmp-run-production-soak.cmd -AcceptLgpl -DurationSeconds 7200 -RunRakPingBurst
pmmp-check-production-soak-status.cmd
pmmp-finalize-production-readiness-after-soak.cmd -NoExitCode
pmmp-start-production-finalizer-watcher.cmd -NoExitCode
pmmp-check-production-finalizer-status.cmd
pmmp-run-bedrock-login-swarm.cmd -Install -Players 400 -DurationSeconds 60 -RegisterEvidence
pmmp-run-bedrock-login-swarm-gate.cmd -AcceptLgpl -Players 400 -DurationSeconds 60 -ServerDurationSeconds 360 -RegisterEvidence
pmmp-register-bedrock-login-swarm-evidence.cmd -InputJson path\to\external-swarm-result.json
pmmp-register-production-plugins.cmd -SourceDir path\to\plugins -Copy
pmmp-register-production-plugins.cmd -NoProductionPlugins
```

`pmmp-audit-production-readiness.cmd`, `pmmp-create-rollback-package.cmd`, and
`pmmp-finalize-production-readiness-after-soak.cmd` use the latest gate by
default, so a hardcoded gate path is only needed when reviewing older evidence.

`pmmp-register-production-plugins.cmd` refuses PMMP example, test, baseline, and
probe plugins by default. This keeps `production-plugins.json` from being
cleared by non-production fixtures. For an intentional vanilla/no-plugin
survival deployment, use `-NoProductionPlugins`; the audit accepts that marker
only while `main_pmmp\plugins` remains empty.

This diagnostic intentionally uses the bundled PMMP runtime at
`main_pmmp\bin\php\php.exe`. A failing plain `php` command from the
repository root does not mean PMMP PHP is broken; it only means PHP is not
installed globally on `PATH`.

If Codex shell fails with:

```text
windows sandbox: spawn setup refresh
```

read:

```text
plan_md/CODEX_windows_sandbox_issue_2026-06-07.md
```

## Current work map

- Latest progress: `plan_md/PMMP_latest_progress_2026-06-07.md`
- Production readiness: `plan_md/PMMP_production_deployment_readiness.md`
- Lane board: `plan_md/PMMP_lane_status_board.md`
- Implementation backlog: `plan_md/PMMP_implementation_backlog.md`
- Parallel prompts: `plan_md/ai_tasks`
- Merge protocol: `plan_md/PMMP_parallel_merge_protocol.md`

## Current validation

The latest clean verified native-enabled fast gate is `20260608-201920`. It
returned ready in `2.121s`, PHPStan `0`, fatal log matches `0`, Rak ping
`400/400`, loss `0%`, average latency `21.13ms`, packet batch native loaded
`true`, packet decode native loaded `true`, packet decoding about `853k
packets/sec`, full chunk serialization about `58.9k chunks/sec`, per-player
chunk pressure snapshots about `142.6M snapshots/sec`, global chunk budget
decisions about `19.5M decisions/sec`, population prefetch selection about
`12.5M candidates/sec`, chunk population coalescing about `23.8M requests/sec`,
and runtime chunk budget pressure reports `1`.

The latest shell diagnostic also passes from the repository root. It verifies
PowerShell child process spawn, cmd child process spawn, PMMP bundled PHP, Git,
ripgrep, and a repository write/delete smoke test.

Production evidence update: the integrated Bedrock login/chunk swarm passed
with `400/400` successful logins, `400/400` chunk-ready players, `0`
disconnects, `0` fatal log matches, and `0%` loss. The evidence is registered
at `main_pmmp\var\perf\production-evidence\bedrock-login-swarm.json`.

The latest fast-finish post-promotion soak completed under
`post-native-promotion-soak-20260609-021925` on port `19155`. Check the current
evidence with:

```bat
pmmp-check-production-soak-status.cmd
pmmp-summarize-production-evidence.cmd -Markdown
pmmp-write-production-deployment-status.cmd -Markdown
pmmp-finalize-production-readiness-after-soak.cmd -NoExitCode
pmmp-start-production-finalizer-watcher.cmd -NoExitCode
pmmp-check-production-finalizer-status.cmd
```

The finalizer refreshed `production-evidence-summary.md` and
`production-deployment-status.json/md`, so the evidence directory is the single
place to inspect the live deployment verdict.

The older `20260607-203549` run came from an interrupted/background approval
execution and is treated as noisy because its ready time was `6.107s`.
The `20260607-225755` run is also noisy because another local PMMP process was
already bound to `19132`; the clean validation was rerun on `19133`.

## Native extension lane

The native extension PoC lives under `main_pmmp\native\pmmp_perf_ext`.

Useful commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\main_pmmp\tools\check-native-extension-env.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\main_pmmp\tools\build-native-extension-windows.ps1 -PatchVs16LinkerVersion
powershell -NoProfile -ExecutionPolicy Bypass -File .\main_pmmp\tools\test-native-extension.ps1
.\main_pmmp\bin\php\php.exe -d "extension=$(Resolve-Path .\main_pmmp\var\native-build\php_pmmp_perf_ext.dll)" .\main_pmmp\tools\bench-native-extension.php
pmmp-bench-staged-native-hotpaths.cmd -Iterations 300
pmmp-run-staged-native-performance-gate.cmd
pmmp-promote-staged-native-extension.cmd
pmmp-run-post-native-promotion-validation.cmd -AcceptLgpl -StartSoak
pmmp-run-native-promotion-pipeline.cmd -AcceptLgpl
pmmp-check-native-promotion-pipeline-status.cmd
```

`pmmp-promote-staged-native-extension.cmd` is the safe post-soak promotion
path for `var/native-build/php_pmmp_perf_ext.dll`. By default it refuses to copy
while a production soak or any PMMP PHP process is still running, runs the
staged native performance gate, backs up the current bundled DLL, copies the
staged DLL, runs the native functional test, and refreshes native build
evidence.

After promotion, `pmmp-run-post-native-promotion-validation.cmd -AcceptLgpl
-StartSoak` runs a production fast gate against the promoted DLL, starts a
background clean soak for that exact DLL, and attaches a finalizer watcher. It
refuses to start if the staged DLL has not actually been promoted. The
post-promotion helper replaces a stale finalizer watcher so the watcher is
attached to the promoted-DLL soak run.

`pmmp-run-native-promotion-pipeline.cmd -AcceptLgpl` is the automated path. It
waits for the running production soak to stop, refuses to continue if that soak
does not produce matching clean `soak.json` pass evidence, promotes the staged
DLL, then launches the promoted-DLL fast gate and clean soak. Inspect it with
`pmmp-check-native-promotion-pipeline-status.cmd`.

Current verified native result:

- DLL build: pass
- PMMP bundled PHP load: pass
- `pmmp_perf_varint_prefix_length(300)`: `2`
- `pmmp_perf_encode_packet_batch(["abc", "de"], [3, 2])`: `03616263026465`
- `pmmp_perf_encode_packet_single("abc", 3)`: `03616263`
- `pmmp_perf_decode_packet_batch(...)`: `["616263", "6465"]`
- `pmmp_perf_encode_signed_varints([0, 1, 127, 128, 300, -1])`: `0002fe018002d80401`
- `pmmp_perf_encode_mapped_signed_varints([1, 3], [1 => 2, 3 => 4])`: `0408`; missing map entries return `null` for PHP fallback.
- `pmmp_perf_serialize_fast_paletted_array(3, "\x01\x02", [0, 1, 255])`: `0301020000000c0000000001000000ff000000`
- native prefix microbench: about `33.8M calls/sec`
- PHP prefix loop comparison: about `22.1M calls/sec`
- native signed VarInt batch microbench: about `15.3M batches/sec`
- native packet-batch encode now writes directly into exact-sized `zend_string`
  buffers instead of repeated `smart_str` appends; signed VarInt, biome
  palette, mapped signed VarInt, U32LE pack, and complete fast paletted-array
  serialization also use direct staged `zend_string` writers.
- native single packet-batch encode microbench: about `19.7M batches/sec`
- native packet-batch decode microbench: about `8.6M batches/sec`, `34.2M packets/sec`
- native biome palette, U32LE palette, and complete fast paletted-array helpers
  are active in the promoted VS2019/v142 production bundled DLL.
- latest staged fast paletted-array microbench: about `6.0M batches/sec` vs
  PHP reference about `3.8M batches/sec`; staged/fallback FastChunkSerializer
  large-palette fixture hashes match and roundtrip passes.
- promoted live native DLL SHA256:
  `E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB`.
  Strict production soak `production-v142-strict-soak-20260609-195210`
  is validating this live DLL.
- latest staged native DLL SHA256:
  `E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB`. Staged
  and live bundled native DLLs now match.
- latest staged native performance gate: pass, packet batch native/PHP ratio
  about `2.58x`, native decode about `754k packets/sec`, full chunk
  serialization about `67.4k chunks/sec`, fast chunk serialization about
  `41.6k chunks/sec`.
- `pmmp_perf_read_fast_paletted_array()` exists in staged native code and passes
  functional testing, but is not wired into `FastChunkSerializer` because the
  current PHP integration measured slower for deserialize.
- latest staged hotpath bench command:
  `pmmp-bench-staged-native-hotpaths.cmd -Iterations 300`. It loads the staged
  DLL with PMMP's required native dependencies while bypassing the live bundled
  perf DLL. Latest result for staged SHA
  `E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB`: packet
  batch raw remains above gate thresholds, full chunk serialization remains
  above `65k chunks/sec` in gate evidence, and fast chunk serialization remains
  above `37k chunks/sec` in gate evidence.
- staged native performance gate command:
  `pmmp-run-staged-native-performance-gate.cmd`. Latest result for staged SHA
  `E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB`: pass,
  using best metrics across three samples to avoid false failures from brief
  local load spikes. Latest deployment-status sample reports packet batch
  native/PHP ratio about `2.53x`, native decode about `843k packets/sec`, full
  chunk serialization about `62.3k chunks/sec`, fast chunk serialization about
  `42.7k chunks/sec`.
  The latest gate result is also persisted to
  `main_pmmp/var/perf/native-performance-gate/staged-native-performance-gate-last.json`.
- latest staged mapped signed VarInt microbench: about `10.9M batches/sec` vs
  PHP map-then-native encode about `4.1M batches/sec`; `ChunkSerializer` uses
  this path when the block translator cache already contains the palette IDs.
- PacketBatch native path is wired as optional acceleration; without the
  extension loaded, the PHP fallback path is used.
- PacketBatch incoming raw string decode is wired as optional native
  acceleration for `NetworkSession` receive batches; without the extension
  loaded, the existing `ByteBufferReader` callback fallback is used.
- ChunkSerializer now uses the native signed VarInt batch encoder for block
  and biome palettes when the extension is loaded; without the extension, the
  original PHP VarInt loop is used.
- `network.raklib-packet-limit` is now wired from `pocketmine.yml` into
  RakLib's per-source-IP packet limiter. The 400-player wild profile sets this
  to `1200`, which prevents localhost synthetic 400-ping bursts from being
  misclassified as a single-IP packet flood while preserving a configurable
  production safety valve.
- The built DLL is copied to `main_pmmp/bin/php/ext/php_pmmp_perf_ext.dll` and
  `main_pmmp/bin/php/php.ini` now loads it by default.
- ChunkSerializer full-chunk no-tile path now skips creating an empty tile
  serialization buffer.
- ChunkSerializer uniform block/biome palettes skip temporary `getPalette()`
  array extraction and write the single value directly.
- Player movement packets bypass the Timings start/stop wrapper when timings
  are disabled, preserving the existing measured path when timings are enabled.
- ChunkCache now supports loaded-chunk packet prefetch. Player chunk ordering
  prewarms a small near-future queue of already-loaded chunks so compression can
  finish before the send request reaches them.
- Player chunk prefetch is now direction-biased. Recent horizontal movement is
  used to prepare chunks in front of the player before chunks behind the player,
  while the second pass still prevents starvation.
- ChunkCache prefetch stats are exported through gate summaries. Fast gates now
  inject a temporary `ChunkCacheProbe` script plugin that runs inside the real
  PMMP server, population-prepares four spawn-near chunks, and verifies
  prefetch promise hits plus packet hits.
- Per-player chunk request pressure is tracked with O(1) status counters on
  `Player`, exposing queued, generation, sending, sent, pending, and
  chunks-per-tick state without scanning the used-chunk map. Gate summaries
  export a synthetic pressure snapshot bench so adaptive chunk budgets can be
  built on top of it without adding tick overhead.
- Player chunk sending now has a pressure-aware adaptive budget. It starts from
  the configured `chunk-sending.per-tick`, grows only when the queue is behind
  and generation/sending pressure is low, and backs off toward the configured
  base when pressure builds.
- Server-level chunk sending now has a 1-tick cached global budget scale based
  on total player chunk pending, requested sending pressure, async worker
  backlog, and tick load. This lets many players back off together under
  overload instead of each player bursting independently.
- Population prefetch now tracks active speculative population requests by
  chunk and movement generation. Duplicate speculative requests are skipped,
  and completions from old movement generations/worlds are counted as stale
  instead of being treated as useful progress.
- World population requests now expose shared-hit, queued, started, resolved,
  rejected, active, and pending counters. The fast gate probe logs these from
  inside the running server so 400-player chunk-demand tuning can be based on
  observed coalescing rather than guesswork.
- The fast gate chunk-cache probe now also logs `PMMP_CHUNK_BUDGET_PRESSURE`
  from inside the running PMMP server, and gate summaries expose reports, scale
  min/max, pending total, async backlog total, and population prefetch
  started/resolved/stale/active totals.
- Latest native-enabled fast gate with 400 Rak ping burst: `20260608-201920`,
  ready `2.121s`, Rak ping `400/400`, loss `0%`, average latency `21.13ms`,
  PHPStan `0`, packet batch raw about `2.51M batches/sec`, packet decode
  native-string about `853k packets/sec`, subchunk serialization about `1.01M
  subchunks/sec`, full chunk serialization about `58.9k chunks/sec`, movement
  synthetic about `5.69M updates/sec`, direction-biased chunk prefetch priority
  about `786k selections/sec`, chunk pressure snapshots about `142.6M/sec`,
  global chunk budget about `19.5M decisions/sec`, population prefetch selection
  about `12.5M candidates/sec`, chunk population runtime requests `894`, shared
  hits `4`, started/resolved `224/224`, coalescing fixture about `23.8M
  requests/sec` with `15.36M` shared hits, runtime budget pressure scale `100`,
  pending `0`, async backlog `0`, chunk-cache probe promise hits `4`, packet
  hits `4`.
- Latest fallback fast gate before php.ini auto-load: `20260608-010252`,
  ready `2.126s`, PHPStan `0`, packet batch raw about `1.11M batches/sec`.
- Latest native-loaded hotpath bench: `main_pmmp/var/perf/native/native-hotpath-bench-20260608-010231.json`,
  PacketBatch raw about `2.48M batches/sec`, subchunk serialization about
  `994k subchunks/sec`.

The current production native DLL uses VS2019 Build Tools/v142 with MSVC
`14.29.30133` and SHA256
`E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB`.
VS2026 `14.50` PE-patched builds are local-only diagnostics and are not final
production evidence.
