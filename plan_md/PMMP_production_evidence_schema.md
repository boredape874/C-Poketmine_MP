# PMMP production evidence schema

## Authoritative current status

Updated: 2026-06-09 KST

The current production evidence directory is `main_pmmp/var/perf/production-evidence`. Fast-release evidence is complete. Strict production readiness is waiting for the active `7200s` soak `production-v142-strict-soak-20260609-195210` to finish cleanly and write matching `soak.json`.

Current high-performance native evidence:

- Live/staged DLL SHA256: `E646296549057876FE30E79CAE008EE79FBE5AF43403CDA0AAFFE696ED5777BB`.
- Compiler: VS2019/v142 MSVC `14.29.30133`.
- Evidence file: `native-v142-build.json`.
- Previous VS2019/v142 warning is cleared for the promoted DLL.

The sections below describe the evidence schema and generation commands. Any older run names in examples are historical examples, not the active release decision.

??臾몄꽌??`main_pmmp`??鍮좊Ⅸ ?깅뒫 寃뚯씠?몄? 蹂꾧컻濡? ?ㅼ꽌踰?諛고룷 ?먯젙???듦낵?쒗궎湲??꾪빐 ?꾩슂??利앷굅 ?뚯씪怨??앹꽦 紐낅졊???뺣━?쒕떎.

利앷굅 ?붾젆?곕━:

```text
main_pmmp/var/perf/production-evidence
```

媛먯궗 紐낅졊:

```bat
pmmp-audit-production-readiness.cmd -Markdown -NoExitCode
```

?꾩껜 利앷굅 ?붿빟:

```bat
pmmp-summarize-production-evidence.cmd
pmmp-summarize-production-evidence.cmd -Markdown
pmmp-write-production-deployment-status.cmd -Markdown
```

## production-plugins.json

紐⑹쟻: ?ㅼ젣 ?댁쁺 ?뚮윭洹몄씤 ?명듃媛 `main_pmmp/plugins`???깅줉?섏뼱 ?덉쓬??利앸챸?쒕떎.

?앹꽦 紐낅졊:

```bat
pmmp-register-production-plugins.cmd -SourceDir C:\path\to\plugins-source -Copy
```

?쒖닔 ?쇱깮/臾댄뵆?ш렇???댁쁺 ?좎뼵:

```bat
pmmp-register-production-plugins.cmd -NoProductionPlugins
```

?듦낵 議곌굔:

- `main_pmmp/plugins` ?꾨옒???ㅼ젣 ?댁쁺 PHP ?뚮윭洹몄씤 ?뚯뒪 ?먮뒗 `.phar`媛 ?덉뼱???쒕떎.
- ?깅줉 ?뚯뒪 ?덉뿉 `plugin.yml` ?먮뒗 `.phar`媛 ?덉뼱???쒕떎.
- ?깅줉 ?뚯뒪 ?덉뿉 `.php` ?먮뒗 `.phar`媛 ?덉뼱???쒕떎.
- ?덉젣 ?뚮윭洹몄씤, ?뚯뒪???뚮윭洹몄씤, `ChunkCacheProbe`???댁쁺 ?뚮윭洹몄씤 利앷굅濡??곗? ?딅뒗??
- ?깅줉 ?꾧뎄??`examples/plugins`, `tests/plugins`, `var/perf/baseline` 寃쎈줈? `ExamplePlugin`, `TesterPlugin`, `DevTools`, `ChunkCacheProbe` ?대쫫??湲곕낯 李⑤떒?쒕떎.
- `-AllowExampleOrTestPlugins`??鍮꾩슫??媛먯궗 ?ㅽ뿕?⑹씠硫? ?ㅼ꽌踰?諛고룷 利앷굅?먮뒗 ?곗? ?딅뒗??
- `-NoProductionPlugins`???섎룄?곸씤 臾댄뵆?ш렇??諛고룷留??좎뼵?쒕떎. 媛먯궗??`main_pmmp/plugins`媛 鍮꾩뼱 ?덉쓣 ?뚮쭔 ??利앷굅瑜??몄젙?쒕떎.

?꾩옱 ?곹깭:

- workspace?먮뒗 PMMP ?덉젣/?뚯뒪???뚮윭洹몄씤留??덇퀬 ?ㅼ젣 ?댁쁺 ?뚮윭洹몄씤 ?명듃媛 ?녿떎.
- ?쒖닔 ?쇱깮/臾댄뵆?ш렇???쒕쾭濡?諛고룷??寃쎌슦 `-NoProductionPlugins` 利앷굅瑜??깅줉?섎㈃ ?쒕떎.

## bedrock-login-swarm.json

紐⑹쟻: ?ㅼ젣 Bedrock ?꾨줈?좎퐳 ?대씪?댁뼵?멸? ??됱쑝濡?濡쒓렇?명븯怨?泥?겕 以鍮??곹깭源뚯? ?꾨떖?⑥쓣 利앸챸?쒕떎.

?듯빀 gate 紐낅졊:

```bat
pmmp-run-bedrock-login-swarm-gate.cmd -AcceptLgpl -Players 400 -DurationSeconds 60 -ServerDurationSeconds 360 -RegisterEvidence
```

?몃? 寃곌낵 ?깅줉 紐낅졊:

```bat
pmmp-register-bedrock-login-swarm-evidence.cmd -InputJson C:\path\to\real-swarm-result.json
```

?듦낵 議곌굔:

- attempted players `>= 400`
- successful logins `>= 400`
- chunk-ready players `>= 400`
- disconnects `0`
- fatal log matches `0`
- duration seconds `>= 60`
- loss percent `<= 10.0`

?꾩옱 ?곹깭:

- `bedrock-login-swarm.json` ?깅줉 ?꾨즺.
- 400紐??듯빀 ?ㅼ썫 ?듦낵: attempted `400`, successful logins `400`, chunk-ready `400`, disconnects `0`, fatal `0`, loss `0%`.
- `skip_ping=true`??濡쒓렇??泥?겕 遺?섎? ?묒냽 ??server-list ping ??＜? 遺꾨━?섍린 ?꾪븳 ?섎꽕???듭뀡?대떎.

## soak.json

紐⑹쟻: ?쒕쾭媛 ?μ떆媛??덉젙?곸쑝濡??좎??⑥쓣 利앸챸?쒕떎.

?ㅽ뻾 紐낅졊:

```bat
pmmp-run-production-soak.cmd -AcceptLgpl -DurationSeconds 7200 -RunRakPingBurst
```

?곹깭 ?뺤씤:

```bat
pmmp-check-production-soak-status.cmd
```

?꾨즺 ??媛먯궗/?붿빟 留덈Т由?

```bat
pmmp-finalize-production-readiness-after-soak.cmd -NoExitCode
pmmp-start-production-finalizer-watcher.cmd -NoExitCode
pmmp-check-production-finalizer-status.cmd
```

?듦낵 議곌굔:

- ?쒕쾭 ready ?곹깭 ?꾨떖
- fatal/error log matches `0`
- PMMP process exit code `0`
- failure reasons empty
- duration seconds `>= 7200`
- `-RunRakPingBurst` ?ъ슜 ??Rak ping `>= 400`, loss percent `<= 10.0`

?꾩옱 ?곹깭:

- `production-soak-20260608-220444`媛 ?ы듃 `19153`?먯꽌 諛깃렇?쇱슫???ㅽ뻾 以묒씠??
- ?쒖옉 ??ready `1.602s`, ?꾩옱 fatal/error matches `0`.
- ?꾨즺 ?꾧퉴吏 `production.soak` blocker???⑤뒗??

## native-v142-build.json

紐⑹쟻: Windows ?앹궛 諛고룷???ㅼ씠?곕툕 ?뺤옣??VS2019/v142 怨꾩뿴 MSVC濡?鍮뚮뱶?섏뿀?뚯쓣 利앸챸?쒕떎.

愿??紐낅졊:

```bat
pmmp-record-native-build-evidence.cmd
```

v142 ?ㅼ튂媛 ?꾩슂????

```powershell
.\main_pmmp\tools\install-v142-build-tools-windows.ps1 -Elevate
.\main_pmmp\tools\build-native-extension-windows.ps1 -PreferVs16 -CopyToPhpExt
.\pmmp-record-native-build-evidence.cmd
```

?꾩옱 ?곹깭:

- ?꾩옱 濡쒖뺄 ?ㅼ씠?곕툕 利앷굅??`native-local-build.json`?대떎.
- ?ㅼ튂??MSVC toolset? `14.50.35717`?대ŉ v142媛 ?꾨땲??
- ??利앷굅???꾩옱 DLL ?곹깭瑜?湲곕줉?섏?留?`production.native_v142` warning???쒓굅?섏? ?딅뒗??

## rollback-package.json

紐⑹쟻: ?ㅼ씠?곕툕 ?뺤옣 臾몄젣媛 ?앷꼈????諛붾줈 ?꾧굅???섎룎由????덉쓬??利앸챸?쒕떎.

?앹꽦 紐낅졊:

```bat
pmmp-create-rollback-package.cmd
```

?꾩옱 ?곹깭:

- rollback evidence???앹꽦?섏뼱 ?덉쑝硫??꾩옱 production audit blocker媛 ?꾨땲??

## host-network.json

紐⑹쟻: ?ㅼ젣 諛고룷 癒몄떊??UDP/firewall/NIC ?곹깭瑜?湲곕줉?쒕떎.

?앹꽦 紐낅졊:

```bat
pmmp-collect-host-network-evidence.cmd
```

?꾩옱 ?곹깭:

- 濡쒖뺄 癒몄떊 湲곗? host network evidence???앹꽦?섏뼱 ?덈떎.
- 理쒖쥌 怨듦컻 ?쒕쾭?먯꽌???ㅼ젣 諛고룷 ?몄뒪?몄뿉??媛숈? 紐낅졊???ㅼ떆 ?ㅽ뻾?댁빞 ?쒕떎.

