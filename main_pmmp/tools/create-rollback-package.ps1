param(
    [string]$GateDir = "",
    [string]$OutputDir = "var/perf/production-evidence"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$resolvedOutput = Join-Path $rootPath $OutputDir
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null

if($GateDir -eq ""){
    $latestGate = Get-ChildItem -LiteralPath (Join-Path $rootPath "var/perf/gates") -Directory -ErrorAction SilentlyContinue |
        Sort-Object -Property Name -Descending |
        Select-Object -First 1
    $resolvedGate = if($latestGate -ne $null){ $latestGate.FullName }else{ $null }
}else{
    $resolvedGate = (Resolve-Path $GateDir).Path
}

$phpIniPath = Join-Path $rootPath "bin/php/php.ini"
$nativeDllPath = Join-Path $rootPath "bin/php/ext/php_pmmp_perf_ext.dll"
$disableScriptPath = Join-Path $resolvedOutput "disable-native-extension.ps1"
$enableScriptPath = Join-Path $resolvedOutput "enable-native-extension.ps1"
$readmePath = Join-Path $resolvedOutput "rollback-readme.md"
$manifestPath = Join-Path $resolvedOutput "rollback-package.json"

$phpIniHash = if(Test-Path -LiteralPath $phpIniPath){ (Get-FileHash -LiteralPath $phpIniPath -Algorithm SHA256).Hash }else{ $null }
$nativeDllHash = if(Test-Path -LiteralPath $nativeDllPath){ (Get-FileHash -LiteralPath $nativeDllPath -Algorithm SHA256).Hash }else{ $null }
$gateSummaryPath = if($resolvedGate -ne $null){ Join-Path $resolvedGate "gate-summary.json" }else{ $null }
$gateSummaryHash = if($gateSummaryPath -ne $null -and (Test-Path -LiteralPath $gateSummaryPath)){ (Get-FileHash -LiteralPath $gateSummaryPath -Algorithm SHA256).Hash }else{ $null }

@'
param(
    [string]$Root = ""
)

$ErrorActionPreference = "Stop"
if($Root -eq ""){
    $Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}else{
    $Root = Resolve-Path $Root
}

$phpIniPath = Join-Path $Root "bin/php/php.ini"
if(-not (Test-Path -LiteralPath $phpIniPath)){
    throw "Missing php.ini: $phpIniPath"
}

$content = Get-Content -LiteralPath $phpIniPath -Raw
$content = $content -replace "(?m)^(\s*)extension\s*=\s*php_pmmp_perf_ext\.dll\s*$", '${1};extension=php_pmmp_perf_ext.dll'
$content | Set-Content -LiteralPath $phpIniPath -Encoding ASCII
Write-Output $phpIniPath
'@ | Set-Content -LiteralPath $disableScriptPath -Encoding ASCII

@'
param(
    [string]$Root = ""
)

$ErrorActionPreference = "Stop"
if($Root -eq ""){
    $Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}else{
    $Root = Resolve-Path $Root
}

$phpIniPath = Join-Path $Root "bin/php/php.ini"
if(-not (Test-Path -LiteralPath $phpIniPath)){
    throw "Missing php.ini: $phpIniPath"
}

$content = Get-Content -LiteralPath $phpIniPath -Raw
if($content -match "(?m)^\s*;\s*extension\s*=\s*php_pmmp_perf_ext\.dll\s*$"){
    $content = $content -replace "(?m)^(\s*);\s*extension\s*=\s*php_pmmp_perf_ext\.dll\s*$", '${1}extension=php_pmmp_perf_ext.dll'
}elseif($content -notmatch "(?m)^\s*extension\s*=\s*php_pmmp_perf_ext\.dll\s*$"){
    $content = $content.TrimEnd() + "`r`nextension=php_pmmp_perf_ext.dll`r`n"
}
$content | Set-Content -LiteralPath $phpIniPath -Encoding ASCII
Write-Output $phpIniPath
'@ | Set-Content -LiteralPath $enableScriptPath -Encoding ASCII

@"
# PMMP rollback package

Generated at: $(Get-Date -Format o)

## Fast rollback

Disable the native extension:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\var\perf\production-evidence\disable-native-extension.ps1
```

Re-enable it:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\var\perf\production-evidence\enable-native-extension.ps1
```

The PHP fallback paths remain in the codebase, so disabling
`php_pmmp_perf_ext.dll` should keep PMMP bootable while removing native
acceleration.
"@ | Set-Content -LiteralPath $readmePath -Encoding UTF8

$gitHead = $null
$gitBranch = $null
try{
    $gitHead = (& git -C $rootPath rev-parse HEAD 2>$null | Select-Object -First 1)
    $gitBranch = (& git -C $rootPath branch --show-current 2>$null | Select-Object -First 1)
}catch{
    $gitHead = $null
    $gitBranch = $null
}

$manifest = [pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    root = $rootPath
    gate_dir = $resolvedGate
    git = [pscustomobject]@{
        head = $gitHead
        branch = $gitBranch
    }
    files = [pscustomobject]@{
        php_ini = $phpIniPath
        php_ini_sha256 = $phpIniHash
        native_dll = $nativeDllPath
        native_dll_sha256 = $nativeDllHash
        gate_summary = $gateSummaryPath
        gate_summary_sha256 = $gateSummaryHash
        disable_native_script = $disableScriptPath
        enable_native_script = $enableScriptPath
        readme = $readmePath
    }
    rollback_actions = @(
        "Stop PMMP.",
        "Run disable-native-extension.ps1 to comment php_pmmp_perf_ext.dll out of bundled php.ini.",
        "Start PMMP with the same data and plugin directories.",
        "If the native path is needed again, run enable-native-extension.ps1 and rerun the fast gate."
    )
}

$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
$manifest | ConvertTo-Json -Depth 5
