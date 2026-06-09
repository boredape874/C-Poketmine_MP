param(
    [string]$HostName = "127.0.0.1",
    [int]$Port = 19132,
    [int]$Players = 400,
    [int]$DurationSeconds = 60,
    [int]$RampMs = 25,
    [string]$SkipPing = "true",
    [switch]$Install,
    [switch]$RegisterEvidence,
    [string]$OutputDir = "var/perf/production-evidence"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$swarmDir = Join-Path $PSScriptRoot "bedrock-swarm"
$evidenceRoot = Join-Path $rootPath $OutputDir
New-Item -ItemType Directory -Force -Path $evidenceRoot | Out-Null

if(-not (Test-Path -LiteralPath (Join-Path $swarmDir "package.json"))){
    throw "Missing bedrock swarm package.json under $swarmDir"
}

if($Install){
    Push-Location $swarmDir
    try{
        npm install
    }finally{
        Pop-Location
    }
}

if(-not (Test-Path -LiteralPath (Join-Path $swarmDir "node_modules/bedrock-protocol/package.json"))){
    $report = [pscustomobject]@{
        generated_at = (Get-Date).ToString("o")
        verdict = "fail"
        error = "missing-node-dependencies"
        action = "run-with-install"
        command = "main_pmmp\tools\run-bedrock-login-swarm.ps1 -Install"
        swarm_dir = $swarmDir
    }
    $outPath = Join-Path $evidenceRoot "bedrock-login-swarm-last-failed.json"
    $report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $outPath -Encoding UTF8
    $report | ConvertTo-Json -Depth 5
    exit 21
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$rawResult = Join-Path $evidenceRoot "bedrock-login-swarm-raw-$stamp.json"
Push-Location $swarmDir
try{
    node .\swarm.js "--host=$HostName" "--port=$Port" "--players=$Players" "--duration=$DurationSeconds" "--ramp-ms=$RampMs" "--skip-ping=$($SkipPing.ToLowerInvariant())" "--out=$rawResult"
    $nodeExit = $LASTEXITCODE
}finally{
    Pop-Location
}

if($RegisterEvidence){
    & (Join-Path $PSScriptRoot "register-bedrock-login-swarm-evidence.ps1") -InputJson $rawResult -TargetPlayers $Players -OutputDir $OutputDir
    exit $LASTEXITCODE
}

Get-Content -LiteralPath $rawResult -Raw
exit $nodeExit
