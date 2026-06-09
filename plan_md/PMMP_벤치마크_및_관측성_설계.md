# PMMP 벤치마크 및 관측성 설계

작성 기준: 2026-06-07  
목적: PMMP 고성능 구현에서 “빨라졌다”를 판단할 수 있는 공통 측정 기준을 정의한다.

## 1. 측정 원칙

- benchmark는 commit SHA, PMMP version, PHP version, extension list, server config, world seed, player count, warmup, 반복 횟수를 반드시 기록한다.
- 평균 TPS만 보지 않는다. p50, p95, p99 tick time과 stage별 service time을 본다.
- Windows 개발 결과와 Linux 운영 결과를 분리한다.
- OneDrive/한글 경로는 개발 편의용으로 두고, production benchmark는 짧은 ASCII 경로에서 별도 수행한다.
- 수치는 원문 출처의 성능 주장보다 로컬 artifact를 우선한다.

## 2. 핵심 지표

| 지표 | 단위 | 설명 | 우선순위 |
|---|---:|---|---|
| tick_time_ms | ms | 전체 tick 시간 | P0 |
| tick_p95_ms | ms | p95 tick 시간 | P0 |
| tick_p99_ms | ms | p99 tick 시간 | P0 |
| network_tick_ms | ms | network 처리 stage 시간 | P0 |
| world_tick_ms | ms | world/entity/chunk 처리 stage 시간 | P0 |
| scheduler_ms | ms | scheduler와 task completion 시간 | P0 |
| packet_encode_ms | ms | packet encode 시간 | P0 |
| packet_decode_ms | ms | packet decode 시간 | P0 |
| compression_ms | ms | compression/decompression 시간 | P0 |
| outbound_bytes | bytes/tick | client로 보낸 총 바이트 | P1 |
| inbound_bytes | bytes/tick | client에서 받은 총 바이트 | P1 |
| outbound_packet_count | count/tick | outbound packet 수 | P0 |
| broadcast_fanout_count | count/tick | broadcast 대상 수 | P0 |
| chunk_queue_len | count/player | player별 pending chunk | P0 |
| chunk_send_latency_ms | ms | chunk enqueue부터 send까지 | P0 |
| async_queue_len | count | AsyncPool pending 작업 수 | P0 |
| async_completion_ms | ms | 완료 작업을 main thread에서 처리한 시간 | P0 |
| entity_tick_ms | ms | entity update 비용 | P1 |
| memory_rss_mb | MB | 프로세스 RSS | P0 |
| gc_cycles | count | GC cycle 수 | P2 |
| dropped_updates | count | coalescing/drop된 낮은 우선순위 update 수 | P1 |

## 3. artifact 포맷

### 3.1 실행 manifest

```json
{
  "run_id": "2026-06-07T00-00-00Z_spawn-chunk-burst",
  "commit_sha": "unknown",
  "pmmp_version": "5.x",
  "bedrock_version": "recorded-from-release-or-server",
  "php_version": "8.x",
  "php_extensions": ["chunkutils2", "pmmpthread", "libdeflate", "morton", "encoding", "igbinary"],
  "os": "linux-or-windows",
  "cpu": "model",
  "memory_gb": 0,
  "config": {
    "view_distance": 8,
    "spawn_radius": 4,
    "async_workers": 2,
    "compression_level": 6,
    "async_compression": false,
    "async_compression_threshold": 10000
  },
  "scenario": {
    "name": "spawn-chunk-burst",
    "players": 100,
    "duration_seconds": 600,
    "warmup_seconds": 120,
    "repetitions": 5
  }
}
```

### 3.2 tick stage JSONL

```json
{"tick":1,"tick_time_ms":38.2,"network_tick_ms":5.1,"world_tick_ms":18.4,"scheduler_ms":2.0,"packet_encode_ms":3.2,"compression_ms":4.1,"outbound_packet_count":812,"outbound_bytes":124002,"async_queue_len":3,"memory_rss_mb":512}
```

### 3.3 chunk latency CSV

```csv
run_id,player_id,chunk_x,chunk_z,enqueued_tick,sent_tick,latency_ms,source,compressed_bytes
spawn-chunk-burst,p001,10,22,1200,1214,700,cache-hit,18342
```

### 3.4 packet histogram CSV

```csv
run_id,packet_id,direction,count,raw_bytes,compressed_bytes,encode_ms,decode_ms,compress_ms
movement-fanout,PlayerAuthInput,in,120000,9600000,0,0,123.1,0
```

## 4. 측정 지점

| 파일 | 측정 지점 | 기록 |
|---|---|---|
| `main_pmmp/src/Server.php` | main tick 시작/종료, network tick, world tick, scheduler 처리 | tick stage |
| `main_pmmp/src/network/mcpe/NetworkSession.php` | packet receive/send, encode/decode, compression/decompression | packet histogram |
| `main_pmmp/src/network/mcpe/StandardPacketBroadcaster.php` | broadcast batch prepare, 대상 수, cache hit | broadcast fanout |
| `main_pmmp/src/player/Player.php` | chunk enqueue, chunk order, `sendNextChunk` | chunk latency |
| `main_pmmp/src/scheduler/AsyncPool.php` | submit, queue length, collect, completion 처리 | async metrics |
| `main_pmmp/src/network/mcpe/handler/InGamePacketHandler.php` | `PlayerAuthInputPacket` 처리 | movement/input latency |

## 5. benchmark scenario

| 시나리오 | 목적 | 부하 구성 | 합격/판정 |
|---|---|---|---|
| idle-players | session 유지 비용 | 50, 100, 200명 접속 후 정지 | tick p95, memory/player |
| spawn-chunk-burst | 접속 직후 청크 spike | 동시에 join, spawn 주변 chunk 수신 | chunk latency p95, compression p95 |
| movement-fanout | 이동/브로드캐스트 비용 | 같은 arena에서 이동, 회전, 점프 | fanout count, movement packet 수 |
| entity-dense | 엔티티 tick과 metadata | 200, 500, 1000 entity | entity tick p95, outbound packet |
| ui-scoreboard | UI packet 폭주 | scoreboard/actionbar/form 반복 갱신 | packet count, coalescing 효과 |
| plugin-io | blocking I/O 위험 | DB/file/webhook 부하 플러그인 | async backlog, tick spike |
| chunk-travel | 장거리 이동 | 여러 방향으로 이동하며 새 chunk 요청 | cache hit, chunk latency |
| compression-matrix | 압축 정책 비교 | level 1/3/6/9, async on/off, libdeflate on/off | CPU, bandwidth, p95 tick |

## 6. 성능 판정 기준

| 변경 종류 | 승인 기준 |
|---|---|
| network hot path | p95 tick 악화 없음, packet encode/compress time 감소, outbound bytes 또는 packet count 개선 |
| chunk hot path | spawn-chunk-burst p95 chunk latency 감소, memory 증가 허용 범위 명시 |
| async/I/O 분리 | AsyncPool backlog 감소, plugin-io tick spike 감소 |
| fanout/router | broadcast 대상 수 감소, 누락 packet/visibility 버그 없음 |
| native/sidecar | PHP 구현 대비 실측 개선, build/deploy 복잡도와 crash risk 문서화 |
| AI 제안 patch | benchmark artifact, CI, 사람 review 통과 |

## 7. regression 기준

다음 중 하나라도 발생하면 성능 회귀 후보로 표시한다.

- p95 tick time 10% 이상 증가
- p99 tick time 20% 이상 증가
- RSS 15% 이상 증가
- spawn-chunk-burst p95 chunk latency 15% 이상 증가
- movement-fanout outbound packet count 20% 이상 증가
- AsyncPool backlog가 장시간 누적
- 동일 조건에서 disconnect, packet decode error, inventory desync, invisible entity, missing chunk 발생

## 8. 운영 dashboard 후보

| 패널 | 그래프 |
|---|---|
| Tick Health | TPS, p50/p95/p99 tick, slow tick count |
| Network | inbound/outbound bytes, packet count, compression time |
| Chunks | pending chunk/player, chunk latency, cache hit |
| Entities | entity tick time, entity count, metadata packet count |
| Async | queue length, worker busy, completion time |
| Memory | RSS, heap usage, GC cycles |
| Plugin | event handler time, scheduler task time, blocking I/O warning |
| Release | PMMP/PHP/BedrockProtocol versions, canary status |

## 9. 초기 작업 순서

1. `runtime_manifest` 출력부터 만든다.
2. tick stage JSONL을 최소 형태로 만든다.
3. `spawn-chunk-burst`, `movement-fanout`, `plugin-io` 세 시나리오를 먼저 고정한다.
4. `pocketmine.yml`의 compression, async, chunk 설정 matrix를 돌린다.
5. 측정 결과를 보고 Phase 3, Phase 4, Phase 6 중 가장 큰 병목부터 구현한다.
