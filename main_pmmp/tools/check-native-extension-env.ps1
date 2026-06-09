param(
    [string]$ExtensionDir = "native/pmmp_perf_ext"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$php = Join-Path $root "bin/php/php.exe"
$extDir = Resolve-Path (Join-Path $root $ExtensionDir)
$buildRoot = Join-Path $root "var/native-build"
$develRoot = Join-Path $buildRoot "php-devel"
$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio/Installer/vswhere.exe"

$phpInfo = & $php -r "echo PHP_VERSION . PHP_EOL; echo PHP_ZTS ? 'zts' : 'nts'; echo PHP_EOL; echo PHP_OS_FAMILY; echo PHP_EOL; echo PHP_EXTENSION_DIR; echo PHP_EOL; echo PHP_VERSION_ID;"
$phpLines = $phpInfo -split "`r?`n"
$cl = Get-Command cl.exe -ErrorAction SilentlyContinue
$nmake = Get-Command nmake.exe -ErrorAction SilentlyContinue
$phpize = Get-Command phpize -ErrorAction SilentlyContinue

$vsInstances = @()
if(Test-Path -LiteralPath $vswhere){
    $vsJson = & $vswhere -all -format json
    if($LASTEXITCODE -eq 0 -and $vsJson){
        $vsInstances = @($vsJson | ConvertFrom-Json)
    }
}

$directCl = Get-ChildItem -LiteralPath (Join-Path ${env:ProgramFiles} "Microsoft Visual Studio") -Recurse -Filter cl.exe -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\VC\\Tools\\MSVC\\[^\\]+\\bin\\Hostx64\\x64\\cl\.exe$" } |
    Sort-Object FullName -Descending |
    Select-Object -First 1
$directNmake = Get-ChildItem -LiteralPath (Join-Path ${env:ProgramFiles} "Microsoft Visual Studio") -Recurse -Filter nmake.exe -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\VC\\Tools\\MSVC\\[^\\]+\\bin\\Hostx64\\x64\\nmake\.exe$" } |
    Sort-Object FullName -Descending |
    Select-Object -First 1
$windowsHeader = Get-ChildItem -LiteralPath (Join-Path ${env:ProgramFiles(x86)} "Windows Kits") -Recurse -Filter Windows.h -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\Include\\[^\\]+\\um\\Windows\.h$" } |
    Sort-Object FullName -Descending |
    Select-Object -First 1
$ucrtMalloc = Get-ChildItem -LiteralPath (Join-Path ${env:ProgramFiles(x86)} "Windows Kits") -Recurse -Filter malloc.h -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\Include\\[^\\]+\\ucrt\\malloc\.h$" } |
    Sort-Object FullName -Descending |
    Select-Object -First 1
$msvcLib = Get-ChildItem -LiteralPath (Join-Path ${env:ProgramFiles} "Microsoft Visual Studio") -Recurse -Filter msvcprt.lib -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\VC\\Tools\\MSVC\\[^\\]+\\lib\\x64\\msvcprt\.lib$" } |
    Sort-Object FullName -Descending |
    Select-Object -First 1
$phpImportLib = Join-Path $root "bin/php/dev/php8ts.lib"
$phpDll = Join-Path $root "bin/php/php8ts.dll"
$develInclude = Get-ChildItem -LiteralPath $develRoot -Recurse -Directory -Filter include -ErrorAction SilentlyContinue |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "main/php.h") } |
    Select-Object -First 1

$requiredFiles = @("config.m4", "config.w32", "php_pmmp_perf_ext.h", "pmmp_perf_ext.c", "README.md")
$missing = @()
foreach ($file in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $extDir $file))) {
        $missing += $file
    }
}

$result = [pscustomobject]@{
    root = $root.Path
    extension_dir = $extDir.Path
    php_binary = $php
    php_version = $phpLines[0]
    php_thread_safety = $phpLines[1]
    php_os_family = $phpLines[2]
    php_extension_dir = $phpLines[3]
    php_version_id = $phpLines[4]
    php_import_lib = $phpImportLib
    has_php_import_lib = Test-Path -LiteralPath $phpImportLib
    php_thread_safe_dll = $phpDll
    has_php_thread_safe_dll = Test-Path -LiteralPath $phpDll
    php_devel_include = if($develInclude){ $develInclude.FullName } else { $null }
    has_php_devel_headers = $develInclude -ne $null
    vswhere = if(Test-Path -LiteralPath $vswhere){ $vswhere } else { $null }
    visual_studio_instances = @($vsInstances | ForEach-Object {
        [pscustomobject]@{
            display_name = $_.displayName
            installation_path = $_.installationPath
            installation_version = $_.installationVersion
            is_complete = $_.isComplete
            is_launchable = $_.isLaunchable
        }
    })
    has_cl = $cl -ne $null
    has_nmake = $nmake -ne $null
    has_phpize = $phpize -ne $null
    direct_cl = if($directCl){ $directCl.FullName } else { $null }
    direct_nmake = if($directNmake){ $directNmake.FullName } else { $null }
    has_direct_cl = $directCl -ne $null
    has_direct_nmake = $directNmake -ne $null
    ucrt_malloc_h = if($ucrtMalloc){ $ucrtMalloc.FullName } else { $null }
    has_ucrt_c_headers = $ucrtMalloc -ne $null
    msvc_x64_lib = if($msvcLib){ $msvcLib.DirectoryName } else { $null }
    has_msvc_x64_lib = $msvcLib -ne $null
    windows_h = if($windowsHeader){ $windowsHeader.FullName } else { $null }
    has_windows_sdk_headers = $windowsHeader -ne $null
    missing_extension_files = $missing
    required_vs_components = @(
        "Microsoft.VisualStudio.Workload.NativeDesktop",
        "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
        "Microsoft.VisualStudio.Component.Windows11SDK.26100"
    )
    build_ready = ($missing.Count -eq 0 -and $directCl -ne $null -and $directNmake -ne $null -and $ucrtMalloc -ne $null -and $msvcLib -ne $null -and $windowsHeader -ne $null -and (Test-Path -LiteralPath $phpImportLib) -and $develInclude -ne $null)
}

$outDir = Join-Path $root "var/perf/native"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outPath = Join-Path $outDir "native-extension-env.json"
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $outPath -Encoding UTF8
$result | ConvertTo-Json -Depth 4
