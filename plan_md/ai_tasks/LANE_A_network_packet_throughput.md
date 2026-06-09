# Lane A prompt: network packet throughput

You are working in `C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp`.

Goal: improve PMMP network packet throughput for a high-density Bedrock survival server while preserving public PMMP API compatibility.

Read first:

- `plan_md/PMMP_latest_progress_2026-06-07.md`
- `plan_md/PMMP_AI_parallel_execution_board.md`
- `main_pmmp/var/perf/ai-handoff/handoff.md` if present

Primary files:

- `src/network/mcpe/StandardPacketBroadcaster.php`
- `src/network/mcpe/NetworkBroadcastUtils.php`
- `src/network/mcpe/NetworkSession.php`
- `src/Server.php`
- `vendor/pocketmine/bedrock-protocol/src/serializer/PacketBatch.php`
- `tools/bench-hotpaths.php`

Current implemented areas:

- raw batch length reuse
- single packet raw batch helper
- network session send-buffer length reuse
- compression threshold and batch length reuse

Task:

1. Audit remaining repeated packet `encode()` and batch construction paths.
2. Add/extend fixture coverage in `tools/bench-hotpaths.php` for common broadcast packet cases.
3. Prefer direct scalar loops and cached lengths over helper chains or repeated `strlen()`.
4. Do not change public plugin APIs.
5. Add modified PHP files to `tools/run-fast-gates.ps1` PHPStan target list.

Validation when shell works:

```powershell
cd C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\continue-fast-progress.ps1
```

Deliverables:

- PHP patch
- bench fixture patch when useful
- progress note in `plan_md/PMMP_latest_progress_2026-06-07.md`
- no public API break without compatibility shim
