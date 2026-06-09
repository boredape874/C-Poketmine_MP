param(
    [int]$Port = 19140,
    [int]$Players = 1,
    [int]$DurationSeconds = 10,
    [int]$ServerDurationSeconds = 45,
    [int]$ReadyTimeoutSeconds = 30,
    [int]$RampMs = 25,
    [string]$SkipPing = "true",
    [switch]$Install,
    [switch]$RegisterEvidence,
    [switch]$AcceptLgpl
)

$ErrorActionPreference = "Stop"

if(-not $AcceptLgpl){
    throw "LGPL license acceptance is required. Re-run with -AcceptLgpl after you have accepted the LICENSE in this PMMP directory."
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runName = "bedrock-swarm-gate-$stamp"
$profileDir = & (Join-Path $PSScriptRoot "create-400-wild-profile.ps1") -OutputDir "var/perf/profiles/$runName" -Port $Port -OfflineAuth
$baselineOut = Join-Path $rootPath "var/perf/baseline/$runName-wrapper-stdout.log"
$baselineErr = Join-Path $rootPath "var/perf/baseline/$runName-wrapper-stderr.log"
$baselineScript = Join-Path $PSScriptRoot "run-source-baseline.ps1"
$evidenceRoot = Join-Path $rootPath "var/perf/production-evidence"
$rawResult = Join-Path $evidenceRoot "bedrock-login-swarm-raw-$stamp.json"
$swarmDir = Join-Path $PSScriptRoot "bedrock-swarm"
New-Item -ItemType Directory -Force -Path (Split-Path $baselineOut -Parent), $evidenceRoot | Out-Null

$baselineArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$baselineScript`"",
    "-AcceptLgpl",
    "-Port", "$Port",
    "-DurationSeconds", "$ServerDurationSeconds",
    "-RunName", "$runName",
    "-ProfileDir", "`"$profileDir`"",
    "-RunChunkCacheProbe"
)
$baselineProcess = Start-Process -FilePath "powershell.exe" -ArgumentList $baselineArgs -WorkingDirectory $rootPath -WindowStyle Hidden -PassThru -RedirectStandardOutput $baselineOut -RedirectStandardError $baselineErr
$baselineDir = Join-Path $rootPath "var/perf/baseline/$runName"
$serverLog = Join-Path $baselineDir "data/server.log"
$ready = $false
$startedAt = Get-Date

try{
    while((Get-Date) -lt $startedAt.AddSeconds($ReadyTimeoutSeconds)){
        if($baselineProcess.HasExited){
            break
        }
        if(Test-Path -LiteralPath $serverLog){
            $tail = Get-Content -LiteralPath $serverLog -Tail 80 -ErrorAction SilentlyContinue
            if(($tail -join "`n") -match "Done|Server started|Minecraft network interface|0\.0\.0\.0:$Port"){
                $ready = $true
                break
            }
        }
        Start-Sleep -Milliseconds 500
    }

    if($ready){
        if($Install){
            Push-Location $swarmDir
            try{
                npm install
            }finally{
                Pop-Location
            }
        }
        if(-not (Test-Path -LiteralPath (Join-Path $swarmDir "node_modules/bedrock-protocol/package.json"))){
            throw "Missing bedrock-swarm node dependencies. Re-run with -Install."
        }
        Push-Location $swarmDir
        try{
            node .\swarm.js "--host=127.0.0.1" "--port=$Port" "--players=$Players" "--duration=$DurationSeconds" "--ramp-ms=$RampMs" "--skip-ping=$($SkipPing.ToLowerInvariant())" "--out=$rawResult"
            $swarmExit = $LASTEXITCODE
        }finally{
            Pop-Location
        }
        if($RegisterEvidence -and (Test-Path -LiteralPath $rawResult)){
            & (Join-Path $PSScriptRoot "register-bedrock-login-swarm-evidence.ps1") -InputJson $rawResult -TargetPlayers $Players
            $swarmExit = $LASTEXITCODE
        }
    }else{
        $swarmExit = 31
    }
}finally{
    if(-not $baselineProcess.HasExited){
        $remaining = [Math]::Max(1, [Math]::Min(15, $ServerDurationSeconds))
        if(-not $baselineProcess.WaitForExit($remaining * 1000)){
            Stop-Process -Id $baselineProcess.Id -Force -ErrorAction SilentlyContinue
        }
    }
    Get-CimInstance Win32_Process |
        Where-Object { $_.Name -eq "php.exe" -and $_.CommandLine -like "*$runName*" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

$summaryPath = Join-Path $baselineDir "run-summary.json"
$summary = if(Test-Path -LiteralPath $summaryPath){ Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json }else{ $null }
$swarmReport = if(Test-Path -LiteralPath $rawResult){ Get-Content -LiteralPath $rawResult -Raw | ConvertFrom-Json }else{ $null }
$report = [pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    root = $rootPath
    run_name = $runName
    ready = $ready
    baseline_dir = $baselineDir
    baseline_summary = $summary
    swarm_result = $swarmReport
    swarm_exit = $swarmExit
}
$outPath = Join-Path $evidenceRoot "bedrock-login-swarm-gate-last.json"
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outPath -Encoding UTF8
$report | ConvertTo-Json -Depth 8
exit $swarmExit
