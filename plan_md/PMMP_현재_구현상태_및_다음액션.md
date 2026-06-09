# PMMP 현재 구현 상태 및 다음 액션

Updated: 2026-06-09 KST

## Current status

- Fast-release: complete.
- Strict production release: waiting for the active `7200s` soak to finish.
- Active strict soak: `production-v142-strict-soak-20260609-195210`.
- Native production DLL SHA256: `E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB`.
- Native compiler evidence: VS2019/v142 MSVC `14.29.30133`.
- 400-player Bedrock login/chunk swarm: passed with `400/400` successful logins, `400/400` chunk-ready players, disconnects `0`, fatal matches `0`.
- Tooling preflight: expected to be clean; re-run before final ship.

## Completed implementation

- Source tree and runtime layout are under `main_pmmp`.
- Fast gates, production readiness audit, deployment status writer, evidence summary, rollback package checks, finalizer watcher, and soak status tools exist.
- High-risk hotpaths were optimized in network packet batching, broadcast preparation, chunk selection, chunk serialization, runtime profiling, and inventory/player/world paths.
- Optional native extension is built, loaded, promoted, and fast-validated with a production v142 DLL.
- Bedrock login/chunk swarm gate reached the requested 400-player target in the controlled local evidence run.
- Explicit vanilla/no-production-plugin evidence exists for the current empty production plugin set.

## Real remaining blockers

1. Strict production audit still needs the currently running `7200s` soak to complete cleanly and produce matching `soak.json`.
2. Real plugin audit is only complete for the current vanilla/no-plugin deployment. If production plugins are added later, they must be scanned and load-tested.
3. Public 400-player wild survival confidence still needs a longer real-behavior run with actual maps, movement/combat/inventory traffic, entities, and server plugins.
4. Chunk loading caps and pregen/view-distance defaults should be tuned from real wild-server telemetry, not from synthetic login-only evidence.

## Current inspection commands

```powershell
pmmp-check-production-soak-status.cmd
pmmp-write-production-deployment-status.cmd -Markdown
pmmp-summarize-production-evidence.cmd -Markdown
pmmp-run-tooling-preflight.cmd -NoExitCode
```

## Next action

The correct next engineering action is not another large rewrite. Keep the strict soak running, verify it finishes cleanly, then run the final production readiness audit. In parallel, only add plugin-specific fixes if real production plugins are placed under `main_pmmp/plugins`.
