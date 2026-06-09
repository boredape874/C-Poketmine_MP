# pmmp_perf_ext

Native C extension for PMMP hot path experiments.

## Scope

This extension is wired into selected PMMP hot paths only when the bundled PHP runtime loads it. PHP fallbacks remain in place for compatibility.

Initial functions:

- `pmmp_perf_varint_prefix_length(int $length): int`
- `pmmp_perf_build_info(): array`
- `pmmp_perf_encode_packet_batch(array $packets, ?array $lengths = null): string`
- `pmmp_perf_encode_packet_single(string $packet, int $length): string`
- `pmmp_perf_decode_packet_batch(string $batch): array`
- `pmmp_perf_decode_packet_batch_callback(string $batch, callable $callback): int`
- `pmmp_perf_encode_signed_varints(array $values): string`
- `pmmp_perf_encode_biome_palette(array $values, array $knownBiomeIds, int $fallbackBiomeId): string`
- `pmmp_perf_encode_mapped_signed_varints(array $values, array $map): ?string`
- `pmmp_perf_pack_u32le(array $values): string`
- `pmmp_perf_unpack_u32le(string $data): array`
- `pmmp_perf_serialize_fast_paletted_array(int $bitsPerBlock, string $wordArray, array $palette): string`
- `pmmp_perf_read_fast_paletted_array(string $data, int $offset): array`

`pmmp_perf_decode_packet_batch_callback()` is currently experimental. The benchmark shows PHP callback invocation from C is slower than returning the native decoded array for the current packet-batch fixture, so PMMP core keeps using `pmmp_perf_decode_packet_batch()` by default.

`pmmp_perf_encode_packet_single()` accelerates the frequent single-packet batch flush path by encoding the unsigned length VarInt and packet bytes in one native allocation. `PacketBatch::encodeRawSingle()` uses it when loaded and keeps the original PHP VarInt fallback otherwise.

`pmmp_perf_encode_packet_batch()` and `pmmp_perf_encode_packet_single()` now precompute the exact output size and write directly into a `zend_string`, avoiding repeated `smart_str` append operations in the packet framing hot path.

Signed VarInt, biome palette, mapped signed VarInt, U32LE pack, and complete fast paletted-array serialization also use direct `zend_string` writers in the latest staged DLL. These paths keep the same PHP-visible function signatures and fallback semantics while reducing append-loop overhead in chunk serialization hot paths.

`pmmp_perf_encode_biome_palette()` is wired into full chunk serialization. It keeps the PHP fallback semantics for unknown legacy biome IDs while avoiding a temporary PHP array before signed VarInt encoding.

`pmmp_perf_encode_mapped_signed_varints()` maps source runtime IDs through an already-warmed PHP integer map and encodes signed VarInts in one native pass. It returns `null` when a source ID is missing, letting PHP fall back to the cache-filling translator path without changing semantics.

`pmmp_perf_pack_u32le()` and `pmmp_perf_unpack_u32le()` target chunk terrain transfer between threads. `FastChunkSerializer` uses native unpack when loaded, and uses native pack only for larger palettes where the PHP `pack()` spread path is more likely to dominate. Both helpers reject inputs that would overflow native output or PHP array allocation sizes.

`pmmp_perf_serialize_fast_paletted_array()` serializes the hot `FastChunkSerializer` paletted-array blob in one native call: bits-per-block byte, packed word array, big-endian palette byte length, and little-endian u32 palette values. `FastChunkSerializer` uses it only for larger palettes, keeping the existing PHP path for small palettes.

`pmmp_perf_read_fast_paletted_array()` reads the same blob shape from a byte string and returns bits-per-block, word array, palette, and the next offset. It is function-tested but not wired into `FastChunkSerializer` hot paths because the current PHP integration measured slower for deserialize.

Latest promoted live DLL:

- SHA256 `3A0C3A1DCB0106F97C8E857800505B1A9F5E00E0F04D1B84D2FEAC0A58832A16`.
- Validated by the active post-promotion soak `post-native-promotion-soak-20260609-011509`.

Latest staged DLL:

- SHA256 `B73FD205B53FEED1559FD3D4E0C49C42A5E3C64B1AB027BDCD804A93C253C87F`.
- Functional test passes.
- Staged performance gate passes with packet batch native/PHP ratio about `2.58x`, native decode about `754k packets/sec`, full chunk serialization about `67.4k chunks/sec`, and fast chunk serialization about `41.6k chunks/sec`.

Recent staged local microbench:

- Native VarInt prefix: about `33.0M` calls/sec.
- Packet batch encode: about `15.4M` batches/sec.
- Packet batch encode with length validation: about `13.9M` batches/sec.
- Single packet batch encode: about `19.7M` batches/sec.
- Signed VarInt batch encode: about `15.1M` batches/sec.
- Mapped signed VarInt encode: about `11.2M` batches/sec vs PHP map-then-native encode reference `4.2M` batches/sec.
- Biome palette encode with fallback: about `15.4M` palettes/sec.
- U32LE pack: about `11.2M` batches/sec vs PHP reference `7.7M` batches/sec.
- U32LE unpack: about `10.4M` batches/sec vs PHP reference `3.6M` batches/sec.
- Fast paletted-array serialize: about `6.1M` batches/sec vs PHP reference `3.7M` batches/sec.
- Packet batch decode: about `34.2M` packets/sec.

Latest staged FastChunkSerializer equivalence check: native and fallback serialized bytes both hash to `e77e0c8148f719945a9f1ea245dcd81e963f76d0a53b7a3671f34992e7bd51e4` for the large-palette fixture, with roundtrip passing.

Latest staged hotpath bench command:

```powershell
pmmp-bench-staged-native-hotpaths.cmd -Iterations 300
```

This loads `var/native-build/php_pmmp_perf_ext.dll` with PMMP's required native dependencies while bypassing the live bundled perf DLL. Latest staged result after the direct writer expansion: packet batch raw about `2.01M` batches/sec vs PHP reference about `1.04M`, full chunk serialization about `65.0k chunks/sec`, and fast chunk serialize/deserialize about `43.3k/37.7k chunks/sec`. The staged performance gate keeps the stronger best-of-3 evidence listed above.

## Candidate Native Lanes

- VarInt and packet framing helpers.
- Packet batch encode/decode helpers.
- Chunk palette signed VarInt helpers.
- Chunk palette cache-map plus signed VarInt helper.
- Chunk biome palette fallback and signed VarInt helpers.
- Fast chunk U32LE palette pack/unpack helpers.
- Fast chunk complete paletted-array serialization helper.
- Compression policy helpers only after PHP-side measurement proves the branch is hot.

## Windows Status

This repository uses PMMP's bundled ZTS PHP runtime plus a downloaded matching PHP devel pack. The current local build works with MSVC `14.50.35717`; production v142 evidence still requires a VS2019/MSVC `14.29` build.
