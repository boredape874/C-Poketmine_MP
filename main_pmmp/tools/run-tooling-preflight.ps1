param(
    [switch]$NoExitCode
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path

$scripts = @(
    "tools\run-fast-gates.ps1",
    "tools\run-source-baseline.ps1",
    "tools\analyze-baseline-log.ps1",
    "tools\continue-fast-progress.ps1",
    "tools\run-pending-phpstan.ps1",
    "tools\update-latest-progress.ps1",
    "tools\write-gate-summary-markdown.ps1",
    "tools\export-ai-handoff.ps1",
    "tools\diagnose-codex-shell.ps1",
    "tools\compare-baseline-runs.ps1",
    "tools\summarize-baseline-runs.ps1",
    "tools\audit-plugin-hotpaths.ps1",
    "tools\audit-production-readiness.ps1",
    "tools\summarize-production-evidence.ps1",
    "tools\write-production-deployment-status.ps1",
    "tools\collect-host-network-evidence.ps1",
    "tools\create-rollback-package.ps1",
    "tools\record-native-build-evidence.ps1",
    "tools\promote-staged-native-extension.ps1",
    "tools\run-post-native-promotion-validation.ps1",
    "tools\run-native-promotion-pipeline.ps1",
    "tools\check-native-promotion-pipeline-status.ps1",
    "tools\run-production-soak.ps1",
    "tools\check-production-soak-status.ps1",
    "tools\finalize-production-readiness-after-soak.ps1",
    "tools\start-production-finalizer-watcher.ps1",
    "tools\check-production-finalizer-status.ps1",
    "tools\run-bedrock-login-swarm.ps1",
    "tools\run-bedrock-login-swarm-gate.ps1",
    "tools\register-bedrock-login-swarm-evidence.ps1",
    "tools\register-production-plugins.ps1",
    "tools\check-native-extension-env.ps1",
    "tools\install-native-build-tools-windows.ps1",
    "tools\install-v142-build-tools-windows.ps1",
    "tools\build-native-extension-windows.ps1",
    "tools\patch-pe-linker-version.ps1",
    "tools\test-native-extension.ps1",
    "tools\bench-staged-native-hotpaths.ps1",
    "tools\run-staged-native-performance-gate.ps1"
)
$requiredFiles = @(
    "tools\hotpath-thresholds.json",
    "continue-fast-progress.cmd",
    "diagnose-codex-shell.cmd",
    "run-tooling-preflight.cmd",
    "run-pending-phpstan.cmd",
    "audit-production-readiness.cmd",
    "summarize-production-evidence.cmd",
    "write-production-deployment-status.cmd",
    "collect-host-network-evidence.cmd",
    "create-rollback-package.cmd",
    "record-native-build-evidence.cmd",
    "promote-staged-native-extension.cmd",
    "run-post-native-promotion-validation.cmd",
    "run-native-promotion-pipeline.cmd",
    "check-native-promotion-pipeline-status.cmd",
    "run-production-soak.cmd",
    "check-production-soak-status.cmd",
    "finalize-production-readiness-after-soak.cmd",
    "start-production-finalizer-watcher.cmd",
    "check-production-finalizer-status.cmd",
    "run-bedrock-login-swarm.cmd",
    "run-bedrock-login-swarm-gate.cmd",
    "register-bedrock-login-swarm-evidence.cmd",
    "register-production-plugins.cmd",
    "bench-staged-native-hotpaths.cmd",
    "run-staged-native-performance-gate.cmd",
    "..\pmmp-continue-fast-progress.cmd",
    "..\pmmp-diagnose-codex-shell.cmd",
    "..\pmmp-run-tooling-preflight.cmd",
    "..\pmmp-run-pending-phpstan.cmd",
    "..\pmmp-audit-production-readiness.cmd",
    "..\pmmp-summarize-production-evidence.cmd",
    "..\pmmp-write-production-deployment-status.cmd",
    "..\pmmp-collect-host-network-evidence.cmd",
    "..\pmmp-create-rollback-package.cmd",
    "..\pmmp-record-native-build-evidence.cmd",
    "..\pmmp-promote-staged-native-extension.cmd",
    "..\pmmp-run-post-native-promotion-validation.cmd",
    "..\pmmp-run-native-promotion-pipeline.cmd",
    "..\pmmp-check-native-promotion-pipeline-status.cmd",
    "..\pmmp-run-production-soak.cmd",
    "..\pmmp-check-production-soak-status.cmd",
    "..\pmmp-finalize-production-readiness-after-soak.cmd",
    "..\pmmp-start-production-finalizer-watcher.cmd",
    "..\pmmp-check-production-finalizer-status.cmd",
    "..\pmmp-run-bedrock-login-swarm.cmd",
    "..\pmmp-run-bedrock-login-swarm-gate.cmd",
    "..\pmmp-register-bedrock-login-swarm-evidence.cmd",
    "..\pmmp-register-production-plugins.cmd",
    "..\pmmp-bench-staged-native-hotpaths.cmd",
    "..\pmmp-run-staged-native-performance-gate.cmd",
    "..\README_PMMP_FAST.md"
)

$results = New-Object System.Collections.Generic.List[object]
$fileResults = New-Object System.Collections.Generic.List[object]
$ok = $true

foreach($relativePath in $scripts){
    $path = Join-Path $rootPath $relativePath
    if(-not (Test-Path -LiteralPath $path)){
        $ok = $false
        $results.Add([pscustomobject]@{
            path = $relativePath
            exists = $false
            parse_ok = $false
            errors = @("missing file")
        }) | Out-Null
        continue
    }

    $parseErrors = $null
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content -LiteralPath $path -Raw), [ref]$parseErrors)
    $errorMessages = @($parseErrors | ForEach-Object { $_.Message })
    if($errorMessages.Count -gt 0){
        $ok = $false
    }

    $results.Add([pscustomobject]@{
        path = $relativePath
        exists = $true
        parse_ok = $errorMessages.Count -eq 0
        errors = $errorMessages
    }) | Out-Null
}

foreach($relativePath in $requiredFiles){
    $path = Join-Path $rootPath $relativePath
    $exists = Test-Path -LiteralPath $path
    if(-not $exists){
        $ok = $false
    }
    $fileResults.Add([pscustomobject]@{
        path = $relativePath
        exists = $exists
    }) | Out-Null
}

[pscustomobject]@{
    root = $rootPath
    ok = $ok
    checked = $results.Count
    scripts = $results
    required_files = $fileResults
} | ConvertTo-Json -Depth 6

if(-not $ok -and -not $NoExitCode){
    exit 8
}
