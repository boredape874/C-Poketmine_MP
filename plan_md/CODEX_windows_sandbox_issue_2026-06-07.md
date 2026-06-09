# Codex Windows sandbox issue 2026-06-07

## Symptom

`functions.shell_command` fails before command execution with:

```text
windows sandbox: spawn setup refresh
```

This happened with minimal commands including:

- `pwd`
- `whoami`
- `cmd /c cd`
- `powershell -NoProfile -Command Get-Location`

It also happened with different working directories:

- `C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP`
- `C:\Users\champ`
- `C:\`

## Conclusion

The failure is not caused by PMMP, PHP, Git, OneDrive, the Korean path, or the current repository. The command process is not created at all. The failing layer is the Codex managed Windows sandbox launcher.

## Current status

As of 2026-06-07 20:38 KST, the shell works again after the session returned to unrestricted execution (`danger-full-access`). `diagnose-codex-shell.cmd` passed PowerShell, cmd, PHP, Git, and ripgrep checks.

The interrupted approval-based fast gate continued in the background and produced `20260607-203549`, but that run had a slow ready time (`6.107s`) and should be treated as noisy. A clean unrestricted rerun produced `20260607-203817`, with server ready in `2.077s`, fatal log matches `0`, PHPStan exit `0`, and compare verdict `pass`.

As of 2026-06-07 20:55 KST, the diagnostic still passes from the repository root via `pmmp-diagnose-codex-shell.cmd`. Plain `php` is not installed globally on `PATH`, but PMMP's bundled runtime at `main_pmmp\bin\php\php.exe` works and is what all project validation scripts use. This is not the sandbox spawn error.

`pmmp-run-tooling-preflight.cmd` also passes, so the PowerShell/CMD automation layer is currently healthy.

As of 2026-06-07 23:19 KST, the root diagnostic passes again with:

- PowerShell child process spawn: pass
- cmd child process spawn: pass
- PMMP bundled PHP runtime: pass
- Git: pass
- ripgrep: pass
- repository write/delete smoke test: pass

`diagnose-codex-shell.ps1` now reports a top-level `ok` field and exits non-zero if any check fails. This prevents later automation from treating a partial shell failure as healthy.

## Current workaround

Use one of these approaches:

1. Reopen the Codex session with sandbox disabled or `danger-full-access`.
2. If approvals are acceptable, run required commands with external execution.
3. If approvals are not acceptable, continue only with direct file edits via `apply_patch`; PHPStan and fast gates cannot be executed from the broken sandbox.

## Added recovery scripts

These scripts are available under `main_pmmp/tools`:

- `diagnose-codex-shell.ps1`: checks PowerShell, cmd, PHP, Git, and ripgrep from the current shell.
- `continue-fast-progress.ps1`: runs the PMMP fast gate with hotpath bench, compares it to the previous baseline when available, and regenerates the AI handoff.
- `update-latest-progress.ps1`: updates `plan_md/PMMP_latest_progress_2026-06-07.md` from the latest gate summary.

Implementation notes:

- `continue-fast-progress.ps1` stores `compare-summary.json` under the current gate directory when the gate path is available.
- `diagnose-codex-shell.ps1` resets `LASTEXITCODE` before each check to avoid stale exit-code readings.

Recommended command after reopening Codex with a working shell:

```powershell
cd C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\diagnose-codex-shell.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\continue-fast-progress.ps1
```

Short CMD wrappers are also available:

```bat
cd /d C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
diagnose-codex-shell.cmd
continue-fast-progress.cmd
```

Root-level wrappers are available from `C-Poketmine_MP`:

```bat
pmmp-diagnose-codex-shell.cmd
pmmp-continue-fast-progress.cmd
```

## Last known verified PMMP state

- Latest clean fast gate run: `20260607-235027`
- Result: server ready in `2.079s`, fatal log matches `0`, PHPStan exit `0`
- Compare vs `fast-gate-20260607-234329`: `pass`
- Note: `20260607-225755` failed because another local PMMP process was already bound to `19132`. It is a noisy port-conflict run, not evidence of a code regression.

## Do not waste time on

- Retrying ordinary `shell_command` in the same managed sandbox profile.
- Moving the repository away from OneDrive as a first response.
- Reinstalling PHP, PMMP, or Git for this specific error.

The next useful action is to change the Codex execution profile or continue patch-only work.

When the diagnostic command itself starts and returns `ok: true`, the managed sandbox spawn layer is no longer the active blocker. In that state, continue with PMMP tooling and use port `19133` if `19132` is already occupied by another local server.

If a command is interrupted during an approval/external execution flow, check for leftover PMMP gate processes before starting another gate:

```powershell
Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'php|powershell|cmd' -and $_.CommandLine -match 'continue-fast-progress|fast-gate|PocketMine' }
```
