# PMMP 고성능 구현 출처 정리

이 문서는 `pasted-text.txt`에 포함된 자료 링크를 고성능 PMMP 구현 검토용으로 분류한 출처 목록이다.

## 1. PMMP 공식 및 핵심 저장소

| 구분 | 출처 | 용도 |
|---|---|---|
| PMMP 본체 | https://github.com/pmmp/pocketmine-mp | PMMP 코어 구조, 릴리즈, 코드 기준점 |
| PMMP 릴리즈 | https://github.com/pmmp/PocketMine-MP/releases | 최신 stable, Bedrock 지원 버전, 변경 내역 확인 |
| PMMP 빌드 문서 | https://github.com/pmmp/PocketMine-MP/blob/stable/BUILDING.md | PMMP 소스 빌드, PHP 바이너리, Composer 환경 기준 |
| PMMP 기본 설정 | https://github.com/pmmp/PocketMine-MP/blob/stable/resources/pocketmine.yml | 성능 관련 기본 설정, 운영 옵션 확인 |
| PMMP changelog 4.0 | https://github.com/pmmp/PocketMine-MP/blob/stable/changelogs/4.0.md | 구조 변화, 성능 개선 히스토리 참고 |
| PMMP 공식 사이트 | https://pmmp.io | 프로젝트 공식 진입점 |
| PMMP 설치 요구사항 | https://doc.pmmp.io/en/rtfd/installation/requirements.html | PMMP 실행 요구사항, PHP 버전, OS 권장사항 |
| PMMP API 문서 | https://apidoc.pmmp.io/de/d8c/classpocketmine_1_1timings_1_1_timings.html | Timings 계측 구조 확인 |
| PMMP dev API 문서 | https://apidoc-dev.pmmp.io | 개발 브랜치 API 확인 |

## 2. PMMP PHP 바이너리와 네이티브 확장

| 구분 | 출처 | 용도 |
|---|---|---|
| PHP-Binaries | https://github.com/pmmp/PHP-Binaries/releases | PMMP용 커스텀 PHP 바이너리, ext 구성, PHP 8.2 기준 확인 |
| php-build-scripts | https://github.com/pmmp/php-build-scripts/blob/master/compile.sh | PMMP PHP 바이너리 빌드 체인 분석 |
| ext-pmmpthread 이슈 | https://github.com/pmmp/ext-pmmpthread/issues/42 | Threaded 객체, RakLib thread, 큐/락 병목 분석 |
| ext-chunkutils2 | https://github.com/pmmp/ext-chunkutils2 | 청크 hot path 네이티브화 참고 |
| ext-libdeflate | https://github.com/pmmp/ext-libdeflate | 패킷 압축 성능 개선 참고 |
| ext-libdeflate 릴리즈 | https://github.com/pmmp/ext-libdeflate/releases | 배포 버전과 바이너리 호환성 확인 |

## 3. PMMP 이슈와 병목 사례

| 구분 | 출처 | 용도 |
|---|---|---|
| PMMP issue 1161 | https://github.com/pmmp/PocketMine-MP/issues/1161 | PMMP 성능/구조 관련 과거 논의 확인 |
| PMMP issue 5750 | https://github.com/pmmp/PocketMine-MP/issues/5750 | chunk, worker, runtime 병목 사례 참고 |
| PMMP issue 6294 | https://github.com/pmmp/PocketMine-MP/issues/6294 | 운영/성능 관련 논의 참고 |

## 4. Bedrock 프로토콜과 서버 네트워크

| 구분 | 출처 | 용도 |
|---|---|---|
| Mojang Bedrock protocol docs | https://github.com/Mojang/bedrock-protocol-docs/ | 공식 Bedrock 프로토콜 변경 추적 |
| Bedrock 샘플 | https://mojang.github.io/bedrock-samples/ | 공식 Bedrock 데이터/애드온 샘플 참고 |
| Bedrock Wiki RakNet | https://wiki.bedrock.dev/servers/raknet | Bedrock RakNet 구조 이해 |
| Bedrock Wiki 서버 프로토콜 | https://wiki.bedrock.dev/servers/bedrock | 로그인, 패킷 흐름, 서버 연결 참고 |
| PMMP RakLib | https://github.com/pmmp/RakLib | PMMP RakNet 구현체 분석 |
| NetherNet spec | https://github.com/df-mc/nethernet-spec | NetherNet 가능성과 한계 검토 |

## 5. 대체 Bedrock 구동기

| 구분 | 출처 | 용도 |
|---|---|---|
| Dragonfly | https://github.com/df-mc/dragonfly | Go 기반 비동기 Bedrock 서버 구조 비교 |
| PowerNukkitX | https://github.com/PowerNukkitX/PowerNukkitX | Java 기반 Bedrock 서버 기능/구조 비교 |
| Cloudburst Nukkit | https://github.com/cloudburstmc/nukkit | Nukkit 계열 업데이트 방식과 Java 구조 비교 |
| Cloudburst Nukkit 대체 표기 | https://github.com/CloudburstMC/Nukkit | 동일 계열 저장소 표기 확인 |
| PMMP Android 빌드 | https://github.com/Frago9876543210/PocketMine-MP-Android/releases | 비공식 Android PMMP 빌드 참고, 핵심 설계 출처로는 낮은 우선순위 |

## 6. Java 서버 병렬화와 대규모 서버 구조

| 구분 | 출처 | 용도 |
|---|---|---|
| Folia overview | https://docs.papermc.io/folia/reference/overview/ | regionized multithreading 구조 참고 |
| Folia FAQ | https://docs.papermc.io/folia/faq/ | Folia 운영 조건, 병렬 tick 제약 참고 |
| Folia region logic | https://docs.papermc.io/folia/reference/region-logic/ | region ownership, tick scheduling 참고 |
| MultiPaper 구조 | https://multipaper.io/multipaper/how-it-works.html | 다중 서버 월드 분산 구조 참고 |
| FiveM OneSync | https://docs.fivem.net/docs/scripting-reference/onesync/ | interest management, entity routing, 대규모 동접 구조 참고 |
| Roblox network ownership | https://roblox.com | 클라이언트/서버 물리 소유권 분산 개념 참고 |

## 7. PHP 런타임과 메모리 모델

| 구분 | 출처 | 용도 |
|---|---|---|
| PHP 공식 사이트 | http://php.net | PHP 런타임 공식 자료 진입점 |
| PHP GC refcounting | https://www.php.net/manual/en/features.gc.refcounting-basics.php | zval, refcount, copy-on-write, GC 비용 이해 |
| PHP JIT RFC | https://wiki.php.net/rfc/jit | JIT 기대효과와 한계 판단 |
| pthreads | https://github.com/krakjoe/pthreads | PHP threading 역사와 제약 참고 |

## 8. 병렬 처리와 큐 연구 자료

| 구분 | 출처 | 용도 |
|---|---|---|
| Michael-Scott Queue 논문 | https://www.cs.rochester.edu/~scott/papers/1996_PODC_queues.pdf | lock-free queue 설계 참고 |
| SEDA 논문 | https://pages.cs.wisc.edu/~remzi/Classes/739/Fall2018/Papers/SEDA-sosp.pdf | staged event-driven architecture 참고 |
| Actor model | https://en.wikipedia.org/wiki/Actor_model | actor/ownership 기반 설계 개념 참고 |

## 9. 공식 BDS와 운영 비교

| 구분 | 출처 | 용도 |
|---|---|---|
| Bedrock Dedicated Server 시작 문서 | https://learn.microsoft.com/en-us/minecraft/creator/documents/bedrockserver/getting-started?view=minecraft-bedrock-stable | 공식 BDS 운영 모델, PMMP와 비교 |

## 10. 검토 필요 또는 낮은 우선순위 자료

아래 링크는 TXT에 포함되어 있으나 PMMP 고성능 구현의 1차 근거로 쓰기에는 부적합하거나, 문맥상 검색 결과 노이즈일 가능성이 높다.

| 출처 | 판단 |
|---|---|
| https://republic.lnk.to/https://republic.lnk.to/JuliaMichaelsIssuesYD | 음악 링크로 보이며 PMMP와 무관 |
| https://republic.lnk.to/JuliaMichaelsIssuesYD | 음악 링크로 보이며 PMMP와 무관 |
| https://www.reddit.com/r/linuxquestions/comments/prmenu/comment/hdjy55z/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_co | 운영체제 스케줄링 참고 가능성은 있으나 1차 근거로 낮음 |
| https://www.spigotmc.org/resources/speedlimit.75269/ | Java 서버 플러그인 자료로 PMMP 코어 설계 근거로 낮음 |
| https://tom-doerr.github.io | Folia 관련 2차 요약 자료로 보이며 공식 Folia 문서보다 우선순위 낮음 |
| https://linkedin.com | Roblox/Hedera 관련 기사성 자료로 PMMP 구현 근거로 낮음 |
| https://esx-framework.org | FiveM ESX 프레임워크 자료로 OneSync 공식 문서보다 우선순위 낮음 |
| https://supercraft.host | 호스팅 업체 블로그성 자료로 낮은 우선순위 |
| https://abrhosting.com | 호스팅 업체 블로그성 자료로 낮은 우선순위 |
| https://spotify.com | 음악 서비스 링크로 PMMP와 무관 |

## 출처 사용 우선순위

1. PMMP 공식 저장소, PMMP 공식 문서, PMMP 확장 저장소
2. Mojang/Microsoft 공식 Bedrock 문서
3. Bedrock Wiki와 PMMP API 문서
4. Dragonfly, Cloudburst, PowerNukkitX 등 대체 구동기 공식 저장소
5. Folia, MultiPaper, FiveM, Roblox 등 구조 참고용 공식 문서
6. 논문과 런타임 문서
7. 블로그, 포럼, Reddit, 호스팅 업체 글은 보조 참고로만 사용
