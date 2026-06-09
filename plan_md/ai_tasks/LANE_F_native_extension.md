# Lane F prompt: optional native extension

You are working in `C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp`.

Goal: prepare optional C/C++ acceleration for PMMP hotpaths without breaking PHP fallback or plugin APIs.

Primary files:

- `native/pmmp_perf_ext/*`
- `tools/check-native-extension-env.ps1`
- `plan_md/PMMP_native_extension_lane.md`

Current status:

- PoC extension source exists.
- PHP was previously detected as `8.2.30 zts Windows`.
- Missing build tools previously included `cl.exe`, `nmake.exe`, `phpize`.

Task:

1. Diagnose build toolchain readiness.
2. Build PoC only when matching PHP build environment exists.
3. Keep PHP fallback path mandatory.
4. Benchmark native helper before expanding native scope.
5. Do not convert large PMMP subsystems to C/C++ without evidence.

Validation:

```powershell
cd C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check-native-extension-env.ps1
```

Deliverables:

- build readiness report
- build log if possible
- benchmark comparison if extension loads
