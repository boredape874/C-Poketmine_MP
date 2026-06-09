# PMMP 고성능 확장 출처 및 AI 조사

작성 기준: 2026-06-07  
용도: `PMMP_고성능_통합실행계획.md`의 근거 출처와 추가 조사 대상을 정리한다.

## 1. PMMP 공식 자료

| 출처 | 링크 | 계획에 반영한 내용 |
|---|---|---|
| PMMP releases | https://github.com/pmmp/PocketMine-MP/releases | 현재 stable, 대상 Bedrock 버전, 릴리즈 변경사항 확인 |
| PMMP requirements | https://doc.pmmp.io/en/rtfd/installation/requirements.html | 64-bit, RAM, 멀티코어 활용 한계, 단일 코어 성능 우선 기준 |
| PMMP stable composer.json | https://github.com/pmmp/PocketMine-MP/blob/stable/composer.json | PHP, pmmpthread, chunkutils2, raklib, bedrock-protocol, bedrock-data 의존성 확인 |
| PMMP BUILDING | https://github.com/pmmp/PocketMine-MP/blob/stable/BUILDING.md | 빌드와 PHP 바이너리 구성 기준 |
| PMMP pocketmine.yml | https://github.com/pmmp/PocketMine-MP/blob/stable/resources/pocketmine.yml | async-workers, compression-level, async-compression, chunk send 설정 |
| PMMP Timings API | https://apidoc.pmmp.io/de/d8c/classpocketmine_1_1timings_1_1_timings.html | 기존 timing 체계와 측정 확장 후보 |
| PMMP AsyncTask API | https://apidoc.pmmp.io/df/dfa/classpocketmine_1_1scheduler_1_1_async_task.html | AsyncTask의 CPU-bound 중심 사용 원칙, PMMP API 접근 제한 |
| PMMP threading 문서 | https://doc.pmmp.io/en/rtfd/developers/threading-in-php-wtf.html | PHP thread 데이터 전달 비용, worker 적합/부적합 작업 구분 |
| PMMP protocol update guide | https://doc.pmmp.io/en/rtfd/developers/internals-docs/updating-minecraft-protocol.html | Bedrock 업데이트 순서, BedrockProtocol/Data/codegen/WorldDataVersions 관리 |
| PMMP API version spec | https://doc.pmmp.io/en/rtfd/developers/plugin-docs/api-version-spec.html | 플러그인 API 호환성 관리 |

## 2. PMMP PHP 바이너리와 native extension

| 출처 | 링크 | 계획에 반영한 내용 |
|---|---|---|
| PHP-Binaries | https://github.com/pmmp/PHP-Binaries | PMMP용 PHP 빌드, 공식 extension 목록, PHP 8.4 지원 표현 주의 |
| php-build-scripts | https://github.com/pmmp/php-build-scripts | PMMP PHP 빌드 체인과 커스텀 빌드 기준 |
| ext-chunkutils2 | https://github.com/pmmp/ext-chunkutils2 | PalettedBlockArray, LightArray, SubChunkConverter native hot path 후보 |
| ext-libdeflate | https://github.com/pmmp/ext-libdeflate | zlib 대체 압축 성능 후보, 실제 서버 부하에서 재측정 필요 |
| ext-pmmpthread | https://github.com/pmmp/ext-pmmpthread | PHP CLI threading 기반, 데이터 복사 비용 주의 |
| ext-morton | https://github.com/pmmp/ext-morton | 좌표 packing, chunk/block key hot path 후보 |
| ext-encoding | https://github.com/pmmp/ext-encoding | 네트워크/디스크 encoding 성능 후보 |
| igbinary | https://github.com/igbinary/igbinary | PHP serializer 대체 성능 후보 |

## 3. Bedrock 프로토콜과 네트워크

| 출처 | 링크 | 계획에 반영한 내용 |
|---|---|---|
| Mojang bedrock-protocol-docs | https://github.com/Mojang/bedrock-protocol-docs | 공식 Bedrock packet 문서, 누락 가능성 감안 |
| Bedrock samples | https://mojang.github.io/bedrock-samples/ | Bedrock 데이터와 리소스 샘플 참조 |
| Bedrock Wiki RakNet | https://wiki.bedrock.dev/servers/raknet | Bedrock 외부 서버의 RakNet/UDP 구조 |
| Bedrock Wiki server protocol | https://wiki.bedrock.dev/servers/bedrock | login, packet flow, compression 이해 |
| RakLib | https://github.com/pmmp/RakLib | PMMP RakNet 구현 계층, PHP 라이브러리임을 명확히 구분 |
| BedrockProtocol Packagist | https://packagist.org/packages/pocketmine/bedrock-protocol | 프로토콜 패키지 버전 추적 |
| BedrockData Packagist | https://packagist.org/packages/pocketmine/bedrock-data | Bedrock data 패키지 버전 추적 |
| gophertunnel | https://github.com/Sandertv/gophertunnel | Go 기반 Bedrock/RakNet 구현 참고 |
| gophertunnel docs | https://sandertv-gophertunnel.mintlify.app/ | proxy/client/server 구현 참고 |
| Gaffer snapshot interpolation | https://www.gafferongames.com/post/snapshot_interpolation/ | 필요한 상태만 전송하고 보간하는 네트워크 설계 참고 |
| Gaffer snapshot compression | https://gafferongames.com/post/snapshot_compression/ | 양자화, delta, 불필요한 값 제거 참고 |

## 4. 대규모 서버 구조와 병렬 처리

| 출처 | 링크 | 계획에 반영한 내용 |
|---|---|---|
| Folia overview | https://docs.papermc.io/folia/reference/overview/ | regionized multithreading의 단일 소유자 원칙 |
| Folia region logic | https://docs.papermc.io/folia/reference/region-logic/ | region merge/split, per-region tick 설계 |
| Folia FAQ | https://docs.papermc.io/folia/faq/ | 플러그인 호환성과 운영 제약 |
| MultiPaper architecture | https://multipaper.io/multipaper/how-it-works.html | chunk ownership, master, shard authority 참고 |
| SEDA paper | https://people.eecs.berkeley.edu/~brewer/papers/SEDA-sosp.pdf | stage, bounded queue, backpressure, dynamic resource control |
| Actor model paper | https://osl.cs.illinois.edu/publications/journals/jsa/AghaK99.html | actor 기반 상태 격리와 message passing |
| FiveM OneSync | https://docs.fivem.net/docs/scripting-reference/onesync/ | focus zone, routing bucket, entity routing |
| IBM interest management survey | https://research.ibm.com/publications/interest-management-for-distributed-virtual-environments-a-survey | 대규모 가상환경 interest management 이론 |
| Roblox multithreading | https://create.roblox.com/docs/scripting/multithreading | Actor 기반 병렬 실행 구조 참고 |
| Roblox network ownership | https://create.roblox.com/docs/physics/network-ownership | client ownership의 성능/보안 tradeoff 주의 |
| LMAX Disruptor | https://lmax-exchange.github.io/disruptor/disruptor.html | 명확한 thread model에서의 queue 설계 참고 |
| JCTools queues | https://javadoc.io/static/org.jctools/jctools-core/3.3.0/org/jctools/queues/package-summary.html | lock-free queue 참고, PHP userland 직접 모방은 보류 |

## 5. PHP 성능과 메모리

| 출처 | 링크 | 계획에 반영한 내용 |
|---|---|---|
| PHP GC cycles | https://www.php.net/manual/en/features.gc.collecting-cycles.php | 순환 참조와 GC 비용 이해 |
| PHP refcount basics | https://www.php.net/manual/en/features.gc.refcounting-basics.php | zval, refcount, copy-on-write 이해 |
| PHP internals memory management | https://www.phpinternalsbook.com/php5/zvals/memory_management.html | PHP 객체/배열 복사 비용 판단 |
| OPcache configuration | https://www.php.net/manual/en/opcache.configuration.php | JIT와 OPcache 설정 기준 |
| PHP 8.4 JIT default changes | https://php.watch/versions/8.4/opcache-jit-ini-default-changes | PHP 8.4 JIT 기본값 변경 주의 |

## 6. 직렬화와 binary buffer 후보

| 출처 | 링크 | 계획에 반영한 내용 |
|---|---|---|
| FlatBuffers | https://flatbuffers.dev/ | zero-copy, compact binary layout 아이디어 참고 |
| Cap'n Proto | https://capnproto.org/ | schema 기반 binary message, zero-copy 아이디어 |
| Protocol Buffers arena | https://protobuf.dev/reference/cpp/arenas/ | allocation churn 감소 아이디어 참고 |

## 7. 대체 Bedrock 서버와 비교 구현

| 출처 | 링크 | 계획에 반영한 내용 |
|---|---|---|
| Dragonfly | https://github.com/df-mc/dragonfly | Go 기반 Bedrock 서버 구조 비교 |
| PowerNukkitX | https://github.com/PowerNukkitX/PowerNukkitX | Java 기반 Bedrock 서버 구조와 기능 비교 |
| Cloudburst Nukkit | https://github.com/CloudburstMC/Nukkit | Nukkit 계열 구조와 protocol update 참고 |
| NetherNet spec | https://github.com/df-mc/nethernet-spec | Bedrock transport 대체 가능성의 장기 연구 후보 |

## 8. AI와 서브 에이전트 설계 출처

| 출처 | 링크 | 계획에 반영한 내용 |
|---|---|---|
| OpenAI agent guide | https://openai.com/business/guides-and-resources/a-practical-guide-to-building-ai-agents/ | agent 구성, tool, guardrail, human intervention 기준 |
| OpenAI agent builder safety | https://platform.openai.com/docs/guides/agent-builder-safety | 고위험 작업의 안전장치와 정책 |
| OpenAI agent evals | https://platform.openai.com/docs/guides/agent-evals | agent 결과 평가와 회귀 방지 |
| Anthropic effective agents | https://www.anthropic.com/engineering/building-effective-agents | routing, parallelization, orchestrator-workers, evaluator-optimizer 패턴 |
| OWASP LLM Top 10 | https://owasp.org/www-project-top-10-for-large-language-model-applications | prompt injection, excessive agency, insecure output handling |
| NIST AI RMF | https://www.nist.gov/publications/artificial-intelligence-risk-management-framework-ai-rmf-10 | AI 위험 관리 프레임워크 |
| NIST SSDF | https://csrc.nist.gov/pubs/sp/800/218/final | 보안 소프트웨어 개발 기준 |
| GitHub Actions hardening | https://docs.github.com/actions/security-guides/security-hardening-for-github-actions | untrusted input, token permission, SHA pinning |
| GitHub code scanning | https://docs.github.com/en/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning | 정적 분석 운영 |
| GitHub Dependabot alerts | https://docs.github.com/en/code-security/dependabot/dependabot-alerts/about-dependabot-alerts | 의존성 취약점 감시 |
| GitHub secret scanning | https://docs.github.com/en/code-security/secret-scanning/introduction/about-push-protection | secret 유출 방지 |
| SLSA levels | https://slsa.dev/spec/v1.0/levels | supply-chain provenance와 build integrity |
| MCP security best practices | https://modelcontextprotocol.io/specification/2025-06-18/basic/security_best_practices | tool 연결 agent의 권한과 공격면 관리 |
| OpenTelemetry docs | https://opentelemetry.io/docs/ | metrics, logs, traces 기반 관측성 |
| Google SRE practical alerting | https://sre.google/resources/book-update/practical-alerting/ | 알림과 SLO 기반 운영 기준 |

## 9. 커뮤니티와 포럼 조사 후보

아래는 지속 조사 대상으로 둔다. 문서에 직접 결론을 넣을 때는 날짜와 원문 링크를 함께 기록한다.

| 채널 | 링크 | 조사 목적 |
|---|---|---|
| PMMP GitHub Issues | https://github.com/pmmp/PocketMine-MP/issues | 성능, 프로토콜, threading, chunk 관련 실제 논의 |
| PMMP GitHub Discussions | https://github.com/pmmp/PocketMine-MP/discussions | 운영자와 플러그인 개발자 요구 파악 |
| PMMP Discord | https://discord.gg/bmSAZBG | 최신 운영 이슈, 릴리즈 대응, 비공식 경험 수집 |
| Bedrock Wiki Discord/GitHub | https://wiki.bedrock.dev/ | Bedrock packet, resource pack, JSON UI 변경 추적 |
| PaperMC Discord/Docs | https://docs.papermc.io/ | Folia/Paper 운영 경험 참고 |
| FiveM community | https://forum.cfx.re/ | 대규모 entity routing과 OneSync 운영 사례 |
| Roblox DevForum | https://devforum.roblox.com/ | Actor, network ownership, 대규모 서버 scripting 사례 |
| Gaffer on Games | https://gafferongames.com/ | 게임 네트워크 serialization, snapshot, compression 글 |

## 10. 출처 사용 규칙

- 공식 PMMP, PHP, BedrockProtocol, PHP-Binaries 자료를 1순위로 둔다.
- 포럼, Discord, 커뮤니티 글은 힌트로만 사용하고, 코드 변경 전 로컬 benchmark로 검증한다.
- 논문과 타 서버 구현은 원리를 가져오되 PMMP PHP runtime과 plugin API 제약에 맞게 축소 적용한다.
- 성능 수치는 원문 수치를 그대로 목표로 삼지 않고, 같은 서버 설정과 같은 부하로 재측정한다.
- AI agent가 가져온 출처는 사람이 링크, 날짜, 주장 범위를 다시 확인한 뒤 계획에 반영한다.
