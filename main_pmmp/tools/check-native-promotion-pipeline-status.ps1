param(
    [string]$LogDir = "var/perf/native-promotion-pipeline"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$resolvedLogDir = if([System.IO.Path]::IsPathRooted($LogDir)){
    $LogDir
}else{
    Join-Path $rootPath $LogDir
}
$metaPath = Join-Path $resolvedLogDir "native-promotion-pipeline-last.json"
$heartbeatPath = Join-Path $resolvedLogDir "native-promotion-pipeline-heartbeat-last.json"
$meta = if(Test-Path -LiteralPath $metaPath){ Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json }else{ $null }
$heartbeat = if(Test-Path -LiteralPath $heartbeatPath){ Get-Content -LiteralPath $heartbeatPath -Raw | ConvertFrom-Json }else{ $null }

function Get-CappedTail([string]$Path, [int]$Lines = 20, [int]$MaxChars = 1000)
{
    if(-not (Test-Path -LiteralPath $Path)){
        return $null
    }
    return @(Get-Content -LiteralPath $Path -Tail $Lines -ErrorAction SilentlyContinue | ForEach-Object {
        $line = [string]$_
        if($line.Length -gt $MaxChars){
            $line.Substring(0, $MaxChars) + "...<truncated>"
        }else{
            $line
        }
    })
}

$processes = @()
if($meta -ne $null -and $meta.pid -ne $null){
    $pidFilter = "ProcessId=$([int]$meta.pid)"
    $processes = @(Get-CimInstance Win32_Process -Filter $pidFilter -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -eq "powershell.exe" -and $_.CommandLine -like "*run-native-promotion-pipeline.ps1*"
    } | Select-Object ProcessId, Name, CommandLine)
}
$stdoutTail = $null
$stderrTail = $null
if($meta -ne $null -and $meta.stdout -ne $null){
    $stdoutTail = Get-CappedTail $meta.stdout
}
if($meta -ne $null -and $meta.stderr -ne $null){
    $stderrTail = Get-CappedTail $meta.stderr
}

[pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    root = $rootPath
    running = $processes.Count -gt 0
    process_count = $processes.Count
    processes = $processes
    latest_meta = if($meta -ne $null){
        [pscustomobject]@{
            generated_at = $meta.generated_at
            name = $meta.name
            pid = $meta.pid
            root = $meta.root
            stdout = $meta.stdout
            stderr = $meta.stderr
            command = $meta.command
            expected_current_soak_complete_at = $meta.expected_current_soak_complete_at
            strict_soak_pass_required = $meta.strict_soak_pass_required
            heartbeat_enabled = $meta.heartbeat_enabled
            progress_fields_enabled = $meta.progress_fields_enabled
        }
    }else{
        $null
    }
    latest_heartbeat = $heartbeat
    stdout_tail = $stdoutTail
    stderr_tail = $stderrTail
} | ConvertTo-Json -Depth 8
