param(
    [string]$ExtensionDir = "native/pmmp_perf_ext",
    [switch]$PreferVs16,
    [switch]$PatchVs16LinkerVersion,
    [switch]$CopyToPhpExt
)

$ErrorActionPreference = "Stop"

function Find-FirstFile([string]$Base, [string]$Filter, [scriptblock]$Predicate)
{
    if(-not (Test-Path -LiteralPath $Base)){
        return $null
    }

    return Get-ChildItem -LiteralPath $Base -Recurse -Filter $Filter -ErrorAction SilentlyContinue |
        Where-Object $Predicate |
        Sort-Object FullName -Descending |
        Select-Object -First 1
}

function Download-PhpDevelPack([string]$BuildRoot)
{
    $zip = Join-Path $BuildRoot "php-devel-pack-8.2.31-Win32-vs16-x64.zip"
    $extractRoot = Join-Path $BuildRoot "php-devel"
    if(-not (Test-Path -LiteralPath $zip)){
        New-Item -ItemType Directory -Force -Path $BuildRoot | Out-Null
        Invoke-WebRequest -Uri "https://windows.php.net/downloads/releases/php-devel-pack-8.2.31-Win32-vs16-x64.zip" -OutFile $zip
    }
    if(-not (Test-Path -LiteralPath $extractRoot)){
        New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
        Expand-Archive -LiteralPath $zip -DestinationPath $extractRoot -Force
    }

    $include = Get-ChildItem -LiteralPath $extractRoot -Recurse -Directory -Filter include -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "main/php.h") } |
        Select-Object -First 1
    if(-not $include){
        throw "PHP devel headers were not found under $extractRoot"
    }
    return $include.FullName
}

function Find-WindowsSdk()
{
    $kits = Join-Path ${env:ProgramFiles(x86)} "Windows Kits/10"
    $umHeader = Find-FirstFile $kits "Windows.h" { $_.FullName -match "\\Include\\[^\\]+\\um\\Windows\.h$" }
    if(-not $umHeader){
        return $null
    }

    $version = Split-Path (Split-Path $umHeader.DirectoryName -Parent) -Leaf
    $base = Join-Path $kits $version
    return [pscustomobject]@{
        Version = $version
        IncludeShared = Join-Path $kits "Include/$version/shared"
        IncludeUcrt = Join-Path $kits "Include/$version/ucrt"
        IncludeUm = Join-Path $kits "Include/$version/um"
        LibUcrt = Join-Path $kits "Lib/$version/ucrt/x64"
        LibUm = Join-Path $kits "Lib/$version/um/x64"
    }
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$phpRoot = Join-Path $root "bin/php"
$phpImportLib = Join-Path $phpRoot "dev/php8ts.lib"
$extDir = Resolve-Path (Join-Path $root $ExtensionDir)
$outRoot = Join-Path $root "var/native-build"
$outDll = Join-Path $outRoot "php_pmmp_perf_ext.dll"
$outObj = Join-Path $outRoot "pmmp_perf_ext.obj"
$outPdb = Join-Path $outRoot "pmmp_perf_ext.pdb"
$outImportLib = Join-Path $outRoot "pmmp_perf_ext.lib"
$buildLog = Join-Path $outRoot "pmmp_perf_ext-build.log"
$develInclude = Download-PhpDevelPack $outRoot

$vsBases = @(
    (Join-Path ${env:ProgramFiles} "Microsoft Visual Studio"),
    (Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio")
)
if($PreferVs16){
    $cl = $null
    $msvcLibProbe = $null
    foreach($vsBase in $vsBases){
        if($cl -eq $null){
            $cl = Find-FirstFile $vsBase "cl.exe" { $_.FullName -match "\\VC\\Tools\\MSVC\\14\.29\.[^\\]+\\bin\\Hostx64\\x64\\cl\.exe$" }
        }
        if($msvcLibProbe -eq $null){
            $msvcLibProbe = Find-FirstFile $vsBase "msvcprt.lib" { $_.FullName -match "\\VC\\Tools\\MSVC\\14\.29\.[^\\]+\\lib\\x64\\msvcprt\.lib$" }
        }
    }
} else {
    $cl = $null
    $msvcLibProbe = $null
    foreach($vsBase in $vsBases){
        if($cl -eq $null){
            $cl = Find-FirstFile $vsBase "cl.exe" { $_.FullName -match "\\VC\\Tools\\MSVC\\[^\\]+\\bin\\Hostx64\\x64\\cl\.exe$" }
        }
        if($msvcLibProbe -eq $null){
            $msvcLibProbe = Find-FirstFile $vsBase "msvcprt.lib" { $_.FullName -match "\\VC\\Tools\\MSVC\\[^\\]+\\lib\\x64\\msvcprt\.lib$" }
        }
    }
}
$sdk = Find-WindowsSdk

$missing = @()
if(-not $cl){ $missing += "MSVC x64 cl.exe" }
if(-not $msvcLibProbe){ $missing += "MSVC x64 libraries" }
if(-not $sdk){ $missing += "Windows SDK headers (Windows.h)" }
if($sdk -and -not (Test-Path -LiteralPath (Join-Path $sdk.IncludeUcrt "malloc.h"))){ $missing += "Windows SDK UCRT C headers (malloc.h)" }
if(-not (Test-Path -LiteralPath $phpImportLib)){ $missing += "PMMP PHP import library (bin/php/dev/php8ts.lib)" }

if($missing.Count -gt 0){
    $status = [pscustomobject]@{
        build_ready = $false
        missing = $missing
        required_components = @(
            "Microsoft.VisualStudio.Workload.NativeDesktop",
            "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
            "Microsoft.VisualStudio.Component.Windows11SDK.26100"
        )
    }
    $status | ConvertTo-Json -Depth 4
    exit 2
}

$msvcRoot = Split-Path (Split-Path (Split-Path $cl.DirectoryName -Parent) -Parent) -Parent
$msvcInclude = Join-Path $msvcRoot "include"
$msvcLib = Join-Path $msvcRoot "lib/x64"
$source = Join-Path $extDir "pmmp_perf_ext.c"
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

$includeArgs = @(
    "/I", $develInclude,
    "/I", (Join-Path $develInclude "main"),
    "/I", (Join-Path $develInclude "Zend"),
    "/I", (Join-Path $develInclude "TSRM"),
    "/I", (Join-Path $develInclude "ext"),
    "/I", $extDir.Path,
    "/I", $msvcInclude,
    "/I", $sdk.IncludeShared,
    "/I", $sdk.IncludeUcrt,
    "/I", $sdk.IncludeUm
)
$libArgs = @(
    "/LIBPATH:$msvcLib",
    "/LIBPATH:$($sdk.LibUcrt)",
    "/LIBPATH:$($sdk.LibUm)",
    "/LIBPATH:$($phpRoot)\dev",
    "php8ts.lib",
    "kernel32.lib",
    "advapi32.lib",
    "user32.lib"
)

$buildOutput = & $cl.FullName /nologo /LD /O2 /MD "/Fo$outObj" "/Fd$outPdb" /D ZEND_WIN32 /D PHP_WIN32 /D ZTS /D ZEND_DEBUG=0 /D COMPILE_DL_PMMP_PERF_EXT @includeArgs $source /link @libArgs "/OUT:$outDll" "/IMPLIB:$outImportLib" 2>&1
$buildExit = $LASTEXITCODE
$buildOutput | Set-Content -LiteralPath $buildLog -Encoding UTF8
if($buildExit -ne 0){
    [pscustomobject]@{
        build_ready = $false
        exit_code = $buildExit
        build_log = $buildLog
        dll = $outDll
        sdk_version = $sdk.Version
        compiler = $cl.FullName
    } | ConvertTo-Json -Depth 4
    exit $buildExit
}

if($PatchVs16LinkerVersion){
    & (Join-Path $PSScriptRoot "patch-pe-linker-version.ps1") -Path $outDll -Major 14 -Minor 29 | Out-Null
}

if($CopyToPhpExt){
    $target = Join-Path $phpRoot "ext/php_pmmp_perf_ext.dll"
    Copy-Item -LiteralPath $outDll -Destination $target -Force
}

[pscustomobject]@{
    build_ready = $true
    dll = $outDll
    patched_vs16_linker_version = [bool]$PatchVs16LinkerVersion
    copied_to_php_ext = [bool]$CopyToPhpExt
    build_log = $buildLog
    sdk_version = $sdk.Version
    compiler = $cl.FullName
} | ConvertTo-Json -Depth 4
