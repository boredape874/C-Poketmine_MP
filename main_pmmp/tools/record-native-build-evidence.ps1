param(
    [string]$OutputDir = "var/perf/production-evidence"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$resolvedOutput = Join-Path $rootPath $OutputDir
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null

$envJson = & (Join-Path $PSScriptRoot "check-native-extension-env.ps1") | ConvertFrom-Json
$dllPath = Join-Path $rootPath "bin/php/ext/php_pmmp_perf_ext.dll"
$nativeBuildDir = Join-Path $rootPath "var/native-build"
$dllHash = if(Test-Path -LiteralPath $dllPath){ (Get-FileHash -LiteralPath $dllPath -Algorithm SHA256).Hash }else{ $null }
$dllInfo = if(Test-Path -LiteralPath $dllPath){ Get-Item -LiteralPath $dllPath }else{ $null }

$v142Cl = Get-ChildItem -LiteralPath (Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio") -Recurse -Filter cl.exe -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\VC\\Tools\\MSVC\\14\.29\.[^\\]+\\bin\\Hostx64\\x64\\cl\.exe$" } |
    Sort-Object FullName -Descending |
    Select-Object -First 1
$clPath = if($v142Cl -ne $null){ $v142Cl.FullName }else{ $envJson.direct_cl }
$toolsetVersion = $null
if($clPath -match "\\VC\\Tools\\MSVC\\([^\\]+)\\"){
    $toolsetVersion = $matches[1]
}
$isV142 = $toolsetVersion -ne $null -and $toolsetVersion.StartsWith("14.29")
$outFileName = if($isV142){ "native-v142-build.json" }else{ "native-local-build.json" }
$outPath = Join-Path $resolvedOutput $outFileName

$report = [pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    root = $rootPath
    verdict = if($isV142){ "production_v142" }else{ "local_non_v142" }
    is_v142 = $isV142
    toolset_version = $toolsetVersion
    cl_path = $clPath
    php_version = $envJson.php_version
    php_thread_safety = $envJson.php_thread_safety
    php_version_id = $envJson.php_version_id
    build_ready = $envJson.build_ready
    native_build_dir = $nativeBuildDir
    bundled_dll = $dllPath
    bundled_dll_exists = Test-Path -LiteralPath $dllPath
    bundled_dll_sha256 = $dllHash
    bundled_dll_length = if($dllInfo -ne $null){ $dllInfo.Length }else{ $null }
    note = if($isV142){
        "This marker satisfies the production v142 native build evidence requirement."
    }else{
        "This records the local native build only. It does not satisfy the production v142 evidence requirement."
    }
}

$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $outPath -Encoding UTF8
$report | ConvertTo-Json -Depth 5
