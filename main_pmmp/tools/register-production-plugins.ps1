param(
    [string]$SourceDir = "",
    [string]$OutputDir = "plugins",
    [string]$EvidenceDir = "var/perf/production-evidence",
    [switch]$AllowExampleOrTestPlugins,
    [switch]$NoProductionPlugins,
    [switch]$Copy
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$resolvedOutput = Join-Path $rootPath $OutputDir
$resolvedEvidence = Join-Path $rootPath $EvidenceDir
New-Item -ItemType Directory -Force -Path $resolvedOutput, $resolvedEvidence | Out-Null

if($NoProductionPlugins){
    $existingPluginFiles = @(Get-ChildItem -LiteralPath $resolvedOutput -Recurse -File -Include *.php,*.phar,plugin.yml -ErrorAction SilentlyContinue)
    if($existingPluginFiles.Count -gt 0){
        throw "Cannot register a no-production-plugins marker because plugin files already exist under $resolvedOutput"
    }
    $report = [pscustomobject]@{
        generated_at = (Get-Date).ToString("o")
        root = $rootPath
        source_dir = $null
        output_dir = $resolvedOutput
        copied = $false
        no_production_plugins = $true
        plugin_yml_count = 0
        php_file_count = 0
        phar_count = 0
        allow_example_or_test_plugins = [bool]$AllowExampleOrTestPlugins
        registered = @()
        note = "This marker declares an intentional no-production-plugin deployment. The production audit accepts it only while main_pmmp/plugins remains empty."
    }
    $outPath = Join-Path $resolvedEvidence "production-plugins.json"
    $report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outPath -Encoding UTF8
    $report | ConvertTo-Json -Depth 6
    exit 0
}

if($SourceDir -eq ""){
    throw "SourceDir is required unless -NoProductionPlugins is used."
}

$resolvedSource = Resolve-Path $SourceDir

$pluginYmlFiles = @(Get-ChildItem -LiteralPath $resolvedSource -Recurse -File -Filter plugin.yml -ErrorAction SilentlyContinue)
$phpFiles = @(Get-ChildItem -LiteralPath $resolvedSource -Recurse -File -Filter *.php -ErrorAction SilentlyContinue)
$pharFiles = @(Get-ChildItem -LiteralPath $resolvedSource -Recurse -File -Filter *.phar -ErrorAction SilentlyContinue)
if($pluginYmlFiles.Count -eq 0 -and $pharFiles.Count -eq 0){
    throw "No PMMP plugin.yml or phar plugin was found in $resolvedSource"
}
if($phpFiles.Count -eq 0 -and $pharFiles.Count -eq 0){
    throw "No PHP plugin source or phar plugin was found in $resolvedSource"
}
if(-not $AllowExampleOrTestPlugins){
    $sourcePath = $resolvedSource.Path
    if($sourcePath -match "\\examples\\plugins(\\|$)" -or $sourcePath -match "\\tests\\plugins(\\|$)" -or $sourcePath -match "\\var\\perf\\baseline(\\|$)"){
        throw "Refusing to register example, test, or baseline probe plugins as production evidence. Re-run with -AllowExampleOrTestPlugins only for an intentional non-production audit."
    }
    foreach($pluginYml in $pluginYmlFiles){
        $pluginText = Get-Content -LiteralPath $pluginYml.FullName -Raw
        if($pluginText -match "(?i)name\s*:\s*(ExamplePlugin|TesterPlugin|DevTools|ChunkCacheProbe)\b"){
            throw "Refusing to register example/test/probe plugin '$($matches[1])' as production evidence."
        }
    }
    foreach($phar in $pharFiles){
        if($phar.BaseName -match "(?i)^(ExamplePlugin|TesterPlugin|DevTools|ChunkCacheProbe)$"){
            throw "Refusing to register example/test/probe phar '$($phar.Name)' as production evidence."
        }
    }
}

$registered = New-Object System.Collections.Generic.List[object]
if($Copy){
    foreach($child in Get-ChildItem -LiteralPath $resolvedSource -Force){
        $target = Join-Path $resolvedOutput $child.Name
        if(Test-Path -LiteralPath $target){
            throw "Target already exists: $target"
        }
        Copy-Item -LiteralPath $child.FullName -Destination $target -Recurse
    }
}

foreach($pluginYml in $pluginYmlFiles){
    $pluginRoot = $pluginYml.Directory.FullName
    $relativeRoot = Resolve-Path -LiteralPath $pluginRoot -Relative
    $content = Get-Content -LiteralPath $pluginYml.FullName -Raw
    $name = if($content -match "(?m)^\s*name\s*:\s*(.+?)\s*$"){ $matches[1].Trim("'`" ") }else{ Split-Path $pluginRoot -Leaf }
    $registered.Add([pscustomobject]@{
        type = "source"
        name = $name
        root = $pluginRoot
        relative_root = $relativeRoot
        plugin_yml = $pluginYml.FullName
    }) | Out-Null
}
foreach($phar in $pharFiles){
    $registered.Add([pscustomobject]@{
        type = "phar"
        name = [System.IO.Path]::GetFileNameWithoutExtension($phar.Name)
        root = $phar.Directory.FullName
        relative_root = Resolve-Path -LiteralPath $phar.Directory.FullName -Relative
        phar = $phar.FullName
    }) | Out-Null
}

$report = [pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    root = $rootPath
    source_dir = $resolvedSource.Path
    output_dir = $resolvedOutput
    copied = [bool]$Copy
    plugin_yml_count = $pluginYmlFiles.Count
    php_file_count = $phpFiles.Count
    phar_count = $pharFiles.Count
    allow_example_or_test_plugins = [bool]$AllowExampleOrTestPlugins
    registered = $registered
}

$outPath = Join-Path $resolvedEvidence "production-plugins.json"
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outPath -Encoding UTF8
$report | ConvertTo-Json -Depth 6
