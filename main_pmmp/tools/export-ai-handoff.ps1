param(
    [string]$OutputDir = "var/perf/ai-handoff",
    [int]$RecentRuns = 5
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$outRoot = Join-Path $root $OutputDir
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

$baselineRoot = Join-Path $root "var/perf/baseline"
$gateRoot = Join-Path $root "var/perf/gates"
$latestBaseline = if (Test-Path -LiteralPath $baselineRoot) {
    Get-ChildItem -LiteralPath $baselineRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
} else {
    $null
}
$latestGate = if (Test-Path -LiteralPath $gateRoot) {
    Get-ChildItem -LiteralPath $gateRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
} else {
    $null
}

$latestGateSummary = if ($latestGate -ne $null -and (Test-Path -LiteralPath (Join-Path $latestGate.FullName "gate-summary.json"))) {
    Get-Content -LiteralPath (Join-Path $latestGate.FullName "gate-summary.json") -Raw | ConvertFrom-Json
} else {
    $null
}
$latestBaselineSummary = if ($latestBaseline -ne $null -and (Test-Path -LiteralPath (Join-Path $latestBaseline.FullName "run-summary.json"))) {
    Get-Content -LiteralPath (Join-Path $latestBaseline.FullName "run-summary.json") -Raw | ConvertFrom-Json
} else {
    $null
}
$nativeEnvPath = Join-Path $root "var/perf/native/native-extension-env.json"
$nativeEnv = if (Test-Path -LiteralPath $nativeEnvPath) {
    Get-Content -LiteralPath $nativeEnvPath -Raw | ConvertFrom-Json
} else {
    $null
}

$scopedStatus = git -C (Split-Path $root -Parent) status --short -- `
    .gitignore `
    README_PMMP_FAST.md `
    *.cmd `
    main_pmmp/native `
    main_pmmp/*.cmd `
    main_pmmp/tools `
    main_pmmp/tools/hotpath-thresholds.json `
    main_pmmp/src/Server.php `
    main_pmmp/src/entity/AttributeMap.php `
    main_pmmp/src/entity/Entity.php `
    main_pmmp/src/entity/Human.php `
    main_pmmp/src/entity/Living.php `
    main_pmmp/src/entity/projectile/Projectile.php `
    main_pmmp/src/entity/projectile/SplashPotion.php `
    main_pmmp/src/entity/object/AreaEffectCloud.php `
    main_pmmp/src/entity/object/FallingBlock.php `
    main_pmmp/src/entity/object/FireworkRocket.php `
    main_pmmp/src/entity/object/Painting.php `
    main_pmmp/src/inventory/BaseInventory.php `
    main_pmmp/src/inventory/SimpleInventory.php `
    main_pmmp/src/network/mcpe/ChunkRequestTask.php `
    main_pmmp/src/network/mcpe/NetworkBroadcastUtils.php `
    main_pmmp/src/network/mcpe/StandardPacketBroadcaster.php `
    main_pmmp/src/network/mcpe/convert/ItemTranslator.php `
    main_pmmp/src/network/mcpe/handler/InGamePacketHandler.php `
    main_pmmp/src/network/mcpe/serializer/ChunkSerializer.php `
    main_pmmp/src/player/ChunkSelector.php `
    main_pmmp/src/player/Player.php `
    main_pmmp/src/player/SurvivalBlockBreakHandler.php `
    main_pmmp/src/world/Explosion.php `
    main_pmmp/src/world/World.php `
    main_pmmp/src/entity/object/ItemEntity.php `
    plan_md/CODEX_windows_sandbox_issue_2026-06-07.md `
    plan_md/PMMP_AI_parallel_execution_board.md `
    plan_md/PMMP_implementation_backlog.md `
    plan_md/PMMP_parallel_merge_protocol.md `
    plan_md/PMMP_lane_status_board.md `
    plan_md/PMMP_subagent_runs.md `
    plan_md/ai_tasks `
    plan_md

$recentSummary = & (Join-Path $PSScriptRoot "summarize-baseline-runs.ps1") -Limit $RecentRuns -Json | ConvertFrom-Json

$handoff = [pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    root = $root.Path
    latest_gate = $latestGateSummary
    latest_baseline = $latestBaselineSummary
    recent_baselines = $recentSummary
    native_env = $nativeEnv
    scoped_git_status = $scopedStatus
    next_commands = [ordered]@{
        continue_fast_progress = "powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\continue-fast-progress.ps1"
        continue_fast_progress_cmd = ".\continue-fast-progress.cmd"
        continue_fast_progress_root_cmd = "..\pmmp-continue-fast-progress.cmd"
        tooling_preflight = "powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-tooling-preflight.ps1"
        pending_phpstan = "powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-pending-phpstan.ps1 -IncludeTooling"
        shell_diagnostics = "powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\diagnose-codex-shell.ps1"
        update_latest_progress = "powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\update-latest-progress.ps1"
        write_gate_summary = "powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-gate-summary-markdown.ps1"
        fast_gate = "powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-fast-gates.ps1 -AcceptLgpl -Port 19132 -KoreanProfile"
        fast_gate_with_ping = "powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-fast-gates.ps1 -AcceptLgpl -Port 19132 -KoreanProfile -RunRakPingBurst"
        fast_gate_with_bench = "powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-fast-gates.ps1 -AcceptLgpl -Port 19132 -KoreanProfile -RunHotpathBench"
        plugin_audit = "powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\audit-plugin-hotpaths.ps1 -Markdown"
        native_env_check = "powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check-native-extension-env.ps1"
    }
    applied_core_areas = @(
        "network packet broadcast batching",
        "packet raw batch length reuse",
        "single packet raw batch helper for async chunk responses",
        "network session send buffer length reuse",
        "compression threshold and async batch prep",
        "compression batch length reuse and fixture bench",
        "chunk selection and chunk serialization",
        "subchunk serialization biome lookup and dictionary lazy path",
        "subchunk serialization hotpath fixture bench",
        "world block update and packet flush",
        "world block update packet creation and collision lookup",
        "world block update tile lookup avoidance",
        "block translator network state data cache",
        "block update packet hotpath fixture bench",
        "entity movement diff",
        "player nearby entity no-array iteration",
        "world colliding entity no-intermediate-array iteration",
        "world nearby/colliding entity boolean and callback helpers",
        "block placement and frost walker entity checks without result arrays",
        "projectile and falling block collision iteration without result arrays",
        "splash potion, area effect cloud, and firework collision iteration without result arrays",
        "world neighbor block updates, explosions, and painting overlap checks without result arrays",
        "chunk save and human drops direct loops without array helper chains",
        "player interaction and survival block break scalar distance checks",
        "entity movement and projectile rotation scalar square math",
        "attribute sync direct loop without array_filter closure",
        "entity spawn network attribute direct loop without array_map closure",
        "player death inventory clear direct slot loop and base inventory direct viewer iteration",
        "survival block break update local player and world caching",
        "survival block break mining progress hotpath fixture bench",
        "item entity merge candidate lazy allocation",
        "pending-change PHPStan preflight before fast gate",
        "pending PHPStan raw-output capture and fast-gate skip on preflight failure",
        "pending PHPStan NoExitCode mode for parent automation",
        "tooling JSON path output normalized to strings",
        "tooling preflight parser check before pending PHPStan and fast gate",
        "tooling preflight NoExitCode mode for parent automation",
        "tooling preflight required wrapper and threshold file checks",
        "CMD wrappers for fast validation and shell diagnostics",
        "root CMD wrappers for PMMP validation from repository root",
        "root fast-progress README with command map",
        "one-command fast gate compare progress update handoff automation",
        "progress updater markdown backtick interpolation fix",
        "gate markdown summary generation and optional bench field handling",
        "compare warning reason extraction for gate markdown summaries",
        "hotpath threshold warnings in gate markdown summaries",
        "configurable hotpath threshold JSON for gate summaries",
        "codex shell diagnostics for Windows sandbox spawn failures",
        "parallel AI execution board for PMMP performance work lanes",
        "ready-to-use AI task prompts for parallel PMMP work lanes",
        "complete AI task prompt set for lanes A through G",
        "priority implementation backlog and parallel merge protocol",
        "lane status board with done criteria and merge readiness",
        "subagent run log for delegated PMMP performance work",
        "item entity merge no-array iteration and pickup inventory cache",
        "player movement clone and scalar delta reduction",
        "player movement process hotpath fixture bench",
        "inventory addable quantity",
        "simple inventory add item direct-slot path",
        "packet encode hotpath fixture bench",
        "packet decode hotpath fixture bench",
        "packet pool lookup hotpath fixture bench",
        "packet pool direct lookup without getPacketById indirection",
        "item type network-id translation cache",
        "native extension PoC scaffold"
    )
    next_core_candidates = @(
        "Native extension build toolchain setup for PMMP PHP 8.2.30 ZTS on Windows",
        "Native extension benchmark wiring after build succeeds",
        "real packet decode fixture bench",
        "Player movement event fast-return audit for non-movement rotations",
        "Survival block break handler real-world micro-optimizations after mining fixture baseline",
        "real plugin hotpath fixes after plugins are added"
    )
}

$jsonPath = Join-Path $outRoot "handoff.json"
$mdPath = Join-Path $outRoot "handoff.md"
$handoff | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# PMMP AI Handoff") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("Generated: $($handoff.generated_at)") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("## Latest Gate") | Out-Null
if ($latestGateSummary -ne $null) {
    $lines.Add(('- gate: `{0}`' -f $latestGateSummary.gate_name)) | Out-Null
    $lines.Add(('- ready: `{0}`' -f $latestGateSummary.ready)) | Out-Null
    $lines.Add(('- ready seconds: `{0}`' -f $latestGateSummary.ready_seconds)) | Out-Null
    $lines.Add(('- fatal: `{0}`' -f $latestGateSummary.fatal_log_matches)) | Out-Null
    $lines.Add(('- phpstan: `{0}`' -f $latestGateSummary.phpstan_exit)) | Out-Null
    $lines.Add(('- rak ping: `{0}/{1}` loss `{2}%`' -f $latestGateSummary.rak_ping_received, $latestGateSummary.rak_ping_sent, $latestGateSummary.rak_ping_loss_percent)) | Out-Null
} else {
    $lines.Add("- none") | Out-Null
}
$lines.Add("") | Out-Null
$lines.Add("## Native Extension") | Out-Null
if ($nativeEnv -ne $null) {
    $lines.Add(('- PHP: `{0}` `{1}` on `{2}`' -f $nativeEnv.php_version, $nativeEnv.php_thread_safety, $nativeEnv.php_os_family)) | Out-Null
    $lines.Add(('- extension source: `{0}`' -f $nativeEnv.extension_dir)) | Out-Null
    $lines.Add(('- build ready: `{0}`' -f $nativeEnv.build_ready)) | Out-Null
    $lines.Add(('- cl/nmake/phpize: `{0}` / `{1}` / `{2}`' -f $nativeEnv.has_cl, $nativeEnv.has_nmake, $nativeEnv.has_phpize)) | Out-Null
    $lines.Add(('- missing files: `{0}`' -f (($nativeEnv.missing_extension_files | ForEach-Object { $_ }) -join ", "))) | Out-Null
} else {
    $lines.Add("- none") | Out-Null
}
$lines.Add("") | Out-Null
$lines.Add("## Next Commands") | Out-Null
foreach ($entry in $handoff.next_commands.GetEnumerator()) {
    $lines.Add(('- {0}: `{1}`' -f $entry.Key, $entry.Value)) | Out-Null
}
$lines.Add("") | Out-Null
$lines.Add("## Scoped Git Status") | Out-Null
foreach ($line in $scopedStatus) {
    $lines.Add(('- `{0}`' -f $line)) | Out-Null
}
$lines.Add("") | Out-Null
$lines.Add("## Next Core Candidates") | Out-Null
foreach ($candidate in $handoff.next_core_candidates) {
    $lines.Add("- $candidate") | Out-Null
}
$lines | Set-Content -LiteralPath $mdPath -Encoding UTF8

[pscustomobject]@{
    json = $jsonPath
    markdown = $mdPath
    latest_gate = if ($latestGateSummary -ne $null) { $latestGateSummary.gate_name } else { $null }
} | ConvertTo-Json -Depth 4
