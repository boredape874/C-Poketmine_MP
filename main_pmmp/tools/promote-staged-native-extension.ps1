param(
    [string]$StagedDll = "var/native-build/php_pmmp_perf_ext.dll",
    [string]$BackupDir = "var/native-build/promoted-backups",
    [switch]$Force,
    [switch]$SkipTest,
    [switch]$SkipPerformanceGate,
    [switch]$SkipEvidence
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$stagedPath = if([System.IO.Path]::IsPathRooted($StagedDll)){
    (Resolve-Path $StagedDll).Path
}else{
    (Resolve-Path (Join-Path $rootPath $StagedDll)).Path
}
$targetPath = Join-Path $rootPath "bin/php/ext/php_pmmp_perf_ext.dll"
$resolvedBackupDir = if([System.IO.Path]::IsPathRooted($BackupDir)){
    $BackupDir
}else{
    Join-Path $rootPath $BackupDir
}

function Get-RootPhpProcesses(){
    $escapedRoot = [regex]::Escape($rootPath)
    @(Get-CimInstance Win32_Process -Filter "Name = 'php.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match $escapedRoot } |
        Select-Object ProcessId, Name, CommandLine)
}

$status = $null
try{
    $status = & (Join-Path $PSScriptRoot "check-production-soak-status.ps1") | ConvertFrom-Json
}catch{
    $status = $null
}
$phpProcesses = Get-RootPhpProcesses

if($status -ne $null -and $status.running -eq $true -and -not $Force){
    [pscustomobject]@{
        promoted = $false
        reason = "production_soak_running"
        root = $rootPath
        staged_dll = $stagedPath
        target_dll = $targetPath
        soak_status = $status
        php_processes = $phpProcesses
        force_required = $true
    } | ConvertTo-Json -Depth 8
    exit 3
}

if($phpProcesses.Count -gt 0 -and -not $Force){
    [pscustomobject]@{
        promoted = $false
        reason = "php_process_holds_extension"
        root = $rootPath
        staged_dll = $stagedPath
        target_dll = $targetPath
        soak_status = $status
        php_processes = $phpProcesses
        force_required = $true
    } | ConvertTo-Json -Depth 8
    exit 4
}

if(-not (Test-Path -LiteralPath $stagedPath)){
    throw "Staged DLL not found: $stagedPath"
}
if(-not (Test-Path -LiteralPath $targetPath)){
    throw "Bundled target DLL not found: $targetPath"
}

$stagedHash = (Get-FileHash -LiteralPath $stagedPath -Algorithm SHA256).Hash
$beforeHash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash
$copied = $false
$backupPath = $null

$performanceGate = $null
if(-not $SkipPerformanceGate){
    $performanceGate = & (Join-Path $PSScriptRoot "run-staged-native-performance-gate.ps1") | ConvertFrom-Json
    if($performanceGate.passed -ne $true){
        [pscustomobject]@{
            promoted = $false
            reason = "staged_native_performance_gate_failed"
            root = $rootPath
            staged_dll = $stagedPath
            target_dll = $targetPath
            staged_sha256 = $stagedHash
            before_sha256 = $beforeHash
            performance_gate = $performanceGate
        } | ConvertTo-Json -Depth 10
        exit 12
    }
}

if($stagedHash -ne $beforeHash){
    New-Item -ItemType Directory -Force -Path $resolvedBackupDir | Out-Null
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = Join-Path $resolvedBackupDir "php_pmmp_perf_ext.$stamp.dll"
    Copy-Item -LiteralPath $targetPath -Destination $backupPath -Force
    Copy-Item -LiteralPath $stagedPath -Destination $targetPath -Force
    $copied = $true
}

$testOutput = $null
$testExit = $null
if(-not $SkipTest){
    $testOutput = & (Join-Path $PSScriptRoot "test-native-extension.ps1") -DllPath "bin/php/ext/php_pmmp_perf_ext.dll"
    $testExit = $LASTEXITCODE
    if($testExit -ne 0){
        throw "Native extension functional test failed after promotion with exit code $testExit"
    }
}

$evidence = $null
if(-not $SkipEvidence){
    $evidence = & (Join-Path $PSScriptRoot "record-native-build-evidence.ps1") | ConvertFrom-Json
}

$afterHash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash
[pscustomobject]@{
    promoted = $true
    copied = $copied
    root = $rootPath
    staged_dll = $stagedPath
    target_dll = $targetPath
    backup_dll = $backupPath
    before_sha256 = $beforeHash
    staged_sha256 = $stagedHash
    after_sha256 = $afterHash
    test_ran = -not $SkipTest
    test_exit = $testExit
    test_output = if($testOutput -ne $null){ $testOutput | ConvertFrom-Json }else{ $null }
    performance_gate_ran = -not $SkipPerformanceGate
    performance_gate = $performanceGate
    evidence_recorded = -not $SkipEvidence
    evidence = $evidence
} | ConvertTo-Json -Depth 8
