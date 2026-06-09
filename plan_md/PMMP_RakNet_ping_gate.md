# PMMP RakNet Ping Gate

작성일: 2026-06-07

## 명령

```powershell
cd C:\Users\champ\OneDrive\문서\개발\C-Poketmine_MP\main_pmmp
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-fast-gates.ps1 -AcceptLgpl -Port 19132 -KoreanProfile -RunRakPingBurst
```

## 최신 결과

- gate: `20260607-030625`
- ready: true
- ready seconds: 2.137
- fatal matches: 0
- PHPStan exit: 0
- process samples: 15
- max working set: 330.098 MB
- max private memory: 326.598 MB
- max threads: 16
- max handles: 488
- rak ping sent: 64
- rak ping received: 64
- rak ping loss: 0%
- rak ping min latency: 26.762 ms
- rak ping avg latency: 27.099 ms
- rak ping max latency: 27.477 ms
- compare verdict: pass

## 의미

이 gate는 실제 Bedrock 클라이언트 로그인 부하는 아니지만, 서버가 ready 된 직후 UDP/RakNet unconnected ping에 응답하는지 빠르게 확인한다. 400명 검증 전 단계에서 포트 바인딩, 네트워크 루프, 초기 응답 손실을 빠르게 잡는 용도다.
