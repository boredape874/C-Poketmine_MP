# PMMP hybrid multithreading completion estimate

Updated: 2026-06-09 KST

## Measured baseline

Production status:

- Deployment status: `ready`.
- Readiness: `90`.
- Blockers: `0`.
- Warnings: `0`.
- Strict soak: `production-v142-strict-soak-20260609-195210`, `100%`, fatal `0`, pass evidence matches run.
- Native DLL SHA256: `E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB`.

Native microbench:

| Metric | Measured |
|---|---:|
| VarInt prefix native | `36.13M calls/sec` |
| VarInt prefix PHP | `25.18M calls/sec` |
| packet batch encode native | `17.05M batches/sec` |
| packet batch encode with lengths | `15.53M batches/sec` |
| packet single encode | `23.67M batches/sec` |
| mapped signed VarInt native | `11.27M batches/sec` |
| mapped signed VarInt PHP-map path | `4.32M batches/sec` |
| biome palette encode | `15.28M batches/sec` |
| u32le pack native | `23.73M batches/sec` |
| u32le pack PHP | `8.11M batches/sec` |
| u32le unpack native | `11.17M batches/sec` |
| u32le unpack PHP | `3.57M batches/sec` |
| fast paletted array native | `16.68M batches/sec` |
| fast paletted array PHP | `3.94M batches/sec` |
| packet batch decode native | `9.53M batches/sec` |
| decoded packets | `38.12M packets/sec` |

Hotpath bench:

| Metric | Measured |
|---|---:|
| packet batch raw native | `2.88M batches/sec` |
| packet batch raw PHP reference | `1.11M batches/sec` |
| packet encode | `595.75k packets/sec` |
| packet decode | `853.09k packets/sec` |
| full chunk serialization | `74.40k chunks/sec` |
| subchunk serialization | `1.54M subchunks/sec` |
| FastChunk serialize | `47.89k chunks/sec` |
| FastChunk deserialize | `40.50k chunks/sec` |
| compression mixed batches | `146.12k batches/sec` |
| movement process synthetic | `6.10M updates/sec` |
| nearby entity iteration callback | `21.86M entities/sec` |
| chunk population coalescing | `23.92M requests/sec` |

## What the measurement means

The current code already has:

- AsyncPool worker infrastructure.
- Async compression path.
- Async chunk request/serialization task.
- Native packet/chunk primitive helpers.
- 400-player login/chunk evidence.

The missing final form is not raw native speed. The missing work is architecture:

- hotspot movement/fanout scenario,
- duplicate packet serialization counters,
- worker queues for immutable packet/chunk snapshots,
- dirty-set coalescing for same-area player/entity/UI updates,
- plugin async I/O containment,
- optional region actors for separated areas.

## Completion estimate

| Target | Remaining work | Estimate with AI-assisted implementation | Confidence |
|---|---|---:|---:|
| Current deployable high-performance core | Final docs/status only | done | High |
| 400-player same-area hotspot benchmark + counters | Add scenario, probes, reports | `8-16h` | Medium-high |
| Hotspot fanout/dirty-set worker lane | Packet fanout counters, duplicate suppression, dirty UI/entity queues | `2-4 days` | Medium |
| Chunk snapshot worker expansion | Immutable snapshot boundaries, queue policy, validation | `2-5 days` | Medium |
| Plugin-safe async I/O lane | Scan real plugins, wrappers, queue examples, validation | `1-5 days` after real plugins exist | Low-medium without plugins |
| Region actor experiment | Isolated area/world actor, message boundary, no plugin object sharing | `2-4 weeks` for experimental lane | Medium-low |
| Region actor production compatibility | plugin behavior, event order, cross-boundary entities, rollback tests | `4-8+ weeks` | Low |
| Hybrid max-threading production profile | hotspot workers + limited region actors + plugin compatibility | `3-6 weeks` minimum | Medium-low |

## Most realistic calendar

Fastest useful path:

1. `1 day`: hotspot benchmark and instrumentation.
2. `2-4 days`: fanout/dirty-set worker optimizations.
3. `2-5 days`: chunk snapshot worker expansion and validation.
4. `1-5 days`: real plugin audit and async I/O fixes, once plugins are available.

That makes the near-term 400-player crowded-area upgrade about `5-15 days`.

Hybrid region actor plus hotspot workers is a different scale: `3-6 weeks` minimum for a serious experimental/production candidate, and longer if existing plugins rely heavily on direct world/entity internals.

## Why AI does not make it instant

AI can write code quickly, but the hard part is correctness evidence:

- PMMP plugin event order must not change unexpectedly.
- World/entity/inventory mutation must remain authoritative.
- Workers cannot touch live PMMP objects.
- Packet order and compression behavior must stay protocol-correct.
- 400-player hotspot proof needs a real scenario, not only login/chunk-ready evidence.

The validation wall-clock time is real even if code generation is fast.
