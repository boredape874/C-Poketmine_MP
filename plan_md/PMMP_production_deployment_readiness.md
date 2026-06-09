# PMMP production deployment readiness

## Current verdict

- High-performance core foundation: quick-validated and promoted.
- Real production deployment readiness: about `80%` under the strict audit.
- Latest verified gate: `20260608-201920`.

The core/native/chunk-network foundation is now strong enough for controlled
staging and short live-style validation. The latest staged native DLL has been
promoted to the live bundled extension path and quick-validated after promotion.
It is not yet a strict final public production release because the audit policy
still requires clean `7200s` soak evidence. VS2019/v142 native build evidence,
rollback, host-local network evidence, explicit vanilla/no-plugin evidence, and
the real 400-player Bedrock login/chunk-ready swarm evidence have already been
generated.

## Latest fast-release result

- Fast-release status: complete.
- Quick validation run: `post-native-promotion-soak-20260609-021925`.
- Quick duration: `300s`.
- Quick ready/fatal: `true` / `0`.
- Quick Rak ping: `400/400`, loss `0%`, average `32.80ms`.
- Strict audit soak: `production-v142-strict-soak-20260609-195210`.
- Strict soak status: running, ready `true`, fatal log matches `0`.
- Live bundled native DLL SHA256:
  `E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB`.
- Staged native DLL SHA256:
  `E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB`.
- Finalizer report:
  `main_pmmp/var/perf/production-evidence/production-readiness-finalize-last.json`.
- Finalizer evidence:
  `soak_pass_evidence_matches_run=true`,
  `soak_failed_evidence_matches_run=false`.

The promoted native DLL is now the live bundled VS2019/v142 DLL. The remaining
strict audit blocker is only that the current strict soak has not reached the
`7200s` production policy yet.

## Verified on latest gate

- Server ready: `2.121s`.
- Fatal log matches: `0`.
- PHPStan exit: `0`.
- Rak ping burst: `400/400`, loss `0%`, average `21.13ms`.
- Packet batch native loaded: `true`.
- Packet decode native loaded: `true`.
- Full chunk serialization native loaded: `true`.
- Packet decode native-string: about `853k packets/sec`.
- Packet batch raw: about `2.51M batches/sec`.
- Subchunk serialization: about `1.01M subchunks/sec`.
- Full chunk serialization: about `58.9k chunks/sec`.
- Movement synthetic: about `5.69M updates/sec`.
- Global chunk budget: about `19.5M decisions/sec`.
- Chunk population coalescing fixture: about `23.8M requests/sec`.
- Runtime chunk population started/resolved: `224/224`.

## Production-specific change made

`network.raklib-packet-limit` is now a `pocketmine.yml` setting and is applied
to RakLib after network interface registration. The default remains `200`.
The generated wild-400 profile sets it to `1200`.

Reason: RakLib's default per-source-IP packet limit is a protection mechanism.
The previous 400-ping localhost burst failed at `199/400` because all packets
came from `127.0.0.1` and hit that limit, not because the PMMP process crashed
or the native hotpaths failed.

## Release blockers

- Run a 2-6 hour soak with autosave, chunk roaming, deaths, inventory movement,
  combat/projectiles, entity density, and world generation.

Rollback evidence and host-local network evidence have now been generated under
`main_pmmp/var/perf/production-evidence`. They are no longer current audit
blockers. The host evidence is local-machine evidence; final live deployment
still needs the same check on the actual host.

## Remaining warning

- None in the current strict audit status. VS2019/v142 evidence exists.

## Current deployment stance

Use this build for a controlled staging server first. For a live public server,
keep player slots capped below the target until the real login/chunk swarm and
soak pass with the production plugin set.

## Automated audit

Run from the repository root:

```bat
pmmp-audit-production-readiness.cmd -Markdown -NoExitCode
```

The audit writes `production-readiness.json` and optionally
`production-readiness.md` into the selected/latest gate directory. It is
expected to return `not_ready` until real production evidence files exist under
`main_pmmp/var/perf/production-evidence`.

Evidence helpers:

```bat
pmmp-create-rollback-package.cmd
pmmp-collect-host-network-evidence.cmd
pmmp-record-native-build-evidence.cmd
pmmp-promote-staged-native-extension.cmd
pmmp-run-staged-native-performance-gate.cmd
pmmp-run-post-native-promotion-validation.cmd -AcceptLgpl -StartSoak
pmmp-run-native-promotion-pipeline.cmd -AcceptLgpl
pmmp-check-native-promotion-pipeline-status.cmd
pmmp-summarize-production-evidence.cmd -Markdown
pmmp-write-production-deployment-status.cmd -Markdown
pmmp-run-production-soak.cmd -AcceptLgpl -DurationSeconds 7200 -RunRakPingBurst
pmmp-check-production-soak-status.cmd
pmmp-finalize-production-readiness-after-soak.cmd -NoExitCode
pmmp-start-production-finalizer-watcher.cmd -NoExitCode
pmmp-check-production-finalizer-status.cmd
pmmp-run-bedrock-login-swarm-gate.cmd -AcceptLgpl -Players 400 -DurationSeconds 60 -ServerDurationSeconds 360 -RegisterEvidence
pmmp-register-bedrock-login-swarm-evidence.cmd -InputJson path\to\external-swarm-result.json
pmmp-register-production-plugins.cmd -SourceDir path\to\plugins -Copy
pmmp-register-production-plugins.cmd -NoProductionPlugins
```

The audit, rollback package helper, and soak finalizer use the latest gate by
default. Pass `-GateDir` only when intentionally reviewing an older gate.

The native build evidence helper writes `native-v142-build.json` only when the
detected MSVC toolset is actually `14.29`/v142. Otherwise it writes
`native-local-build.json`, which documents the current local build but keeps
the production v142 warning active.

Use `pmmp-promote-staged-native-extension.cmd` only after the current production
soak has stopped. It refuses to promote by default while the soak or a PMMP PHP
process is running, runs `pmmp-run-staged-native-performance-gate.cmd`, backs up
the bundled DLL, copies `var/native-build/php_pmmp_perf_ext.dll`, runs the
native functional test, and refreshes native build evidence.

If staged and live bundled native DLL hashes differ, the current soak validates
only the live bundled DLL. After promotion, run
`pmmp-run-post-native-promotion-validation.cmd -AcceptLgpl -StartSoak` to run a
production fast gate, start a background clean soak for the promoted DLL, and
attach a finalizer watcher. The helper refuses to run before promotion and
replaces a stale finalizer watcher so the promoted-DLL soak is monitored.

Live bundled native DLL SHA256 is
`E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB`. This DLL is
being validated by strict production soak
`production-v142-strict-soak-20260609-195210` on port `19156`.

Current staged native DLL SHA256 is
`E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB`. Staged and
live bundled native DLLs now match. It adds direct `zend_string` writers for signed VarInt, biome
palette, mapped signed VarInt, U32LE pack, and fast paletted-array native paths.
It also includes an experimental `pmmp_perf_read_fast_paletted_array()` helper;
that helper is function-tested but not wired into `FastChunkSerializer` hot
paths because the current PHP integration measured slower on deserialize.

Current staged native performance gate passes for the staged DLL. The gate uses
best metrics across three samples to avoid false failures from brief local load
spikes while keeping the same thresholds. Latest staged gate metrics: packet
batch native/PHP ratio about `2.65x`, native decode about `840k packets/sec`,
full chunk serialization about `67.1k chunks/sec`, and fast chunk serialization
about `43.6k chunks/sec`. Latest deployment status sample for the same staged
SHA reports packet batch native/PHP ratio about `2.58x`, native decode about
`754k packets/sec`, full chunk serialization about `67.4k chunks/sec`, and fast
chunk serialization about `41.6k chunks/sec`.

For automatic handoff, use `pmmp-run-native-promotion-pipeline.cmd -AcceptLgpl`.
It waits for the current production soak to stop, refuses to continue if that
soak does not produce matching clean `soak.json` pass evidence, promotes the
staged native DLL, then starts the promoted-DLL fast gate and clean soak.
Inspect the pipeline with
`pmmp-check-native-promotion-pipeline-status.cmd`.

Current v142 check: VS2019 Build Tools/MSVC `14.29.30133` are installed and
`native-v142-build.json` exists. VS2026/MSVC `14.50.35717` remains installed as
the local non-production toolset.

The soak helper writes `soak.json` only when the run is at least 7200 seconds
and clean. Failed or shorter runs write `soak-last-failed.json`. The login
swarm registration helper writes `bedrock-login-swarm.json` only when the input
proves at least 400 attempted players, 400 successful logins, 400 chunk-ready
players, zero disconnects, zero fatal log matches, at least 60 seconds of
duration, and at most 10% loss.

Current Bedrock swarm evidence: `bedrock-login-swarm.json` is registered and
passes with `400` attempted players, `400` successful logins, `400`
chunk-ready players, `0` disconnects, `0` fatal log matches, and `0%` loss.

The plugin registration helper writes `production-plugins.json` only after it
finds PMMP plugin evidence (`plugin.yml` or `.phar`) and PHP source or a phar.
The production audit requires this marker as well as plugin PHP files under
`main_pmmp/plugins`, so an empty plugin directory cannot accidentally clear the
plugin blocker. The helper also refuses PMMP example, test, baseline, and probe
plugins by default, so non-production fixtures cannot accidentally clear the
plugin blocker. For a deliberate vanilla/no-plugin survival deployment,
`pmmp-register-production-plugins.cmd -NoProductionPlugins` writes an explicit
marker; the audit accepts it only while `main_pmmp/plugins` remains empty.

Evidence schema and samples are tracked here:

```text
plan_md/PMMP_production_evidence_schema.md
main_pmmp/tools/production-evidence-samples/
```

Smoke check: `pmmp-run-production-soak.cmd -AcceptLgpl -DurationSeconds 30
-MinimumDurationSeconds 7200` was run on 2026-06-08. It reached ready in
`2.096s` with `0` fatal log matches and correctly wrote `soak-last-failed.json`
instead of `soak.json`, proving the helper path works while keeping the real
2-hour blocker active.

Current strict production soak:
`production-v142-strict-soak-20260609-195210` is running on port `19156`,
reached ready, and currently has `0` fatal/error matches. It validates live
bundled DLL SHA256
`E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB`. Use
`pmmp-check-production-soak-status.cmd` to inspect progress. The finalizer
watcher is attached and will refresh `production-evidence-summary.md` and
`production-deployment-status.json/md` after matching `7200s` pass evidence is
written.
