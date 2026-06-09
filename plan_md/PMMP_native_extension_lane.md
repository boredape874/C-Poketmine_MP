# PMMP native extension lane

Updated: 2026-06-09 KST

## Purpose

PMMP public plugin API compatibility stays in PHP while repeated binary hotpaths move into an optional C native extension. PHP fallback is mandatory, so the server must still boot and pass gates when the extension is missing.

## Current status

- Status: implemented, promoted, and fast-release validated.
- Production live/staged DLL SHA256: `E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB`.
- Compiler evidence: VS2019 Build Tools / MSVC `14.29.30133` / v142.
- Evidence file: `main_pmmp/var/perf/production-evidence/native-v142-build.json`.
- Fast post-promotion soak: `post-native-promotion-soak-20260609-021925`, `300s`, ready `true`, fatal `0`.
- Active strict soak: `production-v142-strict-soak-20260609-195210`, ready `true`, fatal `0`; final production audit waits for the full `7200s` result.

## Implemented helpers

- `pmmp_perf_build_info()`
- `pmmp_perf_varint_prefix_length()`
- `pmmp_perf_encode_packet_batch()`
- `pmmp_perf_encode_packet_single()`
- `pmmp_perf_decode_packet_batch()`
- `pmmp_perf_decode_packet_batch_callback()`
- `pmmp_perf_encode_signed_varints()`
- `pmmp_perf_encode_mapped_signed_varints()`
- `pmmp_perf_encode_biome_palette()`
- `pmmp_perf_pack_u32le()`
- `pmmp_perf_unpack_u32le()`
- `pmmp_perf_serialize_fast_paletted_array()`
- `pmmp_perf_read_fast_paletted_array()`

## PHP integration

- Packet batch encode paths use the native helper when loaded.
- Chunk serialization uses native signed VarInt and palette helpers where measured beneficial.
- `pmmp_perf_read_fast_paletted_array()` is function-tested but not wired into the deserialize hotpath because the measured PHP integration path was slower than the existing PHP reader.
- The extension is optional; fallback paths remain part of the supported runtime contract.

## Build and validation commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\main_pmmp\tools\build-native-extension-windows.ps1 -PreferVs16
powershell -NoProfile -ExecutionPolicy Bypass -File .\main_pmmp\tools\record-native-build-evidence.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\main_pmmp\tools\test-native-extension.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\main_pmmp\tools\promote-staged-native-extension.ps1 -AcceptLgpl
```

## Guardrails

- Do not expose PMMP event objects, `Player`, `World`, or plugin-owned state through the C ABI.
- Do not make the extension mandatory for boot.
- Do not ship the VS2026 `14.50` PE-patched DLL as production evidence. The production DLL is the v142 build above.
- Do not wire native read helpers into live paths without benchmark proof on the real workload.

## Remaining work

- Let the active strict `7200s` soak finish and bind the final `soak.json` evidence to the live v142 DLL hash.
- Re-test `pmmp_perf_read_fast_paletted_array()` only if a cleaner PHP call path removes the previous deserialize regression.
- Add more native work only where benchmark evidence shows PHP overhead is dominant: chunk payload packing, packet fanout encoding, and repeated primitive buffer transforms.
