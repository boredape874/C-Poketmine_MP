param(
    [string]$OutputDir = "var/perf",
    [string]$OutputFile = ""
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$repoRootResult = $null
try {
    $repoRootResult = & git -C $root rev-parse --show-toplevel 2>$null
} catch {
    $repoRootResult = $null
}
$repoRoot = if ($repoRootResult -ne $null -and "$repoRootResult" -ne "") { "$repoRootResult" } else { "$root" }
$localPhp = Join-Path $root "bin/php/php.exe"
$php = if (Test-Path -LiteralPath $localPhp) { $localPhp } else { "php" }
$outputRoot = Join-Path $root $OutputDir

if (-not (Test-Path -LiteralPath $outputRoot)) {
    New-Item -ItemType Directory -Path $outputRoot | Out-Null
}

if ($OutputFile -eq "") {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputFile = Join-Path $outputRoot "runtime-manifest-$stamp.json"
}

function Invoke-Optional {
    param([string]$FilePath, [string[]]$Arguments, [string]$WorkingDirectory)

    try {
        $output = & $FilePath @Arguments 2>&1
        $lines = @($output | ForEach-Object { "$_" })
        $truncated = $false
        if ($lines.Count -gt 250) {
            $lines = @($lines | Select-Object -First 250)
            $truncated = $true
        }
        return @{
            ok = $LASTEXITCODE -eq 0
            output = $lines
            truncated = $truncated
        }
    } catch {
        return @{
            ok = $false
            output = @($_.Exception.Message)
            truncated = $false
        }
    }
}

function Read-JsonFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

$composerJsonPath = Join-Path $root "composer.json"
$composerLockPath = Join-Path $root "composer.lock"
$pocketmineYmlPath = Join-Path $root "resources/pocketmine.yml"

$composerJson = Read-JsonFile $composerJsonPath
$composerLock = Read-JsonFile $composerLockPath

$gitHead = Invoke-Optional "git" @("-C", $repoRoot, "rev-parse", "HEAD") $repoRoot
$gitBranch = Invoke-Optional "git" @("-C", $repoRoot, "branch", "--show-current") $repoRoot
$phpVersion = Invoke-Optional $php @("-v") $root
$phpModules = Invoke-Optional $php @("-m") $root
$phpIni = Invoke-Optional $php @("--ini") $root

$trackedPackages = @(
    "pocketmine/bedrock-protocol",
    "pocketmine/bedrock-data",
    "pocketmine/bedrock-block-upgrade-schema",
    "pocketmine/bedrock-item-upgrade-schema",
    "pocketmine/raklib",
    "pocketmine/raklib-ipc",
    "pocketmine/binaryutils",
    "pocketmine/nbt",
    "pocketmine/snooze",
    "phpstan/phpstan",
    "phpunit/phpunit"
)

$installedPackages = @()
if ($composerLock -ne $null) {
    foreach ($pkg in @($composerLock.packages)) {
        if ($trackedPackages -contains $pkg.name) {
            $installedPackages += [ordered]@{
                name = "$($pkg.name)"
                version = "$($pkg.version)"
            }
        }
    }
    foreach ($pkg in @($composerLock."packages-dev")) {
        if ($trackedPackages -contains $pkg.name) {
            $installedPackages += [ordered]@{
                name = "$($pkg.name)"
                version = "$($pkg.version)"
            }
        }
    }
}

$requiredPackages = @()
if ($composerJson -ne $null) {
    foreach ($property in $composerJson.require.PSObject.Properties) {
        if ($property.Name -match "^php$|^ext-|^pocketmine/") {
            $requiredPackages += [ordered]@{
                name = "$($property.Name)"
                constraint = "$($property.Value)"
            }
        }
    }
}

$configLines = @()
if (Test-Path -LiteralPath $pocketmineYmlPath) {
    $configLines = Get-Content -LiteralPath $pocketmineYmlPath | Where-Object {
        $_ -match "async-workers|compression-level|async-compression|async-compression-threshold|view-distance|spawn-radius|chunk"
    }
}

Add-Type -AssemblyName System.Web

function ConvertTo-JsonString {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return "null"
    }

    return '"' + [System.Web.HttpUtility]::JavaScriptStringEncode($Value) + '"'
}

function ConvertTo-JsonBool {
    param([bool]$Value)

    if ($Value) {
        return "true"
    }

    return "false"
}

function ConvertTo-JsonStringArray {
    param([AllowNull()][object[]]$Values)

    if ($null -eq $Values) {
        return "[]"
    }

    $items = @()
    foreach ($value in $Values) {
        $items += ConvertTo-JsonString "$value"
    }
    return "[" + ($items -join ",") + "]"
}

function ConvertTo-RequiredPackageJson {
    param([object[]]$Packages)

    $items = @()
    foreach ($pkg in $Packages) {
        $items += "{" + '"name":' + (ConvertTo-JsonString "$($pkg["name"])") + ',"constraint":' + (ConvertTo-JsonString "$($pkg["constraint"])") + "}"
    }
    return "[" + ($items -join ",") + "]"
}

function ConvertTo-InstalledPackageJson {
    param([object[]]$Packages)

    $items = @()
    foreach ($pkg in $Packages) {
        $items += "{" + '"name":' + (ConvertTo-JsonString "$($pkg["name"])") + ',"version":' + (ConvertTo-JsonString "$($pkg["version"])") + "}"
    }
    return "[" + ($items -join ",") + "]"
}

$head = if ($gitHead.ok -and $gitHead.output.Count -gt 0) { "$($gitHead.output[0])" } else { $null }
$branch = if ($gitBranch.ok -and $gitBranch.output.Count -gt 0) { "$($gitBranch.output[0])" } else { $null }
$json = @"
{
  "generated_at": $(ConvertTo-JsonString (Get-Date).ToString("o")),
  "root": $(ConvertTo-JsonString "$root"),
  "repo_root": $(ConvertTo-JsonString "$repoRoot"),
  "output_file": $(ConvertTo-JsonString "$OutputFile"),
  "git": {
    "head": $(ConvertTo-JsonString $head),
    "branch": $(ConvertTo-JsonString $branch)
  },
  "php": {
    "binary": $(ConvertTo-JsonString "$php"),
    "version": $(ConvertTo-JsonStringArray $phpVersion.output),
    "modules": $(ConvertTo-JsonStringArray $phpModules.output),
    "ini": $(ConvertTo-JsonStringArray $phpIni.output)
  },
  "composer": {
    "require": $(ConvertTo-RequiredPackageJson $requiredPackages),
    "installed": $(ConvertTo-InstalledPackageJson $installedPackages)
  },
  "pocketmine_yml_focus_lines": $(ConvertTo-JsonStringArray $configLines),
  "machine": {
    "os": $(ConvertTo-JsonString ([System.Environment]::OSVersion.VersionString)),
    "is_64bit_os": $(ConvertTo-JsonBool ([System.Environment]::Is64BitOperatingSystem)),
    "is_64bit_process": $(ConvertTo-JsonBool ([System.Environment]::Is64BitProcess)),
    "processor_count": $([System.Environment]::ProcessorCount),
    "machine_name": $(ConvertTo-JsonString ([System.Environment]::MachineName)),
    "user_domain": $(ConvertTo-JsonString ([System.Environment]::UserDomainName))
  }
}
"@

$json | Set-Content -LiteralPath $OutputFile -Encoding UTF8
Write-Output $OutputFile
