param(
    [int]$FastGatePort = 19154,
    [int]$SoakPort = 19155,
    [int]$SoakDurationSeconds = 7200,
    [int]$SoakMinimumDurationSeconds = 7200,
    [switch]$AcceptLgpl,
    [switch]$StartSoak,
    [switch]$AllowConcurrentSoak,
    [switch]$NoExitCode
)

$ErrorActionPreference = "Stop"

if(-not $AcceptLgpl){
    throw "LGPL license acceptance is required. Re-run with -AcceptLgpl after you have accepted the LICENSE in this PMMP directory."
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$stagedDll = Join-Path $rootPath "var/native-build/php_pmmp_perf_ext.dll"
$bundledDll = Join-Path $rootPath "bin/php/ext/php_pmmp_perf_ext.dll"
$stagedHash = if(Test-Path -LiteralPath $stagedDll){ (Get-FileHash -LiteralPath $stagedDll -Algorithm SHA256).Hash }else{ $null }
$bundledHash = if(Test-Path -LiteralPath $bundledDll){ (Get-FileHash -LiteralPath $bundledDll -Algorithm SHA256).Hash }else{ $null }

if($stagedHash -eq $null -or $bundledHash -eq $null -or $stagedHash -ne $bundledHash){
    [pscustomobject]@{
        started = $false
        reason = "staged_native_not_promoted"
        root = $rootPath
        staged_dll = $stagedDll
        bundled_dll = $bundledDll
        staged_sha256 = $stagedHash
        bundled_sha256 = $bundledHash
        required_command = "pmmp-promote-staged-native-extension.cmd"
    } | ConvertTo-Json -Depth 5
    if(-not $NoExitCode){ exit 5 }
    exit 0
}

function Test-PortInUse([int]$Port){
    $tcp = @(Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue)
    $udp = @(Get-NetUDPEndpoint -LocalPort $Port -ErrorAction SilentlyContinue)
    return $tcp.Count -gt 0 -or $udp.Count -gt 0
}

if($FastGatePort -eq $SoakPort){
    [pscustomobject]@{
        started = $false
        reason = "validation_ports_must_differ"
        fast_gate_port = $FastGatePort
        soak_port = $SoakPort
    } | ConvertTo-Json -Depth 4
    if(-not $NoExitCode){ exit 6 }
    exit 0
}

$busyPorts = @()
foreach($port in @($FastGatePort, $SoakPort)){
    if(Test-PortInUse $port){
        $busyPorts += $port
    }
}
if($busyPorts.Count -gt 0){
    [pscustomobject]@{
        started = $false
        reason = "validation_port_in_use"
        busy_ports = $busyPorts
        fast_gate_port = $FastGatePort
        soak_port = $SoakPort
    } | ConvertTo-Json -Depth 4
    if(-not $NoExitCode){ exit 7 }
    exit 0
}

$existingSoak = $null
try{
    $existingSoak = & (Join-Path $PSScriptRoot "check-production-soak-status.ps1") | ConvertFrom-Json
}catch{
    $existingSoak = $null
}
if($StartSoak -and -not $AllowConcurrentSoak -and $existingSoak -ne $null -and $existingSoak.running -eq $true){
    [pscustomobject]@{
        started = $false
        reason = "production_soak_already_running"
        root = $rootPath
        running_soak = [pscustomobject]@{
            run_name = $existingSoak.run_name
            ready = $existingSoak.ready
            elapsed_seconds = $existingSoak.elapsed_seconds
            remaining_seconds = $existingSoak.remaining_seconds
            expected_complete_at = $existingSoak.expected_complete_at
            fatal_log_matches = $existingSoak.fatal_log_matches
        }
        required_command = "pmmp-check-production-soak-status.cmd"
    } | ConvertTo-Json -Depth 6
    if(-not $NoExitCode){ exit 8 }
    exit 0
}

$fastGate = & (Join-Path $PSScriptRoot "run-fast-gates.ps1") -AcceptLgpl -Port $FastGatePort -DurationSeconds 30 -RunHotpathBench -RunRakPingBurst -RakPingCount 400 | ConvertFrom-Json
$soak = $null
$soakProcess = $null
$finalizer = $null
if($StartSoak){
    $runName = "post-native-promotion-soak-$stamp"
    $logRoot = Join-Path $rootPath "var/perf/post-native-promotion"
    New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
    $stdout = Join-Path $logRoot "$runName.out.log"
    $stderr = Join-Path $logRoot "$runName.err.log"
    $soakArgs = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Join-Path $PSScriptRoot "run-production-soak.ps1"),
        "-AcceptLgpl",
        "-Port",
        $SoakPort,
        "-DurationSeconds",
        $SoakDurationSeconds,
        "-MinimumDurationSeconds",
        $SoakMinimumDurationSeconds,
        "-RunName",
        $runName,
        "-RunRakPingBurst"
    )
    $soakProcess = Start-Process -FilePath "powershell.exe" -ArgumentList $soakArgs -WorkingDirectory $rootPath -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 3
    $soak = & (Join-Path $PSScriptRoot "check-production-soak-status.ps1") -RunName $runName | ConvertFrom-Json
    $finalizer = & (Join-Path $PSScriptRoot "start-production-finalizer-watcher.ps1") -RunName $runName -ReplaceExisting -NoExitCode | ConvertFrom-Json
}

[pscustomobject]@{
    started = $true
    root = $rootPath
    promoted_native_sha256 = $bundledHash
    fast_gate = $fastGate
    soak_started = $StartSoak
    soak_process_id = if($soakProcess -ne $null){ $soakProcess.Id }else{ $null }
    soak = $soak
    finalizer = $finalizer
    stdout = if($StartSoak){ $stdout }else{ $null }
    stderr = if($StartSoak){ $stderr }else{ $null }
    next_command = if($StartSoak){ "pmmp-check-production-soak-status.cmd -RunName $($soak.run_name)" }else{ "pmmp-run-post-native-promotion-validation.cmd -AcceptLgpl -StartSoak" }
} | ConvertTo-Json -Depth 8
