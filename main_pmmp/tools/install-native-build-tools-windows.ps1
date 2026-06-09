param(
    [switch]$PreferExistingVs2026
)

$ErrorActionPreference = "Stop"

function Test-Elevated()
{
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if(-not (Test-Elevated)){
    $script = $PSCommandPath
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$script`""
    if($PreferExistingVs2026){ $args += " -PreferExistingVs2026" }
    Start-Process -FilePath "powershell.exe" -ArgumentList $args -Verb RunAs
    [pscustomobject]@{
        elevated = $false
        action = "started-elevated-powershell"
        note = "Approve the UAC prompt so Visual Studio C++ build tools can be installed."
    } | ConvertTo-Json -Depth 3
    exit 0
}

$setup = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio/Installer/setup.exe"
$vs2026 = Join-Path ${env:ProgramFiles} "Microsoft Visual Studio/18/Community"

if($PreferExistingVs2026 -and (Test-Path -LiteralPath $setup) -and (Test-Path -LiteralPath $vs2026)){
    & $setup modify --installPath $vs2026 --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended --norestart --quiet
    exit $LASTEXITCODE
}

winget install --id Microsoft.VisualStudio.2022.BuildTools --exact --source winget --accept-source-agreements --accept-package-agreements --override "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --quiet --norestart"
exit $LASTEXITCODE
