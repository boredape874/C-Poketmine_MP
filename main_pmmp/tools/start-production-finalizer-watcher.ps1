param(
    [string]$GateDir = "",
    [string]$RunName = "",
    [int]$PollSeconds = 60,
    [switch]$ReplaceExisting,
    [switch]$NoExitCode
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$logRoot = Join-Path $rootPath "var/perf/finalizer-watchers"
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null

$watchName = "production-finalizer-" + (Get-Date -Format "yyyyMMdd-HHmmss")
$stdout = Join-Path $logRoot "$watchName.out.log"
$stderr = Join-Path $logRoot "$watchName.err.log"
$metaPath = Join-Path $logRoot "$watchName.json"
$scriptPath = Join-Path $PSScriptRoot "finalize-production-readiness-after-soak.ps1"

$existing = Get-CimInstance Win32_Process |
    Where-Object {
        $_.ProcessId -ne $PID -and
        $_.CommandLine -like "*finalize-production-readiness-after-soak.ps1*" -and
        $_.CommandLine -like "*-Wait*"
    } |
    Select-Object -First 1
if($null -ne $existing){
    if($ReplaceExisting){
        Stop-Process -Id $existing.ProcessId -Force
        Start-Sleep -Seconds 1
    }else{
    $report = [pscustomobject]@{
        generated_at = (Get-Date).ToString("o")
        root = $rootPath
        already_running = $true
        pid = $existing.ProcessId
        process_name = $existing.Name
        command_line = $existing.CommandLine
        expected_finalize_report = Join-Path $rootPath "var/perf/production-evidence/production-readiness-finalize-last.json"
    }
    $report | ConvertTo-Json -Depth 4
    exit 0
    }
}

$arguments = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$scriptPath`"",
    "-Wait",
    "-PollSeconds", $PollSeconds
)
if($GateDir -ne ""){
    $arguments += @("-GateDir", "`"$GateDir`"")
}
if($RunName -ne ""){
    $arguments += @("-RunName", "`"$RunName`"")
}
if($NoExitCode){
    $arguments += "-NoExitCode"
}

$process = Start-Process -FilePath "powershell.exe" `
    -ArgumentList $arguments `
    -WorkingDirectory $rootPath `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr `
    -WindowStyle Hidden `
    -PassThru

$report = [pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    root = $rootPath
    watch_name = $watchName
    already_running = $false
    pid = $process.Id
    poll_seconds = $PollSeconds
    gate_dir = $GateDir
    run_name = $RunName
    replace_existing = [bool]$ReplaceExisting
    no_exit_code = [bool]$NoExitCode
    stdout = $stdout
    stderr = $stderr
    expected_finalize_report = Join-Path $rootPath "var/perf/production-evidence/production-readiness-finalize-last.json"
}

$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $metaPath -Encoding UTF8
$report | ConvertTo-Json -Depth 4
