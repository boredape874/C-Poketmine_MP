# PMMP 400명 야생 단일 서버 공격계획

작성 기준: 2026-06-07  
목표: PMMP API 호환성을 최대한 유지하면서, 단일 야생 서버 기준 동접 400명 목표에 접근한다.

## 1. 현실 기준

동접 400명 야생 서버는 단순 설정 변경만으로 보장할 수 없다. 특히 야생은 플레이어가 넓게 퍼지고, 새 청크 생성, 청크 전송, 엔티티, 블록 랜덤 tick, 플러그인 이벤트가 동시에 터진다.

따라서 목표를 3단계로 나눈다.

| 단계 | 목표 | API 호환성 | 위험 |
|---|---|---|---|
| Phase A | PMMP 호환 고성능 profile | 거의 유지 | 낮음 |
| Phase B | 플러그인/네트워크/청크 fanout 제거 | 대부분 유지 | 중간 |
| Phase C | 야생 region actor / area executor 실험 | 제한적 shim 필요 | 높음 |

400명 production은 Phase A+B만으로 부족할 수 있다. Phase C까지 가야 진짜 “단일 서버처럼 보이는” 대규모 야생에 가까워진다.

## 2. 절대 원칙

- 메인 tick에서 DB/file/network I/O 금지.
- 모든 플레이어 대상 broadcast 금지.
- 기본 view-distance는 낮게 시작하고, 클라이언트 체감은 prefetch/cache로 보완한다.
- chunk generation은 접속 중 생성보다 사전 생성이 기본이다.
- entity, tile, hopper, random tick, scoreboard/actionbar/form 갱신은 상한을 둔다.
- 플러그인 API는 유지하되, 고위험 API 사용은 slow-path로 격리한다.
- 야생 월드 분산은 region owner 단일 writer 원칙 없이는 하지 않는다.

## 3. 즉시 적용 고성능 profile

### server.properties 권장 시작값

```properties
motd=PMMP Wild 400 Target
server-port=19132
server-portv6=0
enable-ipv6=false
white-list=false
max-players=400
gamemode=survival
force-gamemode=false
hardcore=false
pvp=true
difficulty=1
level-name=world
level-seed=
level-type=DEFAULT
enable-query=false
auto-save=true
view-distance=4
xbox-auth=true
language=kor
```

### pocketmine.yml 권장 시작값

```yaml
settings:
  async-workers: auto
  enable-profiling: true
  profile-report-trigger: 18

network:
  compression-level: 1
  async-compression: true
  async-compression-threshold: 4096
  max-mtu-size: 1492
  enable-encryption: true

debug:
  level: 1

chunk-sending:
  per-tick: 2
  spawn-radius: 2

chunk-ticking:
  tick-radius: 2
  blocks-per-subchunk-per-tick: 1

chunk-generation:
  population-queue-size: 8

console:
  enable-input: false
  title-tick: false
```

이 값은 “최종값”이 아니라 400명 목표의 시작점이다. chunk 체감이 부족하면 view-distance를 올리기 전에 pregen, cache, spawn-radius, per-tick, compression 수치를 비교한다.

## 4. 400명 야생 병목별 대응

| 병목 | 원인 | 1차 대응 | 2차 대응 |
|---|---|---|---|
| 청크 생성 | 야생 신규 탐험 | 월드 사전 생성, population queue 제한 | 별도 pregen 서버/프로세스 |
| 청크 전송 | 접속/이동 시 대량 packet | view-distance 4, spawn-radius 2, compression level 1 | chunk cache hit 개선, chunk send latency metric |
| 메인 tick | world/entity/plugin event 집중 | 플러그인 감사, 랜덤 tick 축소, entity cap | region actor 실험 |
| 네트워크 압축 | 플레이어별 batch 압축 | libdeflate, async compression, threshold matrix | static/broadcast batch cache |
| global broadcast | 모든 플레이어 루프 | world/region/team/subscriber set | AOI router |
| DB/file I/O | 플러그인 저장/로그 | dedicated worker/process, batch flush | write-behind queue |
| scoreboard/UI | 매 tick 문자열 갱신 | 변경분만 전송, tick 상한 | UI subscription cache |
| 엔티티 | mob/item/projectile 폭증 | cap, despawn, merge, inactive tick | entity region owner |

## 5. 멀티스레딩 전략

PMMP에서 안전한 멀티스레딩:

- RakLib thread: 네트워크 transport
- AsyncPool: compression, chunk generation/population, light, auth, 일부 curl
- log writer thread
- worker-local generator context

추가로 넣을 수 있는 것:

| 후보 | 설명 | API 호환성 |
|---|---|---|
| DedicatedDbWorker | DB/file/network I/O 전용 queue | 높음 |
| CompressionPolicyWorker | 큰 packet 압축 전용 정책 강화 | 높음 |
| ChunkPrecomputeWorker | 지도/청크 주변 데이터 사전 계산 | 중간 |
| RegionReadWorker | 읽기 전용 snapshot 분석 | 중간 |
| RegionActor | 야생 region별 단일 writer tick | 낮음-중간 |

금지:

- World/Player/Entity 객체를 worker에 직접 넘기기.
- 여러 thread가 같은 chunk/entity를 동시에 수정하기.
- 플러그인 이벤트를 worker thread에서 직접 호출하기.
- client 판정을 믿고 서버 검증 생략하기.

## 6. API 호환성 유지 방식

| API 종류 | 유지 방식 |
|---|---|
| 기존 이벤트 | main thread에서 계속 호출 |
| Player/World/Entity API | main thread facade 유지 |
| async worker 결과 | command/result DTO로 main thread에 반영 |
| region actor 실험 | 호환 plugin은 main facade를 통해 접근 |
| 위험 plugin API | slow-path로 처리하고 경고 |

400명 목표에서는 모든 플러그인을 무조건 허용하면 어렵다. PMMP API는 최대한 유지하되, `DataPacketReceiveEvent`, `DataPacketSendEvent`, 전역 player loop, sync I/O를 쓰는 플러그인은 성능 등급을 낮게 잡아야 한다.

## 7. 구현 순서

### 1차: 바로 가능한 것

- 고성능 profile 생성 도구
- runtime manifest
- source baseline runner
- hot path 미세 최적화
- 플러그인 성능감사
- Timings 기반 병목 확인

### 2차: 400명 준비

- chunk send latency metric
- broadcast fanout metric
- async queue/backlog metric
- compression-level/async-threshold matrix
- scoreboard/actionbar/form coalescing
- 플러그인 DB/file I/O 분리

### 3차: 진짜 큰 구조

- AOI router
- world/region subscriber set
- static packet cache
- dedicated DB worker
- arena/region actor prototype
- 야생 region ownership 실험 branch

## 8. 성공 기준

| 단계 | 기준 |
|---|---|
| 0명 idle | TPS 20, tick usage 10% 이하 |
| 1명 join | spawn 완료, fatal 없음, chunk latency 기록 |
| 50명 | p95 tick 50ms 이하 |
| 100명 | network/chunk 병목 분리 가능 |
| 200명 | view-distance 4에서 평균 TPS 19.5 이상 |
| 400명 | pregen world, 제한된 plugin set, p95 tick 50ms 근접, disconnect 폭주 없음 |

400명 성공 기준은 bot/load test 없이 확정할 수 없다. 실제 부하 도구 또는 Bedrock 클라이언트 다중 접속이 필요하다.

## 9. 사용자가 해야 하는 것

- LGPL에 동의할지 결정한다.
- 목표 하드웨어를 알려준다: CPU 모델, RAM, 디스크, OS.
- 실제 플러그인을 제공한다.
- 야생 월드 크기와 pregen 가능 범위를 정한다.
- 400명 테스트용 bot/load 도구 또는 테스트 인원을 준비한다.
- production 배포 시점을 승인한다.

## 10. 내가 계속 할 것

- 코어 hot path 최적화.
- profile/config 생성 도구 작성.
- benchmark runner 보강.
- plugin audit와 수정.
- Timings/metric 분석.
- API 호환성 깨지는 변경은 별도 branch로 분리.
- 400명 목표에 맞춘 장기 region actor 설계.
