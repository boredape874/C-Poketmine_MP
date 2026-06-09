# PMMP Git 구조 상태 - 2026-06-08

## 현재 구조

PMMP 본체는 루트가 아니라 `main_pmmp/` 안에 둔다.

```text
C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
```

루트 `C-Poketmine_MP`는 작업 허브다. 루트에는 실행 래퍼(`pmmp-*.cmd`), 계획 문서(`plan_md/`), 요약 문서(`README_PMMP_FAST.md`)를 둔다.

## 해결한 GitHub Desktop 경로 문제

원인은 세 가지였다.

1. 기존 Git 인덱스가 PMMP 파일을 루트 위치(`src/`, `resources/`, `composer.json` 등)로 추적하고 있었다.
2. 실제 파일은 `main_pmmp/` 안으로 이동했지만, Git 인덱스에는 아직 이동이 반영되지 않아 대량 삭제와 대량 새 파일로 보였다.
3. `.gitmodules`와 submodule 내부 `.git` 포인터가 예전 루트 경로를 가리켜 `git submodule status`가 실패했다.

현재 조치:

- `.gitmodules` 경로를 `main_pmmp/build/php`, `main_pmmp/examples/plugins/ExamplePlugin`, `main_pmmp/tests/plugins/DevTools`로 변경했다.
- submodule 내부 `.git` 포인터와 로컬 `core.worktree`를 새 위치 기준으로 수정했다.
- Git 인덱스에서 PMMP 파일 이동을 stage해 `old -> main_pmmp/old` rename으로 인식되게 했다.
- `main_pmmp/bin`, `main_pmmp/vendor`, `main_pmmp/var/perf`, `main_pmmp/var/native-build`는 Git 추적 대상에서 제외했다.

## 현재 검증 결과

- `git submodule status`: 정상
- `main_pmmp/bin`, `main_pmmp/vendor`, `main_pmmp/var/native-build`: staged 항목 없음
- `main_pmmp/tools/run-tooling-preflight.ps1`: 통과
- `pmmp-audit-production-readiness.cmd`: 실행 정상, 배포 증거 부족으로 `not_ready`

## 아직 남은 배포 blocker

코드 실행 오류가 아니라 실서버 증거 부족이다.

- `production.plugins`: 실제 배포 플러그인 등록 증거 없음
- `production.bedrock_login_swarm`: 400명 실제 Bedrock 로그인/청크 요청 스웜 증거 없음
- `production.soak`: 2시간 이상 soak 증거 없음

경고:

- `production.native_v142`: VS2019/v142 네이티브 빌드 증거 없음

## 주의

`git checkout -- .` 또는 `git reset --hard`로 루트를 되돌리면 `main_pmmp` 구조 전환과 지금까지의 최적화 작업이 깨질 수 있다. 되돌릴 필요가 있으면 먼저 어떤 범위를 되돌릴지 파일 단위로 확인해야 한다.
