param(
    [switch]$Elevate
)

$ErrorActionPreference = "Stop"

function Test-Elevated()
{
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if(-not (Test-Elevated)){
    if($Elevate){
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Elevate" -Verb RunAs
        [pscustomobject]@{
            elevated = $false
            action = "started-elevated-powershell"
            note = "Approve the UAC prompt to install VS2019 BuildTools v142."
        } | ConvertTo-Json -Depth 3
        exit 0
    }
    [pscustomobject]@{
        elevated = $false
        action = "requires-elevation"
        note = "Re-run with -Elevate from an interactive session to install VS2019 BuildTools v142."
    } | ConvertTo-Json -Depth 3
    exit 5
}

winget install --id Microsoft.VisualStudio.2019.BuildTools --exact --source winget --accept-source-agreements --accept-package-agreements --override "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --quiet --norestart"
exit $LASTEXITCODE
