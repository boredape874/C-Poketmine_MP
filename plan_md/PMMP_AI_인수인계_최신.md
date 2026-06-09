# PMMP AI 인수인계 최신

작성일: 2026-06-07

## 최신 handoff 산출물

- JSON: `main_pmmp/var/perf/ai-handoff/handoff.json`
- Markdown: `main_pmmp/var/perf/ai-handoff/handoff.md`
- 생성 명령:

```powershell
cd C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\export-ai-handoff.ps1
```

## 최신 gate

- gate: `20260607-030625`
- ready: true
- ready seconds: 2.137
- fatal: 0
- PHPStan: 0
- RakNet ping: 64/64
- RakNet loss: 0%
- RakNet avg latency: 27.099 ms

## 다음 실행 명령

```powershell
cd C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-fast-gates.ps1 -AcceptLgpl -Port 19132 -KoreanProfile -RunRakPingBurst
```

## 다음 후보

- `Player::processMostRecentMovements()`는 움직임이 없을 때 clone을 만들지 않도록 1차 최적화 완료. 더 공격적인 fast-return은 `PlayerMoveEvent` 회귀 리스크 때문에 실제 이동 테스트 전에는 보류.
- 실제 플러그인이 들어오면 `tools/audit-plugin-hotpaths.ps1 -Markdown` 결과 기준으로 sync I/O, 반복 task, 전체 player loop를 먼저 처리.
- 실제 부하 도구가 준비되면 20명, 50명, 100명, 200명, 400명 순서로 gate duration과 process sampling을 늘린다.

## 최신 Player 이동 경로 gate

- gate: `20260607-031119`
- ready: true
- ready seconds: 2.143
- fatal: 0
- PHPStan: 0
- compare verdict: pass

## 최신 비교 도구

- `tools/compare-baseline-runs.ps1`는 ready/fatal뿐 아니라 process memory/thread/handle과 RakNet ping loss/latency delta도 비교한다.
- 최신 비교: `20260607-030625` -> `20260607-031119`
  - ready delta: +0.006 seconds
  - working set delta: -6.293 MB
  - private memory delta: -0.024 MB
  - handles delta: +40
  - verdict: pass

## 최신 Player movement 입력 경로

- `Player::actuallyHandleMovement()`에서 `distanceSquared()` 호출과 dx/dy/dz 재계산을 scalar 계산 1회로 합쳤다.
- gate: `20260607-031511`
- ready seconds: 2.148
- fatal: 0
- PHPStan: 0
- compare verdict: pass
