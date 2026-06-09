# PMMP hotspot 400-player multithreading strategy

Updated: 2026-06-09 KST

## Goal

Support a single crowded area with up to 400 players better than region-split designs. This is different from region actor scaling: all players are close together, so world ownership cannot be split by geography without heavy cross-region contention.

## Core principle

Do not try to run PMMP plugin/world mutation APIs from worker threads. Keep authoritative world state, event order, and plugin callbacks on the main thread. Move expensive pure or snapshot-based work away from the main tick.

## Best targets for crowded-area scaling

1. Packet fanout preparation
   - Build repeated payloads once.
   - Native encode packet batches.
   - Cache VarInt lengths and compressor IDs.
   - Avoid per-recipient duplicate serialization.

2. Compression and binary transforms
   - Keep compression native.
   - Batch packets before compression where protocol-safe.
   - Prefer C helpers for primitive buffer packing/unpacking.

3. Chunk and spawn-area payloads
   - Precompute crowded-area chunk payloads.
   - Share immutable chunk snapshots across players.
   - Push serialization to workers/native helpers where the snapshot is read-only.

4. Visibility and AOI fanout
   - Maintain player interest sets incrementally.
   - For 400 players in one area, avoid all-player scans every tick.
   - Use dirty sets for movement, metadata, equipment, scoreboard, bossbar, and actionbar updates.

5. Entity update coalescing
   - Merge duplicate metadata/movement/equipment broadcasts per tick.
   - Skip redundant packets when the viewer already has the same state.
   - Cap cosmetic/high-frequency updates before gameplay-critical updates.

6. Plugin slow-path containment
   - Main-thread plugin callbacks remain compatible.
   - Detect plugins doing global loops, sync I/O, packet event abuse, or per-tick UI spam.
   - Route heavy plugin I/O to async queues.

7. Native C/C++ lane
   - Keep adding C helpers only for pure binary hotpaths.
   - Priority: packet fanout encode, chunk section packing, paletted array serialization, VarInt maps, u32/u64 packing, repeated payload assembly.
   - Do not expose `Player`, `World`, `Entity`, or plugin objects to C.

## What multithreading can safely do

- Packet batch encoding from immutable inputs.
- Compression.
- Chunk serialization from immutable snapshots.
- Database/file/network I/O.
- Path/search/precompute jobs that return plain results.
- Metrics aggregation and log/evidence processing.

## What should stay on the main thread

- Plugin event calls.
- Player inventory mutation.
- Entity/world/block authoritative mutation.
- Command execution.
- Permission checks tied to live player/plugin state.
- Any API that can call back into plugins.

## Acceptance target

The crowded-area target is not just login success. A useful pass must include:

- 400 connected players in one spawn/combat area.
- Movement fanout.
- Chat/actionbar/scoreboard pressure.
- Inventory interaction.
- Entity metadata updates.
- Chunk resend/teleport burst.
- Fatal `0`, disconnect storm `0`, and tick p95 close to the configured budget.

## Implementation order

1. Add a crowded-area benchmark profile and bot scenario.
2. Add fanout counters for duplicate packet serialization and per-tick viewer scans.
3. Extend native packet/fanout helpers.
4. Add immutable chunk/packet snapshot queues.
5. Add dirty-set based player/entity/UI update coalescing.
6. Audit real plugins and move plugin I/O off the main thread.
7. Tune caps from actual hotspot telemetry.

## Difference from region actor

Region actor helps when players are spread across many areas. It does not solve a 400-player pileup by itself because all hot interactions happen in one region. For this target, the winning strategy is main-thread mutation minimalism plus worker/native fanout, serialization, compression, and I/O.

## Hybrid max-threading model

The best long-term design is not hotspot fanout or region actors alone. Use both, but with different ownership rules:

- Region actors handle separated worlds, dimensions, far-away wild areas, pregen areas, and isolated minigame arenas.
- Hotspot fanout workers handle crowded same-area packet, chunk, compression, visibility, and UI pressure.
- The main thread remains the compatibility boundary for PMMP plugins and authoritative mutations.

This gives more CPU usage without forcing every existing PMMP plugin to become thread-safe.

## Compatibility boundary

Existing PMMP plugins expect live objects to be synchronous and mutable:

- `Player`
- `World`
- `Entity`
- `Block`
- `Inventory`
- event objects

Those objects should not be handed to worker threads or native code. Workers receive immutable snapshots, scalar IDs, binary payloads, or serialized job inputs. Workers return plain results, and the main thread applies the final mutation in PMMP order.

## Threading lanes

| Lane | Threaded? | Plugin compatibility risk | Notes |
|---|---:|---:|---|
| Packet batch encode | Yes | Low | Pure binary input/output |
| Compression | Yes | Low | Already native-friendly |
| Chunk serialization from snapshot | Yes | Low-medium | Snapshot must be immutable |
| Chunk generation/pregen | Yes | Medium | Main thread applies final load state |
| Visibility/AOI calculation | Yes | Medium | Workers calculate candidates; main thread validates |
| Entity AI/path precompute | Partial | Medium-high | No direct entity mutation off-thread |
| DB/file/plugin storage I/O | Yes | Low-medium | Plugin code needs async queue wrapper |
| Plugin event execution | No | High | Keep on main thread |
| Inventory/world/entity mutation | No | High | Keep on main thread |

## Target architecture

```text
Main PMMP thread
  - plugin API compatibility
  - event order
  - authoritative mutation
  - final packet send scheduling

Worker pools
  - packet/fanout encode jobs
  - compression jobs
  - chunk snapshot serialization
  - AOI candidate calculation
  - plugin storage queues
  - metrics and evidence aggregation

C/C++ native extension
  - VarInt and binary packing
  - packet batch assembly
  - paletted array serialization
  - repeated chunk buffer transforms
  - CPU-heavy pure data transforms
```

## Practical rule

If a task can be represented as immutable input to immutable output, it is a threading/native candidate. If it can call a plugin, mutate PMMP objects, or depend on live object identity, it stays on the main thread behind a queue or snapshot boundary.
