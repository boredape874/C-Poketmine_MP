param(
    [int]$Port = 19132,
    [int]$DurationSeconds = 30,
    [switch]$RunRakPingBurst,
    [switch]$SkipFastGate,
    [switch]$SkipHandoff
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$baselineRoot = Join-Path $rootPath "var/perf/baseline"
$gateRoot = Join-Path $rootPath "var/perf/gates"

function Get-LatestDirectory([string]$Path){
    if(Test-Path -LiteralPath $Path){
        Get-ChildItem -LiteralPath $Path -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }else{
        $null
    }
}

function Get-RunNameFromPath($Directory){
    if($Directory -eq $null){
        return $null
    }
    return $Directory.Name
}

Push-Location $root
try{
    $beforeBaseline = Get-LatestDirectory $baselineRoot

    $result = [ordered]@{
        root = $rootPath
        before_baseline = Get-RunNameFromPath $beforeBaseline
        tooling_preflight = $null
        pending_phpstan = $null
        fast_gate = $null
        compare = $null
        progress = $null
        gate_markdown = $null
        production_readiness = $null
        handoff = $null
        note = $null
    }

    if(-not $SkipFastGate){
        $toolingPreflightJson = & (Join-Path $PSScriptRoot "run-tooling-preflight.ps1") -NoExitCode
        $result.tooling_preflight = $toolingPreflightJson | ConvertFrom-Json
        if(-not [bool]$result.tooling_preflight.ok){
            $result.note = "Tooling preflight failed; pending PHPStan and fast gate skipped."
            [pscustomobject]$result | ConvertTo-Json -Depth 12
            exit 9
        }

        $pendingPhpStanJson = & (Join-Path $PSScriptRoot "run-pending-phpstan.ps1") -IncludeTooling -NoExitCode
        $result.pending_phpstan = $pendingPhpStanJson | ConvertFrom-Json
        if($result.pending_phpstan.phpstan_exit -ne 0){
            $result.note = "Pending PHPStan failed; fast gate skipped. Inspect pending_phpstan.output."
            [pscustomobject]$result | ConvertTo-Json -Depth 12
            exit 10
        }

        $gateParams = @{
            AcceptLgpl = $true
            Port = $Port
            DurationSeconds = $DurationSeconds
            KoreanProfile = $true
            RunHotpathBench = $true
        }
        if($RunRakPingBurst){
            $gateParams.RunRakPingBurst = $true
        }

        $gateJson = & (Join-Path $PSScriptRoot "run-fast-gates.ps1") @gateParams
        $gate = $gateJson | ConvertFrom-Json
        $result.fast_gate = $gate

        $afterBaseline = if($gate.baseline_dir -ne $null -and (Test-Path -LiteralPath $gate.baseline_dir)){
            Get-Item -LiteralPath $gate.baseline_dir
        }else{
            Get-LatestDirectory $baselineRoot
        }

        if($beforeBaseline -ne $null -and $afterBaseline -ne $null -and $beforeBaseline.FullName -ne $afterBaseline.FullName){
            $compareJson = & (Join-Path $PSScriptRoot "compare-baseline-runs.ps1") -BaseRun $beforeBaseline.FullName -CandidateRun $afterBaseline.FullName
            $result.compare = $compareJson | ConvertFrom-Json
            $comparePath = if($gate.gate_root -ne $null -and (Test-Path -LiteralPath $gate.gate_root)){
                Join-Path $gate.gate_root "compare-summary.json"
            }else{
                Join-Path $gateRoot "latest-compare.json"
            }
            $compareJson | Set-Content -LiteralPath $comparePath -Encoding UTF8
            $progressJson = & (Join-Path $PSScriptRoot "update-latest-progress.ps1") -CompareJsonPath $comparePath
            $result.progress = $progressJson | ConvertFrom-Json
            $summaryJson = & (Join-Path $PSScriptRoot "write-gate-summary-markdown.ps1") -GateDir $gate.gate_root -CompareJsonPath $comparePath
            $result.gate_markdown = $summaryJson | ConvertFrom-Json
        }else{
            $result.note = "Baseline compare skipped because no distinct previous/candidate baseline was found."
            $progressJson = & (Join-Path $PSScriptRoot "update-latest-progress.ps1")
            $result.progress = $progressJson | ConvertFrom-Json
            if($gate.gate_root -ne $null -and (Test-Path -LiteralPath $gate.gate_root)){
                $summaryJson = & (Join-Path $PSScriptRoot "write-gate-summary-markdown.ps1") -GateDir $gate.gate_root
                $result.gate_markdown = $summaryJson | ConvertFrom-Json
            }
        }

        if($gate.gate_root -ne $null -and (Test-Path -LiteralPath $gate.gate_root)){
            $productionReadinessJson = & (Join-Path $PSScriptRoot "audit-production-readiness.ps1") -GateDir $gate.gate_root -Markdown -NoExitCode
            $result.production_readiness = $productionReadinessJson | ConvertFrom-Json
        }
    }

    if(-not $SkipHandoff){
        $handoffJson = & (Join-Path $PSScriptRoot "export-ai-handoff.ps1")
        $result.handoff = $handoffJson | ConvertFrom-Json
    }

    [pscustomobject]$result | ConvertTo-Json -Depth 12
}finally{
    Pop-Location
}
