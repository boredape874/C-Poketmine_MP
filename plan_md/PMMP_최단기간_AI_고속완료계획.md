# PMMP 최단기간 AI 고속 완료계획

작성 기준: 2026-06-07  
목적: 3일 같은 고정 기한보다 “최대한 빠르게 끝내는 방식”으로 PMMP 고성능 구현을 진행한다.

## 1. 방향 전환

기존 `PMMP_3일_AI_집중실행계획.md`는 3일 sprint용이다. 이 문서는 날짜 제한을 제거하고, 완료 조건을 gate 기반으로 바꾼다.

핵심 변경:

| 기존 | 변경 |
|---|---|
| 3일 안에 가능한 범위 | 통과한 gate부터 바로 다음 단계 진행 |
| 날짜별 작업 | 병렬 lane별 작업 |
| sprint 종료 시 정리 | 매 stage마다 artifact와 patch 정리 |
| 문서 중심 | 측정 -> 구현 -> 검증 -> 운영 문서 순환 |

## 2. 최단 완료의 정의

“다 끝냈다”를 한 번에 하나로 정의하면 너무 커진다. 그래서 3단계 완료로 나눈다.

| 완료 단계 | 의미 | 목표 |
|---|---|---|
| Fast MVP | 성능 병목을 측정하고, 즉시 개선 1-2개를 검증 | 가장 빠른 실효 성과 |
| Production Ready | 운영 설정, 검증, rollback, canary까지 포함 | 실제 서버 적용 가능 |
| Experimental Core | region/actor/native/sidecar 같은 큰 구조 실험 | 장기 고성능 코어 |

최단 경로는 `Fast MVP -> Production Ready -> Experimental Core` 순서다.  
처음부터 Experimental Core를 production에 넣으면 느려지고 위험해진다.

## 3. 새 /goal 문장

Codex나 다른 AI 세션에 붙일 목표:

```text
/goal PMMP 5.x 기반 Bedrock 서버를 최대한 빠르게 고성능화한다. 날짜 제한보다 gate를 우선한다. 1) runtime/benchmark 기준선, 2) tick/network/chunk/async 관측성, 3) 설정과 플러그인 즉시 개선, 4) broadcast/chunk/async 병목 PoC, 5) benchmark와 CI로 검증된 patch, 6) canary/rollback 운영 문서 순서로 진행한다. AI와 서브 에이전트는 분석, benchmark, 문서, 검증을 병렬 처리하고, 코드 merge와 배포 판단은 artifact 기준으로 한다.
```

짧은 버전:

```text
/goal PMMP 고성능 최단 완료: 측정 먼저, tick 보호, packet/chunk/async 병목 제거, benchmark artifact 기준으로 빠르게 merge 가능한 것부터 끝낸다.
```

## 4. 병렬 lane

작업은 날짜가 아니라 lane으로 나눈다. Main AI는 파일 수정과 최종 통합만 맡고, 나머지는 서브 에이전트나 다른 AI 세션에 병렬로 던진다.

| Lane | 담당 | 즉시 할 일 | 완료 조건 |
|---|---|---|---|
| L1. Observability | Main AI | runtime manifest, tick stage, packet/chunk/async metric | artifact가 생성됨 |
| L2. Benchmark | Benchmark Agent | scenario, config matrix, baseline/candidate 비교 | p95/p99 포함 report |
| L3. Code Hotspot | Code Analysis Agent | NetworkSession, broadcaster, Player chunk, AsyncPool 감사 | file:line 근거 report |
| L4. Plugin Audit | Code Analysis Agent | global loop, blocking I/O, Player strong ref 탐지 | 위험 패턴 목록 |
| L5. Release Watch | Release Agent | PMMP/PHP/Bedrock/RakLib 추적 | impact report |
| L6. Docs/Runbook | Documentation Agent | benchmark runbook, canary, rollback | 운영 문서 |
| L7. Risk/Eval | Evaluator Agent | artifact 없는 주장, API break, 보안 위험 검토 | pass/fail |

## 5. 바로 시작할 순서

### Step 0. 현재 repo 상태 고정

산출물:

- `git status`
- PMMP commit/tag
- PHP version
- loaded extensions
- `pocketmine.yml` 주요 설정
- Composer dependency version

완료 gate:

- `runtime_manifest`가 생성된다.

### Step 1. 최소 metric부터 넣기

우선순위:

1. `Server.php` main tick stage
2. `NetworkSession.php` packet encode/decode/compress
3. `StandardPacketBroadcaster.php` broadcast 대상 수와 batch prepare 시간
4. `Player.php` chunk enqueue/send latency
5. `AsyncPool.php` queue length와 completion time

완료 gate:

- tick별 JSONL 또는 CSV artifact가 생성된다.
- 최소 1개 benchmark scenario에서 수치가 나온다.

### Step 2. 가장 빠른 개선부터 적용

순서:

1. `pocketmine.yml` compression/async/chunk matrix
2. scoreboard/actionbar/form 갱신 coalescing
3. global player loop 제거
4. static packet 또는 broadcast batch cache 후보
5. chunk send queue 병목 제거
6. AsyncTask/I/O 분리

완료 gate:

- baseline 대비 p95 tick, compression time, packet count, chunk latency 중 하나 이상이 개선된다.

### Step 3. 검증과 운영화

필수:

- PHPStan/PHPUnit 또는 해당 변경에 맞는 검증
- benchmark artifact
- canary checklist
- rollback note
- 변경 전후 config 기록

완료 gate:

- 운영 서버에 적용 가능한 patch와 실험 patch가 분리된다.

## 6. kill 기준

빠르게 끝내려면 오래 걸릴 작업을 빨리 버려야 한다.

| 작업 | kill 기준 |
|---|---|
| native extension | 1일 안에 재현 가능한 benchmark 이득이 없으면 backlog |
| RakNet 대체 | PMMP 호환성 검증 범위가 커지면 backlog |
| region actor | minigame/arena prototype이 아니면 backlog |
| 완전한 dashboard | JSONL/CSV artifact가 먼저 없으면 backlog |
| 모든 플러그인 전수 수정 | 위험 패턴 상위 플러그인부터 처리 |
| 외부 AI 대량 조사 | patch나 benchmark 판단에 직접 쓰이지 않으면 중단 |

## 7. AI 사용 방식

### Main AI

역할:

- 실제 파일 수정
- patch 통합
- benchmark 실행
- 최종 판단

금지:

- artifact 없이 성능 개선 주장
- 서브 에이전트 결과를 검증 없이 반영

### 서브 에이전트

동시에 3-5개만 사용한다.

우선순위:

1. Code Analysis Agent
2. Benchmark Agent
3. Documentation Agent
4. Release Watch Agent
5. Evaluator/Risk Agent

### 다른 AI 세션

| 세션 | 맡길 일 |
|---|---|
| 연구 세션 | Folia, MultiPaper, PMMP issue, PHP extension 자료 추가 조사 |
| 긴 문서 리뷰 세션 | plan_md 전체 모순/누락 탐지 |
| 코드 후보 세션 | 단일 함수/단일 파일 수준 PoC 아이디어 |

규칙:

- secret, 운영 로그 원문, player 개인정보는 외부 AI에 넣지 않는다.
- 외부 AI 결과는 출처와 artifact가 없으면 초안이다.
- 최종 코드 판단은 repo 내부 검증으로 한다.

## 8. 빠른 task board

### 지금 바로

- [x] runtime manifest 작성
- [ ] benchmark artifact 폴더 구조 확정
- [ ] `Server.php` tick stage 측정 후보 확인
- [ ] `NetworkSession.php` compression/packet metric 후보 확인
- [ ] `Player.php` chunk latency 측정 후보 확인

완료된 artifact:

- `main_pmmp/tools/collect-runtime-manifest.ps1`
- `main_pmmp/tools/run-source-baseline.ps1`
- `main_pmmp/var/perf/runtime-manifest-20260607-014041.json`

사용자 필요 작업:

- PMMP 루트의 `LICENSE`를 읽고 LGPL에 동의한 뒤 baseline 실행 시 `-AcceptLgpl`을 붙인다.
- 실제 접속 부하가 필요하면 Bedrock 클라이언트 또는 별도 bot/load 도구를 준비한다.
- 운영 서버에 적용할 시점은 별도로 승인한다.

baseline 실행 예시:

```powershell
cd C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-source-baseline.ps1 -AcceptLgpl -Port 19132 -DurationSeconds 60
```

### 다음 묶음

- [ ] `pocketmine.yml` config matrix
- [ ] spawn-chunk-burst baseline
- [ ] movement-fanout baseline
- [ ] plugin-io baseline
- [ ] 플러그인 위험 패턴 감사

### 개선 후보

- [ ] broadcast batch cache
- [ ] static packet cache
- [ ] scoreboard/actionbar coalescing
- [ ] AsyncTask/I/O 분리
- [ ] chunk send queue 조정

### 운영화

- [ ] canary checklist
- [ ] rollback note
- [ ] release watch report
- [ ] merge 가능한 patch와 실험 patch 분리

## 9. 최단 완료 보고 형식

매 stage 끝날 때 아래 형식으로만 판단한다.

```text
완료:
- 무엇을 바꿨는지
- 어떤 artifact가 생겼는지
- 어떤 수치가 좋아졌거나 나빠졌는지

판단:
- merge 가능
- 실험 유지
- backlog
- 폐기
```

## 10. 실제 우선순위

가장 빠른 실효 성과 순서:

1. 측정 artifact 생성
2. config matrix로 compression/async/chunk 설정 정리
3. plugin global loop와 blocking I/O 제거
4. broadcast fanout 축소
5. chunk send latency 개선
6. AsyncTask/I/O 분리
7. static packet/batch cache
8. release/canary/rollback 운영화
9. actor/region/native는 benchmark로 필요성이 증명된 뒤 진행
