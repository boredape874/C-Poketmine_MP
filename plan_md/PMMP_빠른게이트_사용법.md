# PMMP 빠른 게이트 사용법

작성일: 2026-06-07

## 목적

2일 안에 최대한 빠르게 PMMP 포크를 밀기 위해, 수정 후 반복 확인을 한 명령으로 묶는다.

## 기본 명령

```powershell
cd C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-fast-gates.ps1 -AcceptLgpl -Port 19132 -KoreanProfile
```

## 최신 통과 기준

- gate: `20260607-030140`
- ready: true
- ready seconds: 4.153
- fatal matches: 0
- PHPStan exit: 0
- config audit: pass
- chunk budget: pass
- plugin audit: pass
- process samples: 15
- max working set: 328.633 MB
- max private memory: 325.512 MB
- max threads: 16
- max handles: 484

## 산출물 위치

- gate summary: `main_pmmp/var/perf/gates/<gate>/gate-summary.json`
- baseline summary: `main_pmmp/var/perf/baseline/<run>/run-summary.json`
- process samples: `main_pmmp/var/perf/baseline/<run>/process-samples.csv`
- log risk report: `main_pmmp/var/perf/baseline/<run>/log-risk-report.json`
- plugin audit: `main_pmmp/var/perf/plugin-audit/plugin-hotpath-report.json`
- chunk budget: `main_pmmp/var/perf/chunk-budget/chunk-budget.json`

## 현재 경고 해석

`log_risk`가 `warn`으로 나오는 것은 source/dev build 경고와 로그 문자열 패턴 때문이다. fatal, critical, bind failure가 0이면 빠른 개발 게이트에서는 통과로 본다.

## 다음 확장

1. 실제 플러그인을 `main_pmmp/plugins` 또는 gate용 plugins 경로에 넣고 `audit-plugin-hotpaths.ps1` 결과를 본다.
2. 실제 접속 부하가 준비되면 fast gate duration을 늘리고 process samples, fatal, TPS 로그를 비교한다.
3. core 변경 후에는 `run-fast-gates.ps1`를 다시 돌려 ready/fatal/PHPStan/process 메트릭을 남긴다.

## 2026-06-07 추가 반영

- `World::actuallyDoTick()` block update 경로에서 같은 chunk hash를 재사용하도록 조정했다.
- `audit-plugin-hotpaths.ps1`는 rule별 count뿐 아니라 line number와 snippet을 함께 기록한다.
- `20260607-023133` gate는 ready delta가 커서 warn이었고, 재실행한 `20260607-023240` gate에서 pass로 회복했다.

## 2026-06-07 벤치 및 엔티티 반영

- `tools/bench-hotpaths.php`를 추가해 `ChunkSelector`와 varint prefix length 계산을 빠르게 측정한다.
- `run-fast-gates.ps1 -RunHotpathBench`를 쓰면 gate summary에 hotpath bench 수치가 포함된다.
- `Entity::updateMovement()`에서 motion diff 계산의 임시 `Vector3` 생성을 제거했다.
- 최신 hotpath bench:
  - chunk selector: 약 5,742,451 chunks/s
  - varint length: 약 16,309,469 cases/s

## 2026-06-07 블록 파괴 경로 반영

- `World::useBreakOn()`에서 `array_merge(...array_map(...))`와 `array_sum(array_map(...))`를 단일 `foreach` 누산으로 교체했다.
- 최신 gate `20260607-024039`는 기준 run 대비 ready delta `+0.027초`, fatal delta `0`, verdict `pass`다.
- 최신 hotpath bench:
  - chunk selector: 약 5,677,275 chunks/s
  - varint length: 약 16,477,450 cases/s

## 2026-06-07 인벤토리 경로 반영

- `SimpleInventory::getAddableItemQuantity()`를 direct slot 조회 기반으로 override해 clone 반복을 줄였다.
- 최신 gate `20260607-025643`는 기준 run 대비 ready delta `-0.015초`, fatal delta `0`, verdict `pass`다.

## 2026-06-07 아이템 변환 경로 반영

- `ItemTranslator::toNetworkId()`에 `Item::getStateId()` 기반 type-level cache를 추가했다.
- 최신 gate `20260607-025925`는 기준 run 대비 ready delta `-0.001초`, fatal delta `0`, verdict `pass`다.

## 2026-06-07 아이템 변환 벤치 반영

- `bench-hotpaths.php`에 `ItemTranslator::toNetworkId()` 반복 변환 벤치를 추가했다.
- `run-fast-gates.ps1 -RunHotpathBench` summary에 `item_translator_conversions_per_second`를 포함한다.
- 최신 bench:
  - item translator: 약 2,597,015 conversions/s
  - chunk selector: 약 5,481,654 chunks/s
  - varint length: 약 15,563,717 cases/s
