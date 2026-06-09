# Lane E prompt: tooling, gates, and evidence

You are working in `C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp`.

Goal: make PMMP performance work fast to verify, easy to resume, and hard to misreport.

Primary files:

- `tools/run-fast-gates.ps1`
- `tools/continue-fast-progress.ps1`
- `tools/update-latest-progress.ps1`
- `tools/write-gate-summary-markdown.ps1`
- `tools/hotpath-thresholds.json`
- `tools/export-ai-handoff.ps1`
- `tools/bench-hotpaths.php`
- `plan_md/PMMP_latest_progress_2026-06-07.md`

Current implemented areas:

- 400-player wild profile
- fast gate
- hotpath bench
- baseline compare
- progress update script
- AI handoff export
- shell diagnostics

Task:

1. Make `continue-fast-progress.ps1` robust to missing previous baselines and missing optional bench fields.
2. Add threshold warnings for key hotpath counters.
3. Generate compact markdown summaries under each gate directory.
4. Keep output machine-readable JSON.
5. Do not require network access.

Validation:

```powershell
cd C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\diagnose-codex-shell.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\continue-fast-progress.ps1
```

Deliverables:

- PowerShell patch
- generated summary behavior
- progress document update
