# PMMP plan_md final audit

Updated: 2026-06-09 KST

## Scope

Reviewed `plan_md` for stale status, broken Korean encoding, missing final blockers, native-extension state, plugin-audit state, and production-readiness consistency.

## Corrected documents

- `PMMP_lane_status_board.md`: updated to current fast-release and strict-soak state.
- `PMMP_native_extension_lane.md`: replaced broken/old native lane with current v142 production DLL status.
- Current-state summary MD: replaced broken/old state summary with current implementation status and real remaining blockers.
- Plugin performance audit checklist MD: replaced broken checklist with current PMMP plugin audit rules.
- `PMMP_latest_progress_2026-06-07.md`: added authoritative current-status header above the historical log.
- `PMMP_production_evidence_schema.md`: added current evidence status above historical examples.
- `README_PMMP_FAST.md`: changed the native build note from old VS2026-local wording to current VS2019/v142 production DLL wording.

## Current release state

- Fast-release: complete.
- Strict production: not final until the active `7200s` soak completes.
- Active strict soak: `production-v142-strict-soak-20260609-195210`.
- Production native DLL SHA256: `E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB`.
- 400-player Bedrock login/chunk evidence: passed.
- Plugin state: explicit vanilla/no-production-plugin evidence only; real plugin packs still require audit.

## Latest validation

- Soak status check: running `true`, ready `true`, progress `79%`, remaining about `1488s`, fatal log matches `0`.
- Deployment status: `waiting_for_soak`, readiness `80`, blockers `1`, warnings `0`, high-performance core ready `true`.
- Native live/staged hash match: `true`.
- Tooling preflight: `ok=true`, checked `39`, failed `0`.
- Later production status recheck: `ready`, readiness `90`, blockers `0`, warnings `0`, strict soak `100%`, fatal `0`, pass evidence matches run.
- Hybrid max-threading estimate recorded in `PMMP_hybrid_multithreading_completion_estimate_2026-06-09.md`.

## Remaining weak areas

1. Strict production evidence still depends on the active soak finishing cleanly.
2. Real wild-server behavior needs longer validation with actual map, movement, combat, entities, inventory traffic, and production plugins.
3. Chunk loading caps and pregen/view-distance defaults need tuning from real telemetry.
4. `pmmp_perf_read_fast_paletted_array()` exists but should stay out of the live deserialize path until it beats the current PHP path.
5. A 400-player single-area hotspot needs a separate crowded-area multithreading lane focused on packet fanout, compression, chunk snapshots, dirty sets, plugin I/O isolation, and native binary helpers.
6. Long-term maximum performance should combine region actors with hotspot fanout workers, while keeping PMMP plugin callbacks and authoritative object mutation on the main thread.

## Final acceptance rule

Do not call the strict production release fully complete until the active strict soak produces matching clean `soak.json` evidence and the final readiness audit reports no blockers.
