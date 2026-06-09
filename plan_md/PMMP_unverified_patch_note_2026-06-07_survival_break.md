# PMMP Unverified Patch Note - Survival Block Break

작성일: 2026-06-07

## 현재 상태

Codex Windows shell이 `windows sandbox: spawn setup refresh` 오류로 중단되어 `Get-Content`, PHPStan, fast gate를 실행하지 못하는 상태다. 외부 승인은 사용자가 원하지 않았으므로 요청하지 않았다.

마지막으로 확인된 fast gate는 `20260607-152009`이며, 그 이후 변경은 검증 대기 상태다.

## 적용된 것으로 확인된 작업

- `SurvivalBlockBreakHandler` 생성자에서 `breakSpeed` 계산 뒤 `player/world` 지역 변수를 사용해 `BLOCK_START_BREAK` 패킷을 브로드캐스트하도록 정리했다.
- `SurvivalBlockBreakHandler::calculateBreakProgressPerTick()`에서 반복되는 `$this->player` 접근 일부를 `$player` 지역 변수로 줄였다.
- `SurvivalBlockBreakHandler::__destruct()`에서 `$player`와 `$world` 지역 변수를 사용해 terrain 확인과 packet broadcast의 반복 체인을 줄였다.
- `ItemEntity` merge scan은 merge 후보가 있을 때만 `$mergeable` 배열을 생성하도록 바꿨다.
- `Player`, `BaseInventory`, `Entity`, `AttributeMap`의 반복 hotpath에서 불필요한 배열 생성 또는 반복 API 호출을 줄였다.

## 남은 작업

셸 또는 파일 읽기 권한이 정상화되면 다음을 확인하고 이어서 적용한다.

- `main_pmmp/src/player/SurvivalBlockBreakHandler.php`
  - `update()` FX 블록에서 `$world = $player->getWorld();` 캐싱 후 particle/sound 호출에 재사용
  - `ArmSwingAnimation` 생성자와 `getViewers()` 호출에 이미 캐싱된 `$player` 사용
  - `calculateBreakProgressPerTick()`와 `__destruct()`는 문법 검증과 PHPStan 확인 필요

## 검증 명령

셸이 복구되면 저장소 루트에서 다음을 실행한다.

```powershell
.\pmmp-continue-fast-progress.cmd
```

또는 `main_pmmp` 폴더에서:

```powershell
.\continue-fast-progress.cmd
```
