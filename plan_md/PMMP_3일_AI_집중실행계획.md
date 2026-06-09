# PMMP 3일 AI 집중 실행계획

작성 기준: 2026-06-07 Asia/Seoul  
기간: 2026-06-07 ~ 2026-06-09  
목표: 3일 안에 PMMP 고성능 구현을 “측정 가능한 MVP” 수준까지 끌어올린다.

## 1. 3일 목표 범위

3일 안에 production급 완전 병렬 PMMP 코어를 만드는 것은 현실적이지 않다. 대신 다음 범위를 완료 목표로 잡는다.

| 구분 | 3일 안에 완료 | 3일 이후로 넘김 |
|---|---|---|
| 성능 측정 | runtime manifest, tick stage, packet/chunk/async metric 기틀 | 장기 dashboard, OpenTelemetry 전체 연동 |
| 즉시 개선 | pocketmine.yml 실험 matrix, 플러그인 위험 패턴 감사, broadcast/chunk 병목 후보 정리 | native extension/sidecar production 적용 |
| 네트워크 | batch/broadcast cache 설계와 1차 PoC 후보 | RakNet 대체 transport |
| 청크 | chunk send latency 측정과 cache 후보 정리 | chunk serialization native rewrite |
| Async/I/O | AsyncTask 위험 사용 감사, dedicated I/O worker 설계 | 완전한 SEDA runtime |
| AI 운영 | subagent 역할, task board, prompt template, gate 문서화 | 완전 자동 merge/deploy |
| 릴리즈 대응 | PMMP/Bedrock 업데이트 watcher 설계 | 모든 버전 자동 포팅 |

3일 결과물은 “감으로 빠르게 만든 최적화”가 아니라, 이후 실제 최적화를 계속 밀어붙일 수 있는 측정 기반과 우선순위 체계다.

## 2. /goal 설정

Codex 또는 다른 AI 세션에서 사용할 목표 문장:

```text
/goal PMMP 5.x 기반 Bedrock 서버를 3일 안에 측정 가능한 고성능 MVP 상태로 만든다. 우선순위는 1) runtime/benchmark 기준선, 2) tick/network/chunk/async 관측성, 3) 플러그인 및 설정 즉시 개선, 4) broadcast/chunk/async 병목 PoC, 5) AI 서브에이전트 운영체계 문서화다. production 배포 전에는 PHPStan/PHPUnit, benchmark artifact, 사람 리뷰를 통과해야 한다.
```

작업 중 세션이 길어질 때 다시 붙일 축약 목표:

```text
/goal 3일 PMMP 고성능 MVP: 측정 먼저, 메인 tick 보호, global broadcast 축소, chunk send latency 개선, AsyncTask/I/O 분리, AI agent는 분석/검증 보조만 수행.
```

## 3. 최종 산출물

| 산출물 | 파일/위치 | 완료 기준 |
|---|---|---|
| 통합 실행계획 | `plan_md/PMMP_고성능_통합실행계획.md` | Phase 0-9와 백로그 정리 |
| 확장 출처 | `plan_md/PMMP_고성능_확장출처_및_AI조사.md` | 공식 문서, 논문, 저장소, 포럼 후보 정리 |
| 벤치마크 설계 | `plan_md/PMMP_벤치마크_및_관측성_설계.md` | metric, artifact, scenario 정의 |
| AI 운영가이드 | `plan_md/PMMP_AI_서브에이전트_운영가이드.md` | agent 역할, YAML 계약, gate 정의 |
| 3일 실행계획 | `plan_md/PMMP_3일_AI_집중실행계획.md` | 날짜별 task와 AI 분업 정의 |
| runtime manifest PoC | `tools/` 또는 `main_pmmp/tools/` | PHP/PMMP/extension/config 기록 |
| metric PoC | `main_pmmp/src/...` 또는 별도 branch | tick/network/chunk/async 최소 측정 |
| benchmark report | `var/perf/` | baseline artifact 1개 이상 |
| 위험 패턴 감사 | `plan_md/PMMP_플러그인_성능감사_체크리스트.md` | global loop, blocking I/O, strong ref 기준 |

## 4. 3일 시간표

### Day 1. 2026-06-07: 기준선과 측정

목표: 최적화 전에 서버가 어디서 시간을 쓰는지 볼 수 있게 만든다.

| 시간대 | 작업 | 담당 | 산출물 |
|---|---|---|---|
| 00-02h | repo 상태 확인, PMMP/PHP/extension/config 기록 방식 결정 | Main AI | runtime manifest 설계 |
| 02-04h | `NetworkSession`, `StandardPacketBroadcaster`, `Player::sendNextChunk`, `AsyncPool` 측정 지점 확정 | Code Analysis Agent | file:line hotspot report |
| 04-07h | runtime manifest PoC 작성 | Main AI | manifest JSON 출력 |
| 07-10h | tick stage JSONL 최소 구현 | Main AI + Reviewer | tick stage artifact |
| 10-12h | spawn-chunk-burst, movement-fanout, plugin-io 시나리오 구체화 | Benchmark Agent | benchmark config |
| 12-16h | baseline 1차 실행 또는 실행 절차 문서화 | Benchmark Agent | baseline report |
| 16-20h | 플러그인 위험 패턴 감사 규칙 작성 | Code Analysis Agent | audit checklist |
| 20-24h | Day 1 결과 정리, Day 2 우선순위 재정렬 | Orchestrator | next task board |

Day 1 완료 기준:

- PMMP/PHP/extension/config를 한 번에 기록할 수 있다.
- tick, network, chunk, async 중 최소 2개 이상의 stage 시간이 artifact로 남는다.
- 성능 개선 후보가 “추측”이 아니라 측정 항목으로 표현된다.

### Day 2. 2026-06-08: 즉시 개선과 PoC

목표: 설정/플러그인/네트워크/청크에서 바로 줄일 수 있는 비용을 줄인다.

| 시간대 | 작업 | 담당 | 산출물 |
|---|---|---|---|
| 00-03h | `pocketmine.yml` compression/async/chunk matrix 설계 | Benchmark Agent | config matrix |
| 03-06h | global broadcast, global player loop, scoreboard/actionbar 폭주 감사 | Code Analysis Agent | risk report |
| 06-10h | broadcast batch cache 또는 static packet cache PoC 설계 | Main AI | PoC patch 후보 |
| 10-14h | chunk send latency 측정 추가 또는 보고서 확장 | Main AI | chunk latency CSV |
| 14-17h | AsyncTask/I/O 분리 설계, 위험 사용 목록 작성 | Code Analysis Agent | async risk report |
| 17-20h | benchmark 재실행, baseline vs candidate 비교 | Benchmark Agent | comparison report |
| 20-22h | Regression Test Agent가 깨질 가능성이 높은 동작 추출 | Regression Agent | test 후보 |
| 22-24h | Risk Gatekeeper가 merge 가능/불가 판단 | Risk Agent | gate report |

Day 2 완료 기준:

- 하나 이상의 candidate 변경 또는 설정 변경이 baseline과 비교된다.
- p95 tick, compression time, chunk latency, packet count 중 하나 이상에서 판단 가능한 수치가 나온다.
- AsyncTask와 플러그인 위험 패턴이 문서화된다.

### Day 3. 2026-06-09: 안정화와 패키징

목표: 3일간 만든 결과를 이후 바로 구현/운영 가능한 형태로 묶는다.

| 시간대 | 작업 | 담당 | 산출물 |
|---|---|---|---|
| 00-04h | candidate patch 정리, 불필요한 실험 제거 | Main AI | 정리된 diff |
| 04-08h | PHPStan/PHPUnit 또는 가능한 검증 실행 | Main AI + CI Triage | 검증 결과 |
| 08-11h | benchmark 최종 실행 | Benchmark Agent | final report |
| 11-14h | 운영 문서, rollback note, canary checklist 작성 | Documentation Agent | release/runbook |
| 14-17h | Release Watch Agent가 PMMP/Bedrock 업데이트 영향 정리 | Release Agent | upstream impact |
| 17-20h | Evaluator가 문서와 patch의 근거 누락 확인 | Evaluator | review notes |
| 20-22h | 최종 task board 정리 | Orchestrator | done/next/backlog |
| 22-24h | 3일 결과 요약과 다음 sprint 계획 작성 | Main AI | final summary |

Day 3 완료 기준:

- artifact가 없는 성능 주장은 제거된다.
- merge 가능한 patch와 실험용 patch가 분리된다.
- 다음 1주 구현 백로그가 우선순위와 metric 기준으로 정리된다.

## 5. 서브 에이전트 분업

동시에 돌릴 agent는 최대 5개 정도로 제한한다. 너무 많이 띄우면 결과 통합 비용이 커진다.

| Agent | 병렬 실행 여부 | 맡길 일 |
|---|---|---|
| Main AI | 항상 | 실제 파일 수정, 최종 통합, 충돌 해결 |
| Code Analysis Agent | 병렬 | PMMP hot path, plugin 위험 패턴, AsyncTask 감사 |
| Benchmark Agent | 병렬 | scenario, config matrix, result 비교 |
| Release Watch Agent | 병렬 | PMMP/PHP/BedrockProtocol/RakLib release 영향 |
| Documentation Agent | 병렬 | 운영 문서, release note, rollback note |
| Evaluator/Risk Agent | 마지막 | 근거 누락, 보안 gate, 테스트 부족 검토 |

## 6. 바로 사용할 subagent 요청문

### Code Analysis Agent

```text
PMMP 5.x 고성능 MVP를 3일 안에 만들기 위한 코드 분석을 맡아라.
수정하지 말고 다음 파일을 중심으로 병목 후보와 측정 지점을 찾아라.
- main_pmmp/src/network/mcpe/NetworkSession.php
- main_pmmp/src/network/mcpe/StandardPacketBroadcaster.php
- main_pmmp/src/Server.php
- main_pmmp/src/player/Player.php
- main_pmmp/src/scheduler/AsyncPool.php
- main_pmmp/src/scheduler/AsyncTask.php
- main_pmmp/src/network/mcpe/handler/InGamePacketHandler.php

출력은 file:line 근거, 병목 가설, 측정 metric, 3일 안에 가능한 PoC 순서로 정리해라.
```

### Benchmark Agent

```text
PMMP 고성능 MVP용 benchmark 설계를 맡아라.
3일 안에 실행 가능한 scenario만 고르고, baseline/candidate 비교 기준을 만들어라.
필수 scenario는 idle-players, spawn-chunk-burst, movement-fanout, plugin-io다.
출력은 config matrix, artifact JSON/CSV 포맷, pass/regression 기준, 실행 순서로 정리해라.
```

### Release Watch Agent

```text
PMMP, PHP-Binaries, BedrockProtocol, BedrockData, RakLib, Minecraft Bedrock release 변경이 3일 MVP에 주는 영향을 조사해라.
production 확정 주장은 공식 출처만 사용하고, 커뮤니티 정보는 참고로 분리해라.
출력은 현재 기준선, 위험 변경, 3일 안에 확인할 항목, 이후 backlog로 분리해라.
```

### Documentation Agent

```text
3일 PMMP 고성능 MVP의 운영 문서를 작성해라.
포함할 문서는 benchmark runbook, canary checklist, rollback note, AI agent 사용 규칙이다.
출력은 바로 plan_md에 넣을 수 있는 Markdown 구조로 작성해라.
```

### Evaluator/Risk Agent

```text
다른 agent 결과와 patch 후보를 검토해라.
성능 주장에 artifact가 있는지, PMMP API 호환성을 깨는지, untrusted input이나 secret 위험이 있는지, 테스트가 부족한지 확인해라.
출력은 pass/fail, blocked reason, required human review list로 작성해라.
```

## 7. 다른 AI 세션 사용법

| 세션 | 목적 | 입력 | 출력 |
|---|---|---|---|
| Codex 메인 세션 | 파일 수정, 통합, 검증 | repo 전체, task board | patch, 문서, 검증 결과 |
| ChatGPT 연구 세션 | 외부 자료 조사 | 출처 질문, 기술 비교 | 링크와 요약 |
| Claude/Gemini 긴문서 세션 | 긴 문서 리뷰 | plan_md 전체 | 누락/모순/리스크 지적 |
| GitHub Copilot | 좁은 코드 작성 | 단일 파일/함수 | 작은 코드 후보 |
| 로컬 CLI AI | 반복 감사 | grep 결과, logs | 패턴 탐지 report |

규칙:

- 외부 AI에 secret, private token, 운영 로그 원문, player 개인정보를 넣지 않는다.
- 외부 AI가 준 코드는 그대로 붙이지 않고 Codex 메인 세션에서 repo 기준으로 다시 검토한다.
- 출처 없는 주장은 `확정`이 아니라 `검증 후보`로 표시한다.
- 최종 merge 판단은 benchmark와 CI 결과로 한다.

## 8. Task board

### P0

- [ ] runtime manifest PoC
- [ ] tick stage JSONL PoC
- [ ] packet/chunk/async metric 측정 지점 선정
- [ ] baseline scenario 1개 이상 실행
- [ ] 플러그인 성능 위험 패턴 체크리스트

### P1

- [ ] compression/async/chunk 설정 matrix
- [ ] broadcast batch cache PoC 후보
- [ ] chunk send latency CSV
- [ ] AsyncTask/I/O 위험 사용 report
- [ ] benchmark comparison report

### P2

- [ ] canary checklist
- [ ] rollback note
- [ ] release watch report
- [ ] AI agent gate report
- [ ] 다음 1주 backlog

## 9. 성공/실패 기준

성공:

- 3일 안에 최소 1개의 baseline artifact가 생성된다.
- PMMP hot path 중 network, chunk, async 중 하나 이상에 측정 코드 또는 측정 절차가 생긴다.
- 최소 1개의 candidate 개선이 baseline과 비교된다.
- AI agent 분업 결과가 문서에 통합된다.
- merge 가능한 변경과 실험용 변경이 분리된다.

실패:

- benchmark 없이 “빨라졌다”고 결론낸다.
- PMMP API나 Bedrock 호환성을 깨는 변경을 검증 없이 넣는다.
- AsyncTask에 대형 객체나 I/O 작업을 더 넣는다.
- AI 출력만 믿고 출처/파일/로그 근거 없이 계획을 확정한다.

## 10. 3일 후 바로 이어갈 1주 백로그

1. `NetworkSession` packet/compression metric 정식화
2. `StandardPacketBroadcaster` batch cache 실험
3. `Player::sendNextChunk` latency와 cache hit 분석
4. AsyncPool completion budget 실험
5. 플러그인 global loop와 blocking I/O 자동 탐지 스크립트
6. PMMP/Bedrock release watcher 자동화
7. MatchActor 또는 arena 단일 소유자 prototype
