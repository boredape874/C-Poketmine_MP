param(
    [string]$RunName = "",
    [string]$EvidenceDir = "var/perf/production-evidence"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$evidenceRoot = Join-Path $rootPath $EvidenceDir
$baselineRoot = Join-Path $rootPath "var/perf/baseline"
$logRoot = Join-Path $rootPath "var/perf/soak-command-logs"

if($RunName -eq ""){
    $latestMeta = Get-ChildItem -LiteralPath $logRoot -File -Filter "*.meta.json" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "production-soak-*.meta.json" -or $_.Name -like "production-strict-soak-*.meta.json" -or $_.Name -like "production-v142-strict-soak-*.meta.json" -or $_.Name -like "post-native-promotion-soak-*.meta.json" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if($latestMeta -ne $null){
        $meta = Get-Content -LiteralPath $latestMeta.FullName -Raw | ConvertFrom-Json
        $runName = [System.IO.Path]::GetFileNameWithoutExtension($latestMeta.Name) -replace "\.meta$", ""
    }else{
        $latestBaseline = Get-ChildItem -LiteralPath $baselineRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "production-soak-*" -or $_.Name -like "production-strict-soak-*" -or $_.Name -like "production-v142-strict-soak-*" -or $_.Name -like "post-native-promotion-soak-*" } |
            Sort-Object Name -Descending |
            Select-Object -First 1
        if($latestBaseline -eq $null){
            throw "No production soak run was found."
        }
        $runName = $latestBaseline.Name
        $meta = $null
    }
}else{
    $runName = $RunName
    $metaPath = Join-Path $logRoot ($RunName + ".meta.json")
    $meta = if(Test-Path -LiteralPath $metaPath){ Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json }else{ $null }
}

$baselineDir = Join-Path $baselineRoot $runName
$serverLog = Join-Path $baselineDir "data/server.log"
$summaryPath = Join-Path $baselineDir "run-summary.json"
$samplesPath = Join-Path $baselineDir "process-samples.csv"
$rakPingPath = Join-Path $baselineDir "rak-ping-burst.json"
$soakPassPath = Join-Path $evidenceRoot "soak.json"
$soakFailPath = Join-Path $evidenceRoot "soak-last-failed.json"

function Read-SharedText([string]$Path)
{
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try{
        $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8, $true)
        try{
            return $reader.ReadToEnd()
        }finally{
            $reader.Dispose()
        }
    }finally{
        $stream.Dispose()
    }
}

function Read-LastProcessSample([string]$Path)
{
    if(-not (Test-Path -LiteralPath $Path)){
        return $null
    }
    $text = Read-SharedText $Path
    $lines = @($text -split "`r?`n" | Where-Object { $_ -ne "" })
    if($lines.Count -lt 2){
        return $null
    }

    return ($lines[-1] | ConvertFrom-Csv -Header timestamp,pid,cpu_seconds,working_set_mb,private_mb,threads,handles)
}

$processes = @(Get-CimInstance Win32_Process | Where-Object {
    if($_.Name -eq "php.exe"){
        return $_.CommandLine -like "*PocketMine.php*" -and $_.CommandLine -like "*$baselineDir*"
    }
    if($_.Name -eq "powershell.exe"){
        return $_.CommandLine -like "*run-production-soak.ps1*" -and $_.CommandLine -like "*$runName*"
    }
    return $false
})
$readyLine = if(Test-Path -LiteralPath $serverLog){
    Select-String -Path $serverLog -Pattern "Done \(([0-9.]+)s\)" | Select-Object -Last 1
}else{
    $null
}
$fatalMatches = if(Test-Path -LiteralPath $serverLog){
    (Select-String -Path $serverLog -Pattern "CRITICAL|Fatal|Exception|ERROR" | Measure-Object).Count
}else{
    $null
}
$lastSample = Read-LastProcessSample $samplesPath
$summary = if(Test-Path -LiteralPath $summaryPath){
    Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
}else{
    $null
}
$elapsedSeconds = $null
$remainingSeconds = $null
$expectedCompleteAt = $null
$progressPercent = $null
if($meta -ne $null -and $meta.generated_at -ne $null){
    try{
        $startedAt = [DateTime]$meta.generated_at
        $elapsedSeconds = [Math]::Max(0, [int]((Get-Date) - $startedAt).TotalSeconds)
        if($meta.duration_seconds -ne $null){
            $durationSeconds = [int]$meta.duration_seconds
            $remainingSeconds = [Math]::Max(0, $durationSeconds - $elapsedSeconds)
            $progressPercent = if($durationSeconds -gt 0){ [Math]::Min(100, [Math]::Round(($elapsedSeconds / $durationSeconds) * 100, 2)) }else{ $null }
            $expectedCompleteAt = $startedAt.AddSeconds($durationSeconds).ToString("o")
        }
    }catch{
        $elapsedSeconds = $null
        $remainingSeconds = $null
        $expectedCompleteAt = $null
    }
}
$rakPing = if(Test-Path -LiteralPath $rakPingPath){
    Get-Content -LiteralPath $rakPingPath -Raw | ConvertFrom-Json
}else{
    $null
}
$passEvidence = if(Test-Path -LiteralPath $soakPassPath){ Get-Content -LiteralPath $soakPassPath -Raw | ConvertFrom-Json }else{ $null }
$failedEvidence = if(Test-Path -LiteralPath $soakFailPath){ Get-Content -LiteralPath $soakFailPath -Raw | ConvertFrom-Json }else{ $null }
$passEvidenceMatchesRun = $passEvidence -ne $null -and $passEvidence.baseline_dir -eq $baselineDir
$failedEvidenceMatchesRun = $failedEvidence -ne $null -and $failedEvidence.baseline_dir -eq $baselineDir

[pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    root = $rootPath
    run_name = $runName
    running = $processes.Count -gt 0
    elapsed_seconds = $elapsedSeconds
    remaining_seconds = $remainingSeconds
    progress_percent = $progressPercent
    expected_complete_at = $expectedCompleteAt
    processes = @($processes | Select-Object ProcessId, Name, CommandLine)
    baseline_dir = $baselineDir
    server_log = $serverLog
    ready = $readyLine -ne $null -or ($summary -ne $null -and [bool]$summary.ready)
    fatal_log_matches = $fatalMatches
    rak_ping = $rakPing
    last_process_sample = $lastSample
    summary_exists = $summary -ne $null
    summary = $summary
    pass_evidence_exists = Test-Path -LiteralPath $soakPassPath
    pass_evidence_matches_run = $passEvidenceMatchesRun
    pass_evidence = $passEvidence
    failed_evidence_exists = Test-Path -LiteralPath $soakFailPath
    failed_evidence_matches_run = $failedEvidenceMatchesRun
    failed_evidence = $failedEvidence
    meta = $meta
} | ConvertTo-Json -Depth 8
